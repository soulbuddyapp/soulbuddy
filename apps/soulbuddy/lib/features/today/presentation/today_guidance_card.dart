import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/today_guidance.dart';

class TodayGuidanceCard extends StatelessWidget {
  const TodayGuidanceCard({
    super.key,
    required this.guidance,
    required this.onOpen,
  });

  final TodayGuidanceCardValue guidance;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('today-guidance-${guidance.key.name}'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icon(guidance.key),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guidance.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(guidance.body),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('today-guidance-action'),
                    onPressed: onOpen,
                    child: Text(guidance.actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _icon(TodayGuidanceKey key) => switch (key) {
  TodayGuidanceKey.duePrayer ||
  TodayGuidanceKey.beginPrayer => Icons.volunteer_activism_outlined,
  TodayGuidanceKey.dueAction ||
  TodayGuidanceKey.startGoal => Icons.flag_outlined,
  TodayGuidanceKey.dueRemembrance ||
  TodayGuidanceKey.keepMemory => Icons.bookmark_outline,
  TodayGuidanceKey.circleAccountability => Icons.people_outline,
  TodayGuidanceKey.rememberPerson => Icons.person_outline,
  TodayGuidanceKey.remainClose ||
  TodayGuidanceKey.quietReturn => Icons.light_mode_outlined,
};
