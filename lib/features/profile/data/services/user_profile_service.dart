
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles reading and updating a user's NPL Community profile.
class UserProfileService {
  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates a profile if needed, without overwriting a custom display name.
  Future<void> syncCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A user must be signed in.');
    }

    final reference = _users.doc(user.uid);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      await reference.set({
        'displayName': _googleDisplayName(user),
        'photoURL': user.photoURL,
        'points': 1000,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Refresh the photo, but preserve the user's custom display name.
    await reference.update({
      'photoURL': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reads the current user's profile from Firestore.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A user must be signed in.');
    }

    final snapshot = await _users.doc(user.uid).get();
    return snapshot.data();
  }

  /// Saves a custom community display name.
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A user must be signed in.');
    }

    final name = displayName.trim();

    if (name.isEmpty || name.length > 60) {
      throw ArgumentError(
        'Display name must contain 1–60 characters.',
      );
    }

    final reference = _users.doc(user.uid);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      await syncCurrentUserProfile();
    }

    await reference.update({
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> getCurrentPoints() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('A user must be signed in.');
    }

    final snapshot = await _users.doc(user.uid).get();
    final points = snapshot.data()?['points'];

    if (points is int) {
      return points;
    }

    return 0;
  }

  String _googleDisplayName(User user) {
    final name = user.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = user.email?.trim();

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'NPL Fan';
  }
}
