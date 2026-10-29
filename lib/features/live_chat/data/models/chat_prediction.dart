
class ChatPrediction {
  const ChatPrediction({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.category,
    required this.prediction,
    required this.rewardPoints,
    required this.matchId,
    required this.matchName,
    required this.status,
    required this.createdAt,
    required this.targetBall,
    required this.resolvedBall,
    required this.resolvedAt,

  });

  final String id;
  final String userId;
  final String displayName;
  final String category;
  final String prediction;
  final int rewardPoints;
  final String matchId;
  final String matchName;
  final String? targetBall;
  final String? resolvedBall;
  final DateTime? resolvedAt;

  // pending, correct, or incorrect
  final String status;

  final DateTime? createdAt;

  factory ChatPrediction.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return ChatPrediction(
      id: id,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Player',
      category: data['category'] as String? ?? '',
      prediction: data['prediction'] as String? ?? '',
      rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 0,
      matchId: data['matchId'] as String? ?? '',
      matchName: data['matchName'] as String? ?? 'NPL Match',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
      targetBall: data['targetBall'] as String?,
      resolvedBall: data['resolvedBall'] as String?,
      resolvedAt: (data['resolvedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'category': category,
      'prediction': prediction,
      'rewardPoints': rewardPoints,
      'matchId': matchId,
      'matchName': matchName,
      'status': status,
    };
  }
}
