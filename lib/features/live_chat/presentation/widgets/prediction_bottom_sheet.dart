
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class PredictionBottomSheet extends StatefulWidget {
  const PredictionBottomSheet({
    super.key,
    required this.team1,
    required this.team2,
    required this.onSubmit,
    this.allowBall = true,
    this.allowFinalWin = true,
  });

  final String team1;
  final String team2;
  final bool allowBall;
  final bool allowFinalWin;

  // The next step will connect this callback to Firestore.
  final void Function({
  required String category,
  required String prediction,
  required int rewardPoints,
  }) onSubmit;

  @override
  State<PredictionBottomSheet> createState() =>
      _PredictionBottomSheetState();
}

class _PredictionBottomSheetState
    extends State<PredictionBottomSheet> {
  late String _category = widget.allowBall ? 'Batting' : 'Final Win';

  List<String> get _categories => [
    if (widget.allowBall) ...['Batting', 'Bowling'],
    if (widget.allowFinalWin) 'Final Win',
  ];
  String? _selectedPrediction;
  int _rewardPoints = 50;

  List<String> get _options {
    switch (_category) {
      case 'Batting':
        return ['4', '6', 'Runs'];
      case 'Bowling':
        return ['Dot Ball', 'Wicket'];
      default:
        return [widget.team1, widget.team2];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Make a Prediction',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.monetization_on,
                  color: Colors.amber,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Points reward',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prediction categories.
            Row(
              children: _categories.map((category) {
                final selected = _category == category;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _category = category;
                          _selectedPrediction = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected
                            ? AppColors.primary
                            .withValues(alpha: 0.10)
                            : Colors.white,
                        foregroundColor: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            Text(
              _category == 'Batting'
                  ? 'What will happen?'
                  : _category == 'Bowling'
                  ? 'Bowling outcome'
                  : 'Who will win the match?',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),

            // Prediction choices.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options.map((option) {
                final selected = _selectedPrediction == option;

                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedPrediction = option;
                    });
                  },
                  selectedColor:
                  AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Correct prediction reward',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$_rewardPoints pts',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            Slider(
              value: _rewardPoints.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              activeColor: AppColors.primary,
              label: '$_rewardPoints points',
              onChanged: (value) {
                setState(() {
                  _rewardPoints = value.round();
                });
              },
            ),

            Text(
              'Win ${_rewardPoints * 2} pts if correct',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedPrediction == null
                    ? null
                    : () {
                  widget.onSubmit(
                    category: _category,
                    prediction: _selectedPrediction!,
                    rewardPoints: _rewardPoints,
                  );
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Submit Prediction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
