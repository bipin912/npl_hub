import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:npl_community/features/leaderboard/presentation/screens/leaderboard_screen.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/data/services/user_profile_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_prediction.dart';
import '../../data/models/match_score.dart';
import '../../data/services/chat_services.dart';
import '../../data/services/live_score_service.dart';
import '../../data/services/prediction_resolver_service.dart';
import '../../data/services/prediction_service.dart';
import '../widgets/animated_cricket_icon.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/match_score_header.dart';
import '../widgets/prediction_bottom_sheet.dart';

import '../widgets/prediction_message_card.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  int _selectedTab = 1;
  int _coinBalance = 1000;
  bool _isSendingMessage = false;
  DateTime? _lastMessageSentAt;

  final PredictionService _predictionService = PredictionService();

  final UserProfileService _userProfileService = UserProfileService();

  final ChatService _chatService = ChatService();

  final PredictionResolverService _predictionResolverService =
      PredictionResolverService();

  Timer? _predictionResolutionTimer;
  bool _isResolvingPredictions = false;

  late final Stream<List<ChatMessage>> _messagesStream = _chatService
      .watchMessages();

  late final Stream<List<ChatPrediction>> _predictionsStream =
      _predictionService.watchAllPredictions();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _pointsStream =
      _createPointsStream();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _createPointsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  StreamSubscription<List<ChatPrediction>>? _predictionStatusSubscription;

  final Map<String, ChatPrediction> _temporaryPredictionResults = {};
  final Map<String, DateTime> _temporaryResultTimes = {};
  final Map<String, Timer> _resultTimers = {};
  final Map<String, String> _knownPredictionStatuses = {};

  bool _hasInitialPredictionSnapshot = false;

  final TextEditingController _messageController = TextEditingController();

  // Controls scrolling in the chat message list.
  final ScrollController _chatScrollController = ScrollController();

  // Tracks the newest message so we know when to scroll.
  String? _lastDisplayedMessageId;

  List<ChatPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _syncProfile();
    _startPredictionResolutionPolling();
    _predictionStatusSubscription = _predictionsStream.listen(
      (predictions) {
        if (!mounted) return;
        setState(() => _predictions = predictions);
        _handlePredictionStatusChanges(predictions);
      },
      onError: (Object error) {
        debugPrint('Prediction status stream failed: $error');
      },
    );
  }

  void _handlePredictionStatusChanges(List<ChatPrediction> predictions) {
    // Initialize existing statuses without showing old results.
    if (!_hasInitialPredictionSnapshot) {
      for (final prediction in predictions) {
        _knownPredictionStatuses[prediction.id] = prediction.status;
      }

      _hasInitialPredictionSnapshot = true;
      return;
    }

    final newlyResolved = <ChatPrediction>[];

    for (final prediction in predictions) {
      final previousStatus = _knownPredictionStatuses[prediction.id];
      _knownPredictionStatuses[prediction.id] = prediction.status;

      final myUid = FirebaseAuth.instance.currentUser?.uid;

      if (previousStatus == 'pending') {
        final won = prediction.status == 'correct';
        final myLoss =
            prediction.status == 'incorrect' && prediction.userId == myUid;
        if (won || myLoss) newlyResolved.add(prediction);
      }
    }

    if (!mounted || newlyResolved.isEmpty) return;

    setState(() {
      for (final prediction in newlyResolved) {
        _temporaryPredictionResults[prediction.id] = prediction;
        _temporaryResultTimes[prediction.id] = DateTime.now();
      }
    });

    for (final prediction in newlyResolved) {
      _resultTimers.remove(prediction.id)?.cancel();

      _resultTimers[prediction.id] = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;

        setState(() {
          _temporaryPredictionResults.remove(prediction.id);
          _temporaryResultTimes.remove(prediction.id);
        });

        _resultTimers.remove(prediction.id);
      });
    }
  }

  Future<void> _syncProfile() async {
    try {
      await _userProfileService.syncCurrentUserProfile();
    } catch (error, stackTrace) {
      debugPrint('Profile sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startPredictionResolutionPolling() {
    // Run an initial check, then repeat every 3 seconds.
    _resolvePendingPredictions();

    _predictionResolutionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _resolvePendingPredictions(),
    );
  }

  Future<void> _resolvePendingPredictions() async {
    if (_isResolvingPredictions) return;
    _isResolvingPredictions = true;
    final scoreService = LiveScoreService();

    try {
      final matches = await scoreService.fetchMatches();
      await _predictionResolverService.settlePending(
        matches: matches,
        loadFeed: (id) => scoreService.fetchBallFeed(matchId: id),
      );
    } catch (error, stackTrace) {
      debugPrint('Prediction resolution check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      scoreService.dispose();
      _isResolvingPredictions = false;
    }
  }

  @override
  void dispose() {
    _predictionStatusSubscription?.cancel();

    for (final timer in _resultTimers.values) {
      timer.cancel();
    }
    _resultTimers.clear();
    _predictionResolutionTimer?.cancel();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    // Prevent multiple simultaneous sends.
    if (_isSendingMessage) return;

    final text = _messageController.text.trim();

    // Prevent messages from being sent too quickly.
    final now = DateTime.now();
    final lastSent = _lastMessageSentAt;

    if (lastSent != null && now.difference(lastSent).inMilliseconds < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before sending again.'),
        ),
      );
      return;
    }

    // Ignore empty messages.
    if (text.isEmpty) return;

    // Enforce the same 500-character limit as the chat service.
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot exceed 500 characters.')),
      );
      return;
    }

    setState(() => _isSendingMessage = true);

    try {
      await _chatService.sendMessage(text);

      _lastMessageSentAt = DateTime.now();

      // Clear only if the field still contains the sent message.
      if (mounted && _messageController.text.trim() == text) {
        _messageController.clear();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _openPredictionSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final scoreService = LiveScoreService();

    List<MatchScore> matches;

    try {
      matches = await scoreService.fetchMatches();
    } catch (_) {
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to load the NPL match. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } finally {
      scoreService.dispose();
    }

    if (!mounted) return;

    if (matches.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No NPL matches are available for prediction.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Reject stale API data.
    final isFresh = matches.first.isFreshWithin(const Duration(seconds: 20));

    if (!isFresh) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Live match data is outdated. Predictions are unavailable.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final liveMatches = matches.where((item) => item.isLive).toList();
    final upcoming = matches.where((item) => item.isUpcoming).toList();

    final MatchScore match;
    final bool isLive;

    if (liveMatches.isNotEmpty) {
      match = liveMatches.first;
      isLive = true;
    } else if (upcoming.isNotEmpty) {
      match = upcoming.first; // the list is in date order: next match first
      isLive = false;
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No match available for prediction right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return PredictionBottomSheet(
          team1: match.team1,
          team2: match.team2,
          allowBall: isLive,
          allowFinalWin: !isLive,
          onSubmit:
              ({
                required String category,
                required String prediction,
                required int rewardPoints,
              }) {
                _savePrediction(
                  matchId: match.id.toString(),
                  category: category,
                  prediction: prediction,
                  rewardPoints: rewardPoints,
                  matchName: '${match.team1} vs ${match.team2}',
                );
              },
        );
      },
    );
  }

  Future<void> _savePrediction({
    required String matchId,
    required String category,
    required String prediction,
    required int rewardPoints,
    required String matchName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please sign in to make a prediction.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Read the user's existing profile name.
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String displayName = user.displayName?.trim() ?? '';

      final savedName = profile.data()?['displayName'];

      if (savedName is String && savedName.trim().isNotEmpty) {
        displayName = savedName.trim();
      }

      if (displayName.isEmpty) {
        displayName = user.email?.split('@').first ?? 'NPL Fan';
      }

      final liveScoreService = LiveScoreService();
      late final int baseSeq;
      String? targetBall;

      try {
        // The sheet may have stayed open after the match ended.
        final currentMatches = await liveScoreService.fetchMatches();
        final selected = currentMatches
            .where((item) => item.id == matchId)
            .toList();
        if (selected.isEmpty) throw StateError('MATCH_NOT_LIVE');
        final current = selected.first;

        if (category == 'Final Win') {
          // Only before the match starts.
          if (!current.isUpcoming) throw StateError('FINAL_WIN_CLOSED');
          baseSeq = 0;
        } else {
          if (!current.isLive) throw StateError('MATCH_NOT_LIVE');
          final feed = await liveScoreService.fetchBallFeed(matchId: matchId);
          if (feed.deliveries.isEmpty) throw StateError('NO_BALL_COMMENTARY');
          baseSeq = feed.latestFirstSeen;
          targetBall = feed.nextBallLabel;
        }
      } finally {
        liveScoreService.dispose();
      }

      await _predictionService.submitPrediction(
        userId: user.uid,
        displayName: displayName,
        matchName: matchName,
        category: category,
        prediction: prediction,
        rewardPoints: rewardPoints,
        matchId: matchId,
        baseSeq: baseSeq,
        targetBall: targetBall,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Prediction submitted successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final errorMessage = error.toString();

      final String message;

      if (errorMessage.contains('NOT_ENOUGH_POINTS')) {
        message = 'Not enough points to make this prediction.';
      } else if (errorMessage.contains('PROFILE_NOT_FOUND')) {
        message = 'Your profile was not found. Please sign in again.';
      } else if (errorMessage.contains('permission-denied')) {
        message = 'Firebase blocked the prediction. Check Firestore rules.';
      } else if (errorMessage.contains('MATCH_NOT_LIVE')) {
        message = 'The match has ended. Predictions are closed.';
      } else if (errorMessage.contains('MATCH_DATA_STALE')) {
        message = 'Live match data is outdated. Try again shortly.';
      } else if (errorMessage.contains('NO_BALL_COMMENTARY')) {
        message = 'Ball commentary is unavailable. Please try again.';
      } else if (errorMessage.contains('FINAL_WIN_CLOSED')) {
        message = 'Final Win predictions close when the match starts.';
      } else {
        message = 'Could not submit prediction. Please try again.';
      }

      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showRewardsInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Coins & Rewards'),
          content: Text(
            'Your sample balance is $_coinBalance coins.\n\n'
            'Rewarded ads may be added here later. Coins will be '
            'used for non-wagering features only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: [
            const LeaderboardScreen(),
            _buildLiveChat(),
            const ProfileScreen(),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.border.withValues(alpha: 0.65),
              width: 0.7,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.primary.withValues(alpha: 0.10),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() => _selectedTab = index);
            },

            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined, size: 21),
                selectedIcon: Icon(Icons.leaderboard, size: 21),
                label: 'Leaderboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline, size: 21),
                selectedIcon: Icon(Icons.chat_bubble, size: 21),
                label: 'Live Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: 21),
                selectedIcon: Icon(Icons.person, size: 21),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveChat() {
    return Column(
      children: [
        // Top bar: app title, predictions, and coin balance.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'NPL Community',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Match prediction',
                onPressed: _openPredictionSheet,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.09),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(7),
                  fixedSize: const Size(44, 44),
                ),
                icon: const AnimatedCricketIcon(size: 30),
              ),
              const SizedBox(width: 8),

              InkWell(
                onTap: _showRewardsInfo,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_outlined,
                        size: 19,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _pointsStream,
                        builder: (context, snapshot) {
                          final points = snapshot.data?.data()?['points'];

                          return Text(
                            snapshot.hasError
                                ? '—'
                                : snapshot.connectionState ==
                                      ConnectionState.waiting
                                ? '…'
                                : '${points is int ? points : 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const MatchScoreHeader(),

        // Chat messages occupy the available space.
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messagesStream,
            builder: (context, messageSnapshot) {
              if (messageSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load chat messages.'),
                );
              }

              if (messageSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = messageSnapshot.data ?? [];
              final currentUid = FirebaseAuth.instance.currentUser?.uid;

              return Builder(
                builder: (context) {
                  final predictions = _predictions;

                  debugPrint(
                    'PREDICTIONS: ${predictions.length} received; '
                    'statuses: ${predictions.map((p) => p.status).join(', ')}',
                  );

                  // Merge both types into one timeline.
                  final timeline = <Map<String, dynamic>>[
                    ...messages.map(
                      (message) => {
                        'type': 'message',
                        'item': message,
                        'time':
                            message.createdAt ??
                            DateTime.fromMillisecondsSinceEpoch(0),
                        'id': message.id,
                      },
                    ),
                    ...predictions
                        .where(
                          (prediction) =>
                              prediction.status.trim().toLowerCase() ==
                              'pending',
                        )
                        .map(
                          (prediction) => {
                            'type': 'prediction',
                            'item': prediction,
                            'time': prediction.createdAt ?? DateTime.now(),
                            'id': prediction.id,
                          },
                        ),

                    ..._temporaryPredictionResults.values.map(
                      (prediction) => {
                        'type': 'prediction',
                        'item': prediction,
                        'time':
                            _temporaryResultTimes[prediction.id] ??
                            DateTime.now(),
                        'id': 'won_${prediction.id}',
                      },
                    ),
                  ];

                  timeline.sort((a, b) {
                    final aTime = a['time'] as DateTime;
                    final bTime = b['time'] as DateTime;
                    return aTime.compareTo(bTime);
                  });

                  if (timeline.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the conversation!'),
                    );
                  }

                  final newestItemId = timeline.last['id'] as String;

                  if (_lastDisplayedMessageId != newestItemId) {
                    _lastDisplayedMessageId = newestItemId;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_chatScrollController.hasClients) {
                        return;
                      }

                      _chatScrollController.animateTo(
                        _chatScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    });
                  }

                  return ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: timeline.length,
                    itemBuilder: (context, index) {
                      final item = timeline[index];

                      if (item['type'] == 'prediction') {
                        final prediction = item['item'] as ChatPrediction;

                        return PredictionMessageCard(
                          key: ValueKey('prediction_${prediction.id}'),
                          prediction: prediction,
                        );
                      }

                      final message = item['item'] as ChatMessage;
                      final isMe = message.uid == currentUid;

                      return ChatMessageBubble(
                        key: ValueKey('message_${message.id}'),
                        username: isMe ? 'You' : message.displayName,
                        message: message.text,
                        isMe: isMe,
                        photoURL: message.photoURL,
                        createdAt: message.createdAt,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // Message composer.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onTap: _scrollChatToBottom,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message the NPL community...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              IconButton.filled(
                tooltip: 'Send message',
                onPressed: _isSendingMessage ? null : _sendMessage,
                icon: _isSendingMessage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        // child: CircularProgressIndicator(
                        //   strokeWidth: 2,
                        //   color: Colors.white,
                        // ),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_chatScrollController.hasClients) return;

      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}
