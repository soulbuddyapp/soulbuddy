import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/sacred_piece.dart';
import '../../../core/presentation/sacred_piece_medallion.dart';
import '../../orientation/providers/orientation_providers.dart';
import '../../orientation/presentation/orientation_path.dart';
import '../domain/formation_reading.dart';
import '../providers/formation_providers.dart';

class FormationTodayCard extends ConsumerWidget {
  const FormationTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orientation = ref.watch(orientationJourneyStatusProvider);
    return orientation.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _card(
        context,
        eyebrow: 'FORMATION',
        title: 'Grow closer to God',
        body: 'Begin with the eight memorable Nuggets.',
        progress: null,
        piece: SacredPiece.orientation,
        orientationCompleted: 0,
        action: 'Start orientation',
        onPressed: () => context.push('/orientation'),
      ),
      data: (journey) {
        if (!journey.complete) {
          final action = journey.started
              ? 'Continue orientation'
              : 'Start orientation';
          final route = journey.firstIncompleteId == null
              ? '/orientation'
              : '/orientation?nugget=${journey.firstIncompleteId}';
          return _card(
            context,
            eyebrow: 'YOUR FORMATION PATH',
            title: 'Grow closer to God',
            body: 'Listen, read, and plant one good seed from the next Nugget.',
            progress: '${journey.completedCount} of 8 Nuggets complete',
            piece: SacredPiece.orientation,
            orientationCompleted: journey.completedCount,
            action: action,
            onPressed: () => context.push(route),
          );
        }
        final readings = ref.watch(formationProgressProvider);
        return readings.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => _card(
            context,
            eyebrow: 'SCRIPTURE FORMATION',
            title: 'Grow closer to God',
            body: formationReadings.first.theme,
            progress: formationReadings.first.reference,
            piece: SacredPiece.scripture,
            orientationCompleted: null,
            action: 'Begin meditation',
            onPressed: () => context.go('/prayers/meditation'),
          ),
          data: (progress) {
            final next = progress.next(formationReadings);
            final completed = progress.completedIds.length.clamp(
              0,
              formationReadings.length,
            );
            return _card(
              context,
              eyebrow: 'SCRIPTURE FORMATION',
              title: 'Grow closer to God',
              body: next.theme,
              progress:
                  '${next.reference} · $completed of ${formationReadings.length}',
              piece: SacredPiece.scripture,
              orientationCompleted: null,
              action: completed == 0 ? 'Begin meditation' : 'Continue reading',
              onPressed: () => context.go('/prayers/meditation/${next.id}'),
            );
          },
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String body,
    required String? progress,
    required SacredPiece piece,
    required int? orientationCompleted,
    required String action,
    required VoidCallback onPressed,
  }) => Card(
    key: const Key('formation-today-card'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SacredPieceMedallion(
                key: Key('formation-piece-${piece.name}'),
                piece: piece,
                decorative: true,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body),
          if (orientationCompleted != null) ...[
            const SizedBox(height: AppSpacing.md),
            OrientationPath(completedCount: orientationCompleted),
          ],
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              progress,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('formation-today-action'),
            onPressed: onPressed,
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}
