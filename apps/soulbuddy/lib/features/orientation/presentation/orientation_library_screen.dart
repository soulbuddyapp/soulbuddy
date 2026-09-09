import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/presentation/sacred_surface.dart';
import '../domain/orientation_course.dart';
import '../providers/orientation_providers.dart';
import 'orientation_reader_screen.dart';
import 'orientation_path.dart';

class OrientationLibraryScreen extends ConsumerStatefulWidget {
  const OrientationLibraryScreen({
    required this.onClose,
    this.onSkip,
    this.initialNuggetId,
    super.key,
  });
  final VoidCallback onClose;
  final Future<void> Function()? onSkip;
  final String? initialNuggetId;
  @override
  ConsumerState<OrientationLibraryScreen> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<OrientationLibraryScreen> {
  static const _fullCourse = OrientationCourse(
    id: 'full-course',
    title: 'Aim for a Plentiful Harvest — Full Teaching',
    tenet: 'The complete seven-tenet teaching',
    duration: Duration(milliseconds: 726336),
    audioAsset: 'orientation/full-course.mp3',
    transcriptAsset: 'assets/orientation/full-course.json',
  );

  OrientationCourse? _selected;
  bool _appliedInitialNugget = false;
  void _select(OrientationCourse? course) {
    if (_selected != null) {
      ref.invalidate(orientationSavedProgressProvider(_selected!.id));
    }
    setState(() => _selected = course);
  }

  void _back() => _select(null);

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(orientationCatalogProvider);
    final loadedCourses = catalog.value;
    if (!_appliedInitialNugget &&
        widget.initialNuggetId != null &&
        loadedCourses != null) {
      _appliedInitialNugget = true;
      final matches = loadedCourses.where(
        (nugget) => nugget.id == widget.initialNuggetId,
      );
      if (matches.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selected == null) _select(matches.first);
        });
      }
    }
    final selected = _selected;
    if (selected != null) {
      final courses = catalog.value ?? const <OrientationCourse>[];
      final index = courses.indexWhere((course) => course.id == selected.id);
      final isFullCourse = selected.id == _fullCourse.id;
      final transcript = ref.watch(
        orientationTranscriptProvider(selected.transcriptAsset),
      );
      return transcript.when(
        loading: () => _status('Opening the Nugget…'),
        error: (_, _) => _status(
          'This Nugget could not be opened.',
          onRetry: () => ref.invalidate(
            orientationTranscriptProvider(selected.transcriptAsset),
          ),
        ),
        data: (value) => OrientationReaderScreen(
          key: ValueKey(selected.id),
          course: selected,
          transcript: value,
          onBack: _back,
          onSkip: widget.onSkip,
          courseIndex: index < 0 ? 0 : index,
          courseCount: isFullCourse ? 1 : courses.length,
          onPrevious: !isFullCourse && index > 0
              ? () => _select(courses[index - 1])
              : null,
          onNext: !isFullCourse && index >= 0 && index + 1 < courses.length
              ? () => _select(courses[index + 1])
              : null,
          reduceMotion:
              ref.watch(appFeedbackPreferencesProvider).value?.reducedMotion ??
              false,
        ),
      );
    }
    final theme = Theme.of(context);
    final journey = ref.watch(orientationJourneyStatusProvider).value;
    final large = MediaQuery.textScalerOf(context).scale(18) > 26;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: large ? 96 : 64,
        title: const Text(
          'Orientation',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (widget.onSkip != null)
            SizedBox(
              width: large ? 120 : 112,
              child: TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip for now', textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Orientation could not be opened.'),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(orientationCatalogProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (courses) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Aim for a plentiful harvest',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Eight memorable Nuggets. Listen, read along, and continue from where you stopped. Choose your own listening speed.',
                  ),
                  if (journey != null) ...[
                    const SizedBox(height: 20),
                    SacredSurface(
                      marble: true,
                      padding: const EdgeInsets.all(16),
                      child: OrientationPath(
                        completedCount: journey.completedCount,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  for (var i = 0; i < courses.length; i++)
                    Builder(
                      builder: (context) {
                        final course = courses[i];
                        final saved = ref
                            .watch(orientationSavedProgressProvider(course.id))
                            .value;
                        final label = saved?.completed == true
                            ? 'Listen again'
                            : (saved?.position ?? Duration.zero) > Duration.zero
                            ? 'Continue from where you stopped'
                            : 'Listen and read';
                        final seconds = course.duration.inSeconds;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            key: Key('orientation-course-${course.id}'),
                            onTap: () => _select(course),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NUGGET ${i + 1} OF ${courses.length} · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    course.title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(course.tenet),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        saved?.completed == true
                                            ? Icons.replay
                                            : Icons.play_circle_outline,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: InkWell(
                      key: const Key('orientation-full-course'),
                      onTap: () => _select(_fullCourse),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FULL TEACHING · ABOUT 12 MINUTES'),
                            SizedBox(height: 8),
                            Text(
                              'Read or listen to the full course',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'The complete seven-tenet teaching with motivational narration, gentle music, synchronized text, and adjustable speed.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(String text, {VoidCallback? onRetry}) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to orientation',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Try again'))
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
  );
}
