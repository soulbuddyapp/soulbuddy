import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/sacred_surface.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import '../../orientation/data/orientation_progress_repository.dart';
import '../../orientation/domain/orientation_course.dart';
import '../../orientation/presentation/orientation_path.dart';
import '../../orientation/presentation/orientation_reader_screen.dart';
import '../../orientation/providers/orientation_providers.dart';
import '../../goals/presentation/create_meditation_goal.dart';
import '../providers/kingdom_course_providers.dart';

class KingdomCourseScreen extends ConsumerStatefulWidget {
  const KingdomCourseScreen({this.initialNuggetId, this.onClose, super.key});

  final String? initialNuggetId;
  final VoidCallback? onClose;

  @override
  ConsumerState<KingdomCourseScreen> createState() =>
      _KingdomCourseScreenState();
}

class _KingdomCourseScreenState extends ConsumerState<KingdomCourseScreen> {
  OrientationCourse? _selected;
  var _openedInitial = false;

  void _select(OrientationCourse? nugget) {
    setState(() => _selected = nugget);
    ref.invalidate(kingdomJourneyStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(orientationJourneyStatusProvider);
    if (foundation case AsyncData(value: final status)) {
      if (!status.complete) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kingdom life'),
            actions: [
              IconButton(
                onPressed: widget.onClose,
                tooltip: 'Close',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Begin with Orientation',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text('${status.completedCount} of 8 Nuggets complete'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/orientation'),
                      child: const Text('Continue Orientation'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } else if (foundation.hasError) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: widget.onClose,
              tooltip: 'Close',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(orientationJourneyStatusProvider),
            child: const Text('Try again'),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: widget.onClose,
              tooltip: 'Close',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final catalog = ref.watch(kingdomCatalogProvider);
    final nuggets = catalog.value;
    if (!_openedInitial && nuggets != null && widget.initialNuggetId != null) {
      _openedInitial = true;
      for (final nugget in nuggets) {
        if (nugget.id == widget.initialNuggetId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _select(nugget);
          });
          break;
        }
      }
    }
    if (_selected case final selected?) {
      final index = nuggets?.indexWhere((item) => item.id == selected.id) ?? -1;
      final transcript = ref.watch(
        orientationTranscriptProvider(selected.transcriptAsset),
      );
      return transcript.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => ref.invalidate(
                orientationTranscriptProvider(selected.transcriptAsset),
              ),
              child: const Text('Try again'),
            ),
          ),
        ),
        data: (value) => OrientationReaderScreen(
          key: ValueKey(selected.id),
          course: selected,
          transcript: value,
          onBack: () => _select(null),
          onPrevious: index > 0 ? () => _select(nuggets![index - 1]) : null,
          onNext: nuggets != null && index >= 0 && index + 1 < nuggets.length
              ? () => _select(nuggets[index + 1])
              : null,
          courseIndex: index < 0 ? 0 : index,
          courseCount: nuggets?.length ?? 1,
          collectionName: 'Kingdom life',
          onCompleted: () {
            ref.invalidate(kingdomJourneyStatusProvider);
            ref.invalidate(kingdomMeditationReadyProvider);
          },
        ),
      );
    }

    final journey = ref.watch(kingdomJourneyStatusProvider).value;
    final meditationReady =
        ref.watch(kingdomMeditationReadyProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kingdom life'),
        actions: [
          IconButton(
            onPressed: widget.onClose,
            tooltip: 'Close',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(kingdomCatalogProvider),
                  child: const Text('Try again'),
                ),
              ),
              data: (courses) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SanctuaryReadingHeading(
                    title: 'Life in the Kingdom',
                    art: SanctuaryArt.renewal,
                    subtitle: 'Love God. Serve others. Care for creation.',
                  ),
                  const SizedBox(height: 20),
                  if (journey != null)
                    SacredSurface(
                      padding: const EdgeInsets.all(16),
                      child: OrientationPath(
                        completedCount: journey.completedCount,
                        total: courses.length,
                      ),
                    ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < courses.length; i++) ...[
                    _KingdomNuggetTile(
                      course: courses[i],
                      index: i,
                      progress: ref
                          .watch(
                            orientationSavedProgressProvider(courses[i].id),
                          )
                          .value,
                      onTap: () => _select(courses[i]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (meditationReady) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => createMeditationGoal(context, ref),
                      icon: const Icon(Icons.self_improvement),
                      label: const Text('Name a meditation Goal'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/goals'),
                      child: const Text('My Collection'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KingdomNuggetTile extends StatelessWidget {
  const _KingdomNuggetTile({
    required this.course,
    required this.index,
    required this.progress,
    required this.onTap,
  });
  final OrientationCourse course;
  final int index;
  final OrientationProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: Key('kingdom-nugget-${course.id}'),
      leading: CircleAvatar(
        child: progress?.completed == true
            ? const Icon(Icons.check, size: 18)
            : Text('${index + 1}'),
      ),
      title: Text(course.title),
      subtitle: Text(
        '${course.tenet} · ${course.duration.inSeconds ~/ 60}:${(course.duration.inSeconds % 60).toString().padLeft(2, '0')}',
      ),
      trailing: Icon(
        progress?.completed == true ? Icons.replay : Icons.play_arrow,
      ),
      onTap: onTap,
    ),
  );
}
