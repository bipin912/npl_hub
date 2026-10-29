import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.score,
  });

  final String uid;
  final String displayName;
  final String? photoURL;
  final int score;
}

class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int topLimit = 50;

  /// Field that holds this month's net points, e.g. "points_2026_10".
  static String monthField([DateTime? date]) {
    final d = date ?? DateTime.now().toUtc();
    return 'points_${d.year}_${d.month.toString().padLeft(2, '0')}';
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String _field(bool monthly) => monthly ? monthField() : 'points';

  int _score(Map<String, dynamic>? data, bool monthly) {
    final v = data?[_field(monthly)];
    return v is num ? v.toInt() : 0;
  }

  Stream<List<LeaderboardEntry>> watchTop({required bool monthly}) {
    final field = _field(monthly);

    Query<Map<String, dynamic>> query = _users;
    if (monthly) {
      query = query.where(field, isGreaterThan: 0);
    }

    return query
        .orderBy(field, descending: true)
        .limit(topLimit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data();
      final name = (data['displayName'] as String?)?.trim();
      final photo = data['photoURL'] as String?;
      return LeaderboardEntry(
        uid: doc.id,
        displayName: (name == null || name.isEmpty) ? 'NPL Fan' : name,
        photoURL: (photo == null || photo.isEmpty) ? null : photo,
        score: _score(data, monthly),
      );
    }).toList());
  }

  /// The signed-in user's score for the selected filter.
  Stream<int> watchMyScore({required bool monthly}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream<int>.empty();
    return _users.doc(uid).snapshots().map((s) => _score(s.data(), monthly));
  }

  /// Rank = number of users with a higher score, plus one.
  Future<int> rankFor({required bool monthly, required int score}) async {
    final result = await _users
        .where(_field(monthly), isGreaterThan: score)
        .count()
        .get();
    return (result.count ?? 0) + 1;
  }
}