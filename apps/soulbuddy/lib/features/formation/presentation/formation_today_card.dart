import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/sacred_piece.dart';
import '../../../core/presentation/sacred_piece_medallion.dart';
import '../../../core/presentation/sacred_surface.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import '../../orientation/providers/orientation_providers.dart';
import '../../orientation/presentation/orientation_path.dart';
import '../../daily_formation/presentation/daily_formation_card.dart';
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
        body: 'Plant something good each day.',
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
            eyebrow: 'TODAY’S INVITATION',
            title: 'Grow closer to God',
            body: 'Plant something good each day.',
            progress: '${journey.completedCount} of 8 Nuggets complete',
            piece: SacredPiece.orientation,
            orientationCompleted: journey.completedCount,
            action: action,
            onPressed: () => context.push(route),
          );
        }
        if (journey.complete) return const DailyFormationCard();
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
            onPressed: () => context.push('/prayers/meditation'),
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
              onPressed: () => context.push('/prayers/meditation/${next.id}'),
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
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
      final invitation = SacredSurface(
        marble: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SacredPieceMedallion(
              key: Key('formation-piece-${piece.name}'),
              piece: piece,
              selected: true,
              decorative: true,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              eyebrow,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('formation-today-action'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Text(action, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
      return Column(
        key: const Key('formation-today-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (largeText || constraints.maxWidth < 280) ...[
            const SanctuaryArch(height: 240),
            const SizedBox(height: 18),
            invitation,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(flex: 10, child: SanctuaryArch(height: 330)),
                const SizedBox(width: 16),
                Expanded(flex: 10, child: invitation),
              ],
            ),
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
        ],
      );
    },
  );
}
