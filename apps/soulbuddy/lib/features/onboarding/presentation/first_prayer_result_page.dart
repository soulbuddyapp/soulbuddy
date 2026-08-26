import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../providers/first_prayer_providers.dart';

class FirstPrayerResultPage extends StatelessWidget {
  const FirstPrayerResultPage({
    required this.prayer,
    required this.onPray,
    required this.onKeep,
    super.key,
  });

  final FirstPrayerResult prayer;
  final VoidCallback onPray;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prayer.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              prayer.body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onPray, child: const Text('Pray now')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onKeep,
              child: const Text('Keep this prayer'),
            ),
          ],
        ),
      ),
    ),
  );
}
