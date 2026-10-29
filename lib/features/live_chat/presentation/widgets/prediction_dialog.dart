
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

Future<void> showPredictionDialog(BuildContext context) async {
  String selectedTeam = 'Team A';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Match Prediction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who do you think will win?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selectedTeam,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedTeam = value);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Team A'),
                        value: 'Team A',
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Team B'),
                        value: 'Team B',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Make a prediction for fun. Correct predictions '
                      'may earn points; no coins are staked.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Temporary prototype behavior.
                  // Firebase submission will be added later.
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Sample prediction selected: $selectedTeam',
                      ),
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}
