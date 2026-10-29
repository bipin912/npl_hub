
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../profile/data/services/user_profile_service.dart';
import '../models/chat_message.dart';

/// Handles Firestore operations for the NPL live chat.
class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _roomId = 'npl_chat';
  static const int _maxMessageLength = 500;

  CollectionReference<Map<String, dynamic>> get _messagesCollection {
    return _firestore
        .collection('rooms')
        .doc(_roomId)
        .collection('messages');
  }

  /// Streams recent messages, updating when new messages arrive.
  Stream<List<ChatMessage>> watchMessages() {
    return _messagesCollection
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(ChatMessage.fromFirestore)
          .toList()
          .reversed
          .toList();
    });
  }


  /// Sends a message with the current user's verified profile details.
  Future<void> sendMessage(String messageText) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must sign in to send a message.');
    }

    final text = messageText.trim();

    if (text.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    if (text.length > _maxMessageLength) {
      throw ArgumentError(
        'Message cannot exceed $_maxMessageLength characters.',
      );
    }

    // Ensure the profile exists and is up to date before sending.
    final profileService = UserProfileService(
      firestore: _firestore,
      auth: _auth,
    );

    await profileService.syncCurrentUserProfile();

    final profileSnapshot =
    await _firestore.collection('users').doc(user.uid).get();

    final profile = profileSnapshot.data();

    if (profile == null) {
      throw StateError('Your user profile could not be loaded.');
    }

    await _messagesCollection.add({
      'uid': user.uid,
      'text': text,
      'displayName': profile['displayName'],
      'photoURL': profile['photoURL'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

}
