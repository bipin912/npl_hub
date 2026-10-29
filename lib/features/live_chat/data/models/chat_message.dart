
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents one message in the NPL community chat.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a message stored in the NPL chat.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.uid,
    required this.text,
    required this.displayName,
    required this.photoURL,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String text;
  final String displayName;
  final String? photoURL;
  final DateTime? createdAt;

  factory ChatMessage.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];

    return ChatMessage(
      id: document.id,
      uid: data['uid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'NPL Fan',
      photoURL: data['photoURL'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

