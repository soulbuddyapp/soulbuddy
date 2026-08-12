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
      child: InkWell(
        onTap: () => context.push('/remember/${encounter.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
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
                _typeLabel(encounter.memoryType),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                encounter.occurredOn,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.inkMuted),
              ),
              if (encounter.sensitive) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text('Sensitive memory'),
              ] else if (encounter.body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  encounter.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'What I left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};
