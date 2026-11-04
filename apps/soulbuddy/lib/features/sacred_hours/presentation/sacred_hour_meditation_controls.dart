import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class SacredHourMeditationControls extends StatelessWidget {
  const SacredHourMeditationControls({
    required this.prompt,
    required this.onReflect,
    required this.onAnotherReflection,
    super.key,
  });

  final String prompt;
  final VoidCallback? onReflect;
  final VoidCallback? onAnotherReflection;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'God speaks to us in meditation',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      const Text('Listen to know if your prayer needs something from you'),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        key: const Key('sacred-hour-reflection-prompt'),
        onPressed: onReflect,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(AppSpacing.md),
        ),
        child: Text(prompt, textAlign: TextAlign.left),
      ),
      Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: onAnotherReflection,
          child: const Text('Another reflection'),
        ),
      ),
    ],
  );
}
