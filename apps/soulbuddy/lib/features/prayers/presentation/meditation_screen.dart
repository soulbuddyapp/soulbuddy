import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../formation/domain/formation_reading.dart';
import '../../formation/providers/formation_providers.dart';
import '../../orientation/providers/orientation_providers.dart';

class MeditationScreen extends ConsumerWidget {
  const MeditationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(orientationJourneyStatusProvider);
    final progress = ref.watch(formationProgressProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/prayers'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Prayers'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Meditation',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Read slowly, listen deeply, pray honestly, and carry one faithful action into your day.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              journey.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _OrientationInvitation(
                  onOpen: () => context.go('/orientation'),
                ),
                data: (value) => value.complete
                    ? const SizedBox.shrink()
                    : _OrientationInvitation(
                        progress:
                            '${value.completedCount} of 8 Nuggets complete',
                        action: value.started
                            ? 'Continue orientation'
                            : 'Start orientation',
                        onOpen: () {
                          final id = value.firstIncompleteId;
                          context.go(
                            id == null
                                ? '/orientation'
                                : '/orientation?nugget=$id',
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Scripture path',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Thirteen guided meditations, arranged to help you turn from sin, walk with the Holy Spirit, grow in virtue, and bear fruit.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      progress.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(formationProgressProvider),
                          child: const Text('Try again'),
                        ),
                        data: (value) {
                          final next = value.next(formationReadings);
                          final complete = value.completedIds.length.clamp(
                            0,
                            formationReadings.length,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                next.theme,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${next.reference} · $complete of ${formationReadings.length} complete',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FilledButton.icon(
                                key: const Key('meditation-continue-reading'),
                                onPressed: () => context.go(
                                  '/prayers/meditation/${next.id}',
                                ),
                                icon: const Icon(Icons.self_improvement),
                                label: Text(
                                  complete == 0
                                      ? 'Begin meditation'
                                      : 'Continue meditation',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'All meditations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              progress.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (value) => Column(
                  children: [
                    for (final reading in formationReadings)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            value.completedIds.contains(reading.id)
                                ? Icons.check_circle
                                : Icons.self_improvement_outlined,
                          ),
                          title: Text(reading.theme),
                          subtitle: Text(reading.reference),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.go('/prayers/meditation/${reading.id}'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrientationInvitation extends StatelessWidget {
  const _OrientationInvitation({
    required this.onOpen,
    this.progress = 'Begin with the eight memorable Nuggets.',
    this.action = 'Start orientation',
  });

  final VoidCallback onOpen;
  final String progress;
  final String action;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.65),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your foundation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(progress),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.play_arrow),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}
