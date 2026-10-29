
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../leaderboard/data/services/leaderboard_service.dart';
import '../models/chat_prediction.dart';

class PredictionService {
  PredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Shared predictions collection for the NPL community chat.
  CollectionReference<Map<String, dynamic>> get _predictions =>
      _firestore
          .collection('rooms')
          .doc('npl_chat')
          .collection('predictions');

  /// Submits a prediction and deducts its selected points immediately.
  ///
  /// rewardPoints is the selected stake.
  /// A correct result should later award rewardPoints * 2.
  /// An incorrect result receives no additional points.
  Future<String> submitPrediction({
    required String userId,
    required String displayName,
    required String category,
    required String prediction,
    required int rewardPoints,
    required String matchId,
    required String matchName,
    int baseSeq = 0,
    String? targetBall,
  }) async {
    // Validate submission details.
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty.');
    }

    if (prediction.trim().isEmpty) {
      throw ArgumentError('Prediction cannot be empty.');
    }

    if (matchId.trim().isEmpty) {
      throw ArgumentError('Match ID cannot be empty.');
    }

    if (matchName.trim().isEmpty) {
      throw ArgumentError('Match name cannot be empty.');
    }

    if (!['Batting', 'Bowling', 'Final Win'].contains(category)) {
      throw ArgumentError('Invalid prediction category.');
    }

    if (rewardPoints < 10 || rewardPoints > 100) {
      throw ArgumentError('Prediction amount must be between 10 and 100.');
    }

    if (category == 'Batting' &&
        !['4', '6', 'Runs'].contains(prediction)) {
      throw ArgumentError('Invalid batting prediction.');
    }

    if (category == 'Bowling' &&
        !['Dot Ball', 'Wicket'].contains(prediction)) {
      throw ArgumentError('Invalid bowling prediction.');
    }

    if (baseSeq < 0) {
      throw ArgumentError('Base sequence cannot be negative.');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final predictionRef = _predictions.doc();

    final cleanDisplayName = displayName.trim().isEmpty
        ? 'Player'
        : displayName.trim();

    // Deduction and prediction creation succeed or fail together.
    await _firestore.runTransaction((transaction) async {
      // All transaction reads must happen before its writes.
      final userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw StateError('PROFILE_NOT_FOUND');
      }

      final pointsValue = userSnapshot.data()?['points'];

      if (pointsValue is! num) {
        throw StateError('INVALID_POINTS_BALANCE');
      }

      final currentPoints = pointsValue.toInt();

      if (currentPoints < rewardPoints) {
        throw StateError('NOT_ENOUGH_POINTS');
      }

      // Deduct the selected amount immediately.
      transaction.update(userRef, {
        'points': currentPoints - rewardPoints,
        LeaderboardService.monthField(): FieldValue.increment(-rewardPoints),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastPointsPredictionId': predictionRef.id,
      });

      // Create the pending prediction in the same transaction.
      transaction.set(predictionRef, {
        if (targetBall != null) 'targetBall': targetBall,
        'userId': userId,
        'displayName': cleanDisplayName.length > 40
            ? cleanDisplayName.substring(0, 40)
            : cleanDisplayName,
        'baseSeq': baseSeq,
        'matchName': matchName.trim(),
        'category': category,
        'prediction': prediction,
        'rewardPoints': rewardPoints,
        'matchId': matchId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return predictionRef.id;
  }

  /// The user's own predictions, newest first.
  Stream<List<ChatPrediction>> watchUserHistory(String uid) {
    return _predictions
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs
        .map((d) => ChatPrediction.fromMap(d.id, d.data()))
        .toList());
  }

  /// Watches predictions for a particular match.
  Stream<List<ChatPrediction>> watchPredictions({
    required String matchId,
  }) {
    return _predictions
        .where('matchId', isEqualTo: matchId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (document) => ChatPrediction.fromMap(
          document.id,
          document.data(),
        ),
      )
          .toList(),
    );
  }

  /// Watches recent predictions across all matches for the shared chat.
  Stream<List<ChatPrediction>> watchAllPredictions() {
    return _predictions
    .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (document) => ChatPrediction.fromMap(
          document.id,
          document.data(),
        ),
      )
          .toList(),
    );
  }
}
