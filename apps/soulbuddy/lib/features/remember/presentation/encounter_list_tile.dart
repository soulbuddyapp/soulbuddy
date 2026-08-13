import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../record/domain/encounter.dart';
import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';

class EncounterListTile extends ConsumerWidget {
  const EncounterListTile({required this.encounter, super.key});

  final Encounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref
        .watch(memoryAudioForEncounterProvider(encounter.id))
        .whenOrNull(data: (value) => value);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
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
                          encounter.sensitive
                              ? 'Private memory'
                              : encounter.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (encounter.memoryType == MemoryType.promise) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const CovenantPairedSlabMark(
                          key: Key('promise-paired-slab-mark'),
                        ),
                      ],
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
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const CovenantIncisedDivider(),
                  if (!encounter.sensitive && encounter.body.isNotEmpty) ...[
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
          if (audio != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: AudioPlaybackControl(
                audio: audio,
                compact: true,
                label: encounter.sensitive ? 'Audio memory' : 'Voice recording',
              ),
            ),
        ],
      ),
    );
  }
}

String _typeLabel(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'What I left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};
