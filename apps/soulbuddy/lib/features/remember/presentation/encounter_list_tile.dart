import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../record/domain/encounter.dart';

class EncounterListTile extends StatelessWidget {
  const EncounterListTile({required this.encounter, super.key});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    encounter.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (encounter.isAltar) ...[
                  const SizedBox(width: AppSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text('Altar'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              encounter.occurredOn,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.inkMuted),
            ),
            if (encounter.body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                encounter.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.push('/remember/scripture/John/3'),
                child: const Text('Open John 3'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
