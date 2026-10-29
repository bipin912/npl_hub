
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.username,
    required this.message,
    required this.isMe,
    this.photoURL,
    this.createdAt,
  });

  final String username;
  final String message;
  final bool isMe;
  final String? photoURL;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final timeText = createdAt == null
        ? ''
        : DateFormat('h:mm a').format(createdAt!.toLocal());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _ProfileAvatar(photoURL: photoURL),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(13),
                    topRight: const Radius.circular(13),
                    bottomLeft: Radius.circular(isMe ? 13 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 13),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                    color: AppColors.border.withValues(alpha: 0.8),
                    width: 0.7,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) ...[
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: isMe ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (timeText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.1,
                            color: isMe
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 6),
              _ProfileAvatar(photoURL: photoURL),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.photoURL});

  final String? photoURL;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoURL != null && photoURL!.isNotEmpty;

    return CircleAvatar(
      radius: 13,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundImage: hasPhoto ? NetworkImage(photoURL!) : null,
      child: !hasPhoto
          ? const Icon(
        Icons.person,
        size: 15,
        color: AppColors.primary,
      )
          : null,
    );
  }
}
