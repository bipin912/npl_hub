import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../leaderboard/data/services/leaderboard_service.dart';
import '../models/ball_event.dart';
import '../models/match_score.dart';

class PredictionResolverService {
  PredictionResolverService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// A ball settles only after its rows stopped changing for this long.
  /// Corrections seen so far arrived up to ~143 s late.
  static const int settleDelayMs = 5000;

  /// A ball that already has a newer ball after it settles sooner.
  static const int settleDelayAfterNextMs = 5000;

  /// Firestore rules only allow refunds this long after creation.
  static const Duration refundAfter = Duration(hours: 2, minutes: 1);

  CollectionReference<Map<String, dynamic>> get _predictions => _firestore
      .collection('rooms')
      .doc('npl_chat')
      .collection('predictions');

  /// Settles whatever it can among this user's pending predictions.
  Future<void> settlePending({
    required List<MatchScore> matches,
    required Future<BallFeed> Function(String matchId) loadFeed,
  }) async {
    final user = _auth.currentUser;
    if (user == null || matches.isEmpty) return;

    final snapshot = await _predictions
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snapshot.docs.isEmpty) return;

    final byId = {for (final m in matches) m.id: m};
    final feeds = <String, BallFeed>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final matchId = data['matchId']?.toString() ?? '';
      final isFinalWin = data['category'] == 'Final Win';
      final match = byId[matchId];

      try {
        if (match == null) {
          // Unknown match (e.g. made on the old API): refund.
          await _refund(doc, user.uid);
        } else if (isFinalWin) {
          if (match.isFinished) await _settleFinalWin(doc, match, user.uid);
        } else if (match.isLive) {
          var feed = feeds[matchId];
          if (feed == null) {
            feed = await loadFeed(matchId);
            feeds[matchId] = feed;
          }
          await _settleBall(doc, feed, user.uid);
        } else if (match.isFinished) {
          // Ball prediction that never found a usable delivery: refund.
          await _refund(doc, user.uid);
        }
      } on FirebaseException catch (error) {
        debugPrint('Settling ${doc.id} failed: ${error.code}');
      }
    }
  }

  // ---------------------------------------------------------------- balls

  Future<void> _settleBall(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      BallFeed feed,
      String uid,
      ) async {
    final data = doc.data();
    final category = data['category'] as String? ?? '';
    final prediction = data['prediction'] as String? ?? '';
    final baseValue = data['baseSeq'];
    final baseSeq = baseValue is num ? baseValue.toInt() : 0;
    // Use the real clock too, otherwise the final ball before a break never settles.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final clock = feed.newestSequence > nowMs ? feed.newestSequence : nowMs;


    Delivery? found;
    bool? outcome;


      for (var i = 0; i < feed.deliveries.length; i++) {
        final d = feed.deliveries[i];
        if (d.firstSeen <= baseSeq) continue; // happened before the prediction

        // A newer ball in the feed means this one is much less likely to change.
        final hasNewer = i < feed.deliveries.length - 1;
        final delay = hasNewer ? settleDelayAfterNextMs : settleDelayMs;
        if (d.lastSeen > clock - delay) break; // still changing: wait

        if (d.hasExtra) continue; // wide / bye / no-ball somewhere in this ball
        final r = _evaluate(
          category: category,
          prediction: prediction,
          event: d.event,
        );
        if (r == null) continue; // wide / bye / run out: skip
        found = d;
        outcome = r;
        break;
      }


    final delivery = found;
    final isCorrect = outcome;
    if (delivery == null || isCorrect == null) return;

    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction<void>((tx) async {
      final current = await tx.get(doc.reference);
      if (!current.exists) return;

      final cur = current.data()!;
      if (cur['userId'] != uid || cur['status'] != 'pending') return;

      if (isCorrect) {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw StateError('PROFILE_NOT_FOUND');

        final points = userSnap.data()?['points'];
        final stake = cur['rewardPoints'];
        if (points is! num) throw StateError('INVALID_POINTS_BALANCE');
        if (stake is! num) throw StateError('INVALID_PREDICTION_AMOUNT');

        final payout = stake.toInt() * 2;
        tx.update(userRef, {
          'points': points.toInt() + payout,
          LeaderboardService.monthField(): FieldValue.increment(payout),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSettledPredictionId': doc.id,
        });
      }

      tx.update(doc.reference, {
        'resolvedBall': delivery.event.ballLabel,

        'status': isCorrect ? 'correct' : 'incorrect',
        'resolvedSeq': delivery.firstSeen,
        'resolvedText': delivery.event.text,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool? _evaluate({
    required String category,
    required String prediction,
    required BallEvent event,
  }) {
    final o = event.outcome;
    if (o == null) return null;

    if (category == 'Bowling') {
      if (prediction == 'Wicket') return o == BallOutcome.wicket;
      if (prediction == 'Dot Ball') return o == BallOutcome.dot;
    }
    if (category == 'Batting') {
      if (prediction == '4') return o == BallOutcome.four;
      if (prediction == '6') return o == BallOutcome.six;
      if (prediction == 'Runs') return o == BallOutcome.runs;
    }
    return null;
  }

  // ------------------------------------------------------------ final win

  Future<void> _settleFinalWin(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      MatchScore match,
      String uid,
      ) async {
    final winner = match.winner.trim();
    final result = match.statusText.toLowerCase();

    // Tie / no result / abandoned: no winner and no "won" in the result.
    final isVoid = winner.isEmpty && result.isNotEmpty && !result.contains('won');

    if (winner.isEmpty && !isVoid) return; // result not published yet
    if (isVoid && !_oldEnoughToRefund(doc.data())) return;

    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction<void>((tx) async {
      final fresh = await tx.get(doc.reference);
      if (!fresh.exists || fresh.data()?['status'] != 'pending') return;

      final stake = (fresh.data()?['rewardPoints'] as num).toInt();
      final picked = (fresh.data()?['prediction'] as String? ?? '').trim();

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('PROFILE_NOT_FOUND');
      final points = (userSnap.data()?['points'] as num).toInt();

      final String newStatus;
      final int payout;
      if (isVoid) {
        newStatus = 'void';
        payout = stake;
      } else if (picked == winner) {
        newStatus = 'correct';
        payout = stake * 2;
      } else {
        newStatus = 'incorrect';
        payout = 0;
      }

      if (payout > 0) {
        tx.update(userRef, {
          'points': points + payout,
          LeaderboardService.monthField(): FieldValue.increment(payout),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSettledPredictionId': doc.id,
        });
      }
      tx.update(doc.reference, {

        'status': newStatus,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // --------------------------------------------------------------- refund

  bool _oldEnoughToRefund(Map<String, dynamic> data) {
    final created = data['createdAt'];
    return created is Timestamp &&
        DateTime.now().difference(created.toDate()) >= refundAfter;
  }

  Future<void> _refund(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      String uid,
      ) async {
    if (!_oldEnoughToRefund(doc.data())) return;

    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction<void>((tx) async {
      final fresh = await tx.get(doc.reference);
      if (!fresh.exists || fresh.data()?['status'] != 'pending') return;

      final stake = (fresh.data()?['rewardPoints'] as num).toInt();
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;
      final points = (userSnap.data()?['points'] as num).toInt();

      tx.update(userRef, {
        'points': points + stake,
        LeaderboardService.monthField(): FieldValue.increment(stake),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSettledPredictionId': doc.id,
      });
      tx.update(doc.reference, {
        'status': 'void',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}