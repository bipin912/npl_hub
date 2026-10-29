
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/chat_prediction.dart';

class PredictionMessageCard extends StatelessWidget {
  const PredictionMessageCard({
    super.key,
    required this.prediction,
  });

  final ChatPrediction prediction;


  @override
  Widget build(BuildContext context) {
    final ball = prediction.resolvedBall ?? prediction.targetBall;
    final isSettledBall = prediction.resolvedBall != null;
    final isCorrect = prediction.status == 'correct';
    final isIncorrect = prediction.status == 'incorrect';
    final isMyWin = isCorrect &&
        prediction.userId == FirebaseAuth.instance.currentUser?.uid;

    final Color statusColor = isCorrect
        ? Colors.green.shade700
        : isIncorrect
        ? Colors.red.shade700
        : Colors.orange.shade800;

    final String statusLabel = isCorrect
        ? 'CORRECT'
        : isIncorrect
        ? 'INCORRECT'
        : 'PENDING';

    final String pointsText = isCorrect
        ? '+${prediction.rewardPoints * 2} points earned'
        : isIncorrect
        ? '-${prediction.rewardPoints} points lost'
        : '${prediction.rewardPoints} points staked · Awaiting result';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: isMyWin
            ? const Color(0xFFE8F5E9)
            : AppColors.surface,
        border: Border.all(
          color: isMyWin
              ? const Color(0xFF81C784)
              : AppColors.border.withValues(alpha: 0.8),
          width: isMyWin ? 1.0 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Username and status.
          Row(
            children: [
              const Icon(
                Icons.sports_cricket,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prediction.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Match name.
          Text(
            prediction.matchName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (ball != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.sports_baseball, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  isSettledBall ? 'Settled on ball $ball' : 'Next ball ~$ball',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 4),

          // Category and selected prediction.
          Row(
            children: [
              Flexible(
                child: Text(
                  prediction.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prediction.prediction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // Points outcome.
          Row(
            children: [
              Icon(
                isIncorrect
                    ? Icons.remove_circle_outline
                    : Icons.stars_rounded,
                size: 15,
                color: isIncorrect ? statusColor : Colors.amber.shade700,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  pointsText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isIncorrect
                        ? statusColor
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
