import 'package:flutter/material.dart';
import 'package:npl_community/core/constants/app_colors.dart';


import '../../../../live_chat/data/models/chat_prediction.dart';
import '../../../../live_chat/data/services/prediction_service.dart';


const int _previewCount = 5;
class PredictionHistorySection extends StatefulWidget {
  const PredictionHistorySection({super.key, required this.userId});
  final String userId;

  @override
  State<PredictionHistorySection> createState() =>
      _PredictionHistorySectionState();
}



class _PredictionHistorySectionState extends State<PredictionHistorySection> {
  late final Stream<List<ChatPrediction>> _stream =
  PredictionService().watchUserHistory(widget.userId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatPrediction>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('History error: ${snapshot.error}');
          return const Text('Could not load prediction history.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final all = snapshot.data!;
        final settled = all.where((p) => p.status != 'pending').toList();
        final wins = settled.where((p) => p.status == 'correct').length;
        final losses = settled.where((p) => p.status == 'incorrect').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(label: 'Won', value: wins, color: Colors.green.shade700),
                const SizedBox(width: 8),
                _StatChip(label: 'Lost', value: losses, color: Colors.red.shade700),
              ],
            ),
            const SizedBox(height: 10),
            if (settled.isEmpty)
              const Text('No settled predictions yet.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
            else ...[
              ...settled.take(_previewCount).map((p) => _HistoryTile(prediction: p)),
              if (settled.length > _previewCount)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PredictionHistoryScreen(userId: widget.userId),
                      ),
                    ),
                    child: Text('See all (${settled.length})'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.prediction});
  final ChatPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final won = p.status == 'correct';
    final lost = p.status == 'incorrect';
    final color = won
        ? Colors.green.shade700
        : lost
        ? Colors.red.shade700
        : AppColors.textSecondary;

    final result = won
        ? '+${p.rewardPoints * 2} pts'
        : lost
        ? '-${p.rewardPoints} pts'
        : 'Refunded';
    final ball = p.resolvedBall ?? p.targetBall;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(won ? Icons.check_circle : lost ? Icons.cancel : Icons.undo,
              size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.category} · ${p.prediction}'
                      '${ball != null ? ' · Ball $ball' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(p.matchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(result,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }



}
class PredictionHistoryScreen extends StatefulWidget {
  const PredictionHistoryScreen({super.key, required this.userId});
  final String userId;

  @override
  State<PredictionHistoryScreen> createState() =>
      _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState extends State<PredictionHistoryScreen> {
  late final Stream<List<ChatPrediction>> _stream =
  PredictionService().watchUserHistory(widget.userId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Prediction history',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: StreamBuilder<List<ChatPrediction>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load prediction history.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final settled =
          snapshot.data!.where((p) => p.status != 'pending').toList();
          final wins = settled.where((p) => p.status == 'correct').length;
          final losses = settled.where((p) => p.status == 'incorrect').length;

          if (settled.isEmpty) {
            return const Center(
              child: Text('No settled predictions yet.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: settled.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _StatChip(
                          label: 'Won',
                          value: wins,
                          color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      _StatChip(
                          label: 'Lost',
                          value: losses,
                          color: Colors.red.shade700),
                    ],
                  ),
                );
              }
              return _HistoryTile(prediction: settled[index - 1]);
            },
          );
        },
      ),
    );
  }
}