import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _service = LeaderboardService();

  bool _monthly = true;
  late Stream<List<LeaderboardEntry>> _topStream =
  _service.watchTop(monthly: true);

  void _setMonthly(bool value) {
    if (value == _monthly) return;
    setState(() {
      _monthly = value;
      _topStream = _service.watchTop(monthly: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_monthly)
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),

        // Filter.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              _FilterChip(
                label: 'This month',
                selected: _monthly,
                onTap: () => _setMonthly(true),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'All time',
                selected: !_monthly,
                onTap: () => _setMonthly(false),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: _topStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Leaderboard error: ${snapshot.error}');
                return const Center(
                  child: Text('Unable to load the leaderboard.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    _monthly
                        ? 'No one has scored this month yet.'
                        : 'No players yet.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final e = entries[index];
                  // Equal scores share a rank.
                  final rank =
                      entries.indexWhere((x) => x.score == e.score) + 1;
                  return _LeaderboardRow(
                    rank: rank,
                    entry: e,
                    isMe: e.uid == currentUid,
                  );
                },
              );
            },
          ),
        ),

        _MyPositionBar(
          key: ValueKey(_monthly),
          service: _service,
          monthly: _monthly,
          topStream: _topStream,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  Color? get _medal {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB300);
      case 2:
        return const Color(0xFF9E9E9E);
      case 3:
        return const Color(0xFFB87333);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medal;
    final hasPhoto = entry.photoURL != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 22)
                : Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: hasPhoto ? NetworkImage(entry.photoURL!) : null,
            child: hasPhoto
                ? null
                : const Icon(Icons.person, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${entry.displayName} (You)' : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.stars_rounded, size: 15, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            '${entry.score}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned bar showing the signed-in user's rank and points.
class _MyPositionBar extends StatefulWidget {
  const _MyPositionBar({
    super.key,
    required this.service,
    required this.monthly,
    required this.topStream,
  });

  final LeaderboardService service;
  final bool monthly;
  final Stream<List<LeaderboardEntry>> topStream;

  @override
  State<_MyPositionBar> createState() => _MyPositionBarState();
}

class _MyPositionBarState extends State<_MyPositionBar> {
  late final Stream<int> _myScore =
  widget.service.watchMyScore(monthly: widget.monthly);

  int? _cachedScore;
  Future<int>? _rankFuture;

  Future<int> _rankFutureFor(int score) {
    if (_cachedScore != score || _rankFuture == null) {
      _cachedScore = score;
      _rankFuture =
          widget.service.rankFor(monthly: widget.monthly, score: score);
    }
    return _rankFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: StreamBuilder<int>(
        stream: _myScore,
        builder: (context, scoreSnap) {
          if (uid == null) {
            return const Text('Sign in to see your position.');
          }
          if (!scoreSnap.hasData) {
            return const SizedBox(height: 20);
          }

          final score = scoreSnap.data!;

          // Monthly: no rank until the user has a positive score.
          if (widget.monthly && score <= 0) {
            return _bar(
              rankText: 'Not ranked yet',
              score: score,
              note: 'Win a prediction to enter this month’s ranking',
            );
          }

          return StreamBuilder<List<LeaderboardEntry>>(
            stream: widget.topStream,
            builder: (context, topSnap) {
              final top = topSnap.data;

              // In the top list: take the rank from it directly.
              if (top != null && top.any((e) => e.uid == uid)) {
                final mine = top.firstWhere((e) => e.uid == uid);
                final rank =
                    top.indexWhere((e) => e.score == mine.score) + 1;
                return _bar(rankText: '#$rank', score: mine.score);
              }

              // Outside the top list: count users with a higher score.
              return FutureBuilder<int>(
                future: _rankFutureFor(score),
                builder: (context, rankSnap) {
                  return _bar(
                    rankText: rankSnap.hasData ? '#${rankSnap.data}' : '…',
                    score: score,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _bar({required String rankText, required int score, String? note}) {
    return Row(
      children: [
        const Icon(Icons.person_pin_rounded, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your position: $rankText',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '$score pts',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}