import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/orientation_controller.dart';
import '../domain/orientation_course.dart';
import '../providers/orientation_providers.dart';
import 'orientation_transcript_view.dart';

class OrientationReaderScreen extends ConsumerStatefulWidget {
  const OrientationReaderScreen({
    required this.course,
    required this.transcript,
    required this.onBack,
    this.onSkip,
    this.onPrevious,
    this.onNext,
    this.courseIndex = 0,
    this.courseCount = 1,
    this.controller,
    this.reduceMotion = false,
    super.key,
  });
  final OrientationCourse course;
  final OrientationTranscript transcript;
  final VoidCallback onBack;
  final Future<void> Function()? onSkip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int courseIndex;
  final int courseCount;
  final OrientationController? controller;
  final bool reduceMotion;
  @override
  ConsumerState<OrientationReaderScreen> createState() => _ReaderState();
}

class _ReaderState extends ConsumerState<OrientationReaderScreen>
    with WidgetsBindingObserver {
  late final OrientationController _controller;
  bool _following = true, _leaving = false;
  bool _completionNotified = false;
  double? _scrub;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        widget.controller ??
        OrientationController(
          course: widget.course,
          transcript: widget.transcript,
          player: ref.read(orientationPlayerFactoryProvider)(),
          repository: ref.read(orientationProgressRepositoryProvider),
        );
    _controller.addListener(_changed);
    unawaited(_controller.initialize());
  }

  void _changed() {
    if (_controller.completed && !_completionNotified) {
      _completionNotified = true;
      ref.invalidate(orientationSavedProgressProvider(widget.course.id));
      ref.invalidate(orientationJourneyStatusProvider);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    unawaited(_controller.close().whenComplete(_controller.dispose));
    super.dispose();
  }

  Future<void> _leave({bool skip = false, VoidCallback? destination}) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _controller.close();
    if (!mounted) return;
    if (skip && widget.onSkip != null) {
      await widget.onSkip!();
    } else {
      (destination ?? widget.onBack)();
    }
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  String _rate(double rate) => rate.toString().replaceAll(RegExp(r'\.0$'), '');

  void _showStatus() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .65,
        minChildSize: .3,
        maxChildSize: .9,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Listening status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_controller.error != null) ...[
              Text(_controller.error!),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_controller.initialize());
                },
                child: const Text('Try audio again'),
              ),
            ],
            if (_controller.persistenceWarning != null) ...[
              const SizedBox(height: 8),
              Text(_controller.persistenceWarning!),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep reading'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResponse() {
    final response = _nuggetResponse(widget.course.id, widget.course.tenet);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Carry this Nugget with you',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ResponsePrompt(label: 'PRAY', text: response.prayer),
            const SizedBox(height: 12),
            _ResponsePrompt(label: 'REFLECT', text: response.reflection),
            const SizedBox(height: 12),
            _ResponsePrompt(label: 'PLANT', text: response.action),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/remember/capture?mode=write&source=orientation');
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Save a private reflection'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/prayers/create');
              },
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Save a prayer'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/welcome/goal');
              },
              icon: const Icon(Icons.spa_outlined),
              label: const Text('Turn the seed into a Goal'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _controller;
    final duration = widget.course.duration.inMilliseconds
        .toDouble()
        .clamp(1.0, double.infinity)
        .toDouble();
    final large = MediaQuery.textScalerOf(context).scale(18) > 26;
    final reduceMotion =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: large ? 96 : 64,
          leading: IconButton(
            tooltip: 'Back to orientation',
            onPressed: _leaving ? null : () => _leave(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          actions: [
            IconButton(
              key: const Key('orientation-respond'),
              tooltip: 'Pray, reflect, and plant',
              onPressed: _showResponse,
              icon: const Icon(Icons.spa_outlined),
            ),
            if (widget.onSkip != null)
              SizedBox(
                width: large ? 120 : 112,
                child: TextButton(
                  onPressed: _leaving ? null : () => _leave(skip: true),
                  child: const Text(
                    'Skip for now',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PopupMenuButton<double>(
                          key: const Key('orientation-speed'),
                          tooltip: 'Playback speed',
                          initialValue: c.speed,
                          enabled: !c.loading && !_leaving,
                          onSelected: (speed) => unawaited(c.setSpeed(speed)),
                          itemBuilder: (_) => [
                            for (final speed in OrientationController.speeds)
                              PopupMenuItem(
                                value: speed,
                                child: Text('${_rate(speed)}×'),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed, size: 20),
                                const SizedBox(width: 6),
                                Text('${_rate(c.speed)}×'),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<double>(
                          key: const Key('orientation-text-size'),
                          tooltip: 'Text size',
                          initialValue: c.textScale,
                          onSelected: (scale) =>
                              unawaited(c.setTextScale(scale)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: .85, child: Text('Smaller')),
                            PopupMenuItem(value: 1.0, child: Text('Standard')),
                            PopupMenuItem(value: 1.2, child: Text('Large')),
                            PopupMenuItem(value: 1.4, child: Text('Larger')),
                            PopupMenuItem(value: 1.6, child: Text('Largest')),
                          ],
                          icon: const Icon(Icons.text_fields),
                        ),
                        TextButton.icon(
                          key: const Key('orientation-follow'),
                          onPressed: () =>
                              setState(() => _following = !_following),
                          icon: Icon(
                            _following ? Icons.sync : Icons.my_location,
                            size: 18,
                          ),
                          label: Text(
                            _following ? 'Following' : 'Follow narration',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.error != null || c.persistenceWarning != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: [
                          c.error,
                          c.persistenceWarning,
                        ].whereType<String>().join(' '),
                        child: TextButton.icon(
                          key: const Key('orientation-status'),
                          onPressed: _showStatus,
                          icon: const Icon(Icons.info_outline, size: 20),
                          label: Text(
                            c.error != null ? 'Audio help' : 'Save help',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: OrientationTranscriptView(
                      transcript: widget.transcript,
                      position: c.position,
                      following: _following,
                      textScale: c.textScale,
                      reduceMotion: reduceMotion,
                      onManualScroll: () => setState(() => _following = false),
                      onSeek: (position) => unawaited(c.seek(position)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.courseCount > 1)
                          Row(
                            children: [
                              if (large)
                                IconButton(
                                  key: const Key('orientation-previous-course'),
                                  tooltip: 'Previous Nugget',
                                  onPressed:
                                      _leaving || widget.onPrevious == null
                                      ? null
                                      : () => _leave(
                                          destination: widget.onPrevious,
                                        ),
                                  icon: const Icon(Icons.chevron_left),
                                )
                              else
                                TextButton(
                                  key: const Key('orientation-previous-course'),
                                  onPressed:
                                      _leaving || widget.onPrevious == null
                                      ? null
                                      : () => _leave(
                                          destination: widget.onPrevious,
                                        ),
                                  child: const Text('Previous'),
                                ),
                              Expanded(
                                child: Text(
                                  'Nugget ${widget.courseIndex + 1} of ${widget.courseCount}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              if (large)
                                IconButton(
                                  key: const Key('orientation-next-course'),
                                  tooltip: 'Next Nugget',
                                  onPressed: _leaving || widget.onNext == null
                                      ? null
                                      : () =>
                                            _leave(destination: widget.onNext),
                                  icon: const Icon(Icons.chevron_right),
                                )
                              else
                                TextButton(
                                  key: const Key('orientation-next-course'),
                                  onPressed: _leaving || widget.onNext == null
                                      ? null
                                      : () =>
                                            _leave(destination: widget.onNext),
                                  child: const Text('Next'),
                                ),
                            ],
                          ),
                        Semantics(
                          label: 'Listening position',
                          child: Slider(
                            key: const Key('orientation-seek'),
                            min: 0,
                            max: duration,
                            value:
                                (_scrub ?? c.position.inMilliseconds.toDouble())
                                    .clamp(0.0, duration)
                                    .toDouble(),
                            semanticFormatterCallback: (value) =>
                                _time(Duration(milliseconds: value.round())),
                            onChanged: c.loading
                                ? null
                                : (value) => setState(() => _scrub = value),
                            onChangeEnd: (value) {
                              setState(() => _scrub = null);
                              unawaited(
                                c.seek(Duration(milliseconds: value.round())),
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _time(c.position),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              _time(widget.course.duration),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Start again',
                              onPressed: c.loading
                                  ? null
                                  : () => unawaited(c.startAgain()),
                              icon: const Icon(Icons.replay),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FilledButton.icon(
                                key: const Key('orientation-play'),
                                onPressed: c.loading || c.busy || _leaving
                                    ? null
                                    : () => unawaited(c.toggle()),
                                icon: c.loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        c.playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                label: Text(
                                  c.loading
                                      ? 'Opening…'
                                      : c.playing
                                      ? 'Pause'
                                      : c.completed
                                      ? 'Replay'
                                      : c.position > Duration.zero
                                      ? 'Continue'
                                      : 'Play',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Forward 10 seconds',
                              onPressed: c.loading
                                  ? null
                                  : () => unawaited(
                                      c.seek(
                                        c.position +
                                            const Duration(seconds: 10),
                                      ),
                                    ),
                              icon: const Icon(Icons.forward_10),
                            ),
                          ],
                        ),
                      ],
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
}

class _ResponsePrompt extends StatelessWidget {
  const _ResponsePrompt({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    ),
  );
}

class _NuggetResponse {
  const _NuggetResponse(this.prayer, this.reflection, this.action);
  final String prayer;
  final String reflection;
  final String action;
}

_NuggetResponse _nuggetResponse(String id, String tenet) => switch (id) {
  '01-pull-the-weeds' => const _NuggetResponse(
    'Jesus, show me the weed while it is small, and give me courage to pull it early.',
    'What temptation have I been negotiating with?',
    'Remove one small opening for sin today.',
  ),
  '02-the-open-door' => const _NuggetResponse(
    'Jesus, help me rise in your victory instead of hiding in shame.',
    'Where do I need to receive mercy and begin again?',
    'Take one hopeful step back toward God.',
  ),
  '03-make-room-to-listen' => const _NuggetResponse(
    'Holy Spirit, quiet my noise and lead me in truth.',
    'What decision needs prayerful listening?',
    'Pause for one minute before the next important choice.',
  ),
  '04-the-song-she-could-play' => const _NuggetResponse(
    'Lord, make me faithful with the gifts you have entrusted to me.',
    'Which gift needs steady practice?',
    'Give ten focused minutes to one useful discipline.',
  ),
  '05-more-than-her-name' => const _NuggetResponse(
    'Jesus, free me from comparison and make my gifts useful in service.',
    'Where am I seeking recognition more than service?',
    'Do one helpful thing without announcing it.',
  ),
  '06-the-lunch-no-one-saw' => const _NuggetResponse(
    'Father, teach me to notice and love the person in front of me.',
    'Who near me may be carrying a hidden need?',
    'Offer one quiet act of generosity today.',
  ),
  '07-what-did-it-grow' => const _NuggetResponse(
    'Jesus, keep me close to you and let good fruit reach others through my life.',
    'Who could be helped by what God has placed in my hands?',
    'Plant something good in the garden today.',
  ),
  _ => _NuggetResponse(
    'God, help me receive this truth and live it with love.',
    'What is one part of “$tenet” I need to carry today?',
    'Choose one small good seed and plant it today.',
  ),
};
