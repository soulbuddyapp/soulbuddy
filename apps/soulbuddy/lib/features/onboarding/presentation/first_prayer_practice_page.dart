import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class FirstPrayerPracticePage extends StatelessWidget {
  const FirstPrayerPracticePage({
    required this.action,
    required this.onContinue,
    super.key,
  });

  final String? action;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final practice = action?.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Practice',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (practice != null && practice.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  practice,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
