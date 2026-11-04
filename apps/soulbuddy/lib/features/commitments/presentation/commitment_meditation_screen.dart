import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/domain/prayer_narration.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import '../application/commitment_audio.dart';
import '../application/commitment_meditation_session_controller.dart';
import '../data/commitment_repository.dart';
import '../domain/commitment.dart';
import '../providers/commitment_providers.dart';
import '../providers/commitment_prayer_narration_providers.dart';
import 'commitment_audio_reader.dart';

Uri commitmentMemoryUri(String localDate) => Uri(
  path: '/remember/capture',
  queryParameters: {
    'mode': 'reflection',
    'source': 'commitment',
    'date': localDate,
    'title': 'Time with God · $localDate',
    'prompt': 'What do you want to remember from this time with God?',
  },
);

class CommitmentMeditationScreen extends ConsumerWidget {
  const CommitmentMeditationScreen({
    required this.commitmentId,
    this.listening = false,
    super.key,
  });
  final String commitmentId;
  final bool listening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(commitmentDetailsProvider(commitmentId));
    final identity = ref.watch(localIdentityProvider);
    final repository = ref.watch(commitmentRepositoryProvider);
    if (details.hasError || identity.hasError || repository.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session could not be loaded.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(commitmentDetailsProvider(commitmentId));
                  ref.invalidate(commitmentRepositoryProvider);
                  ref.invalidate(localIdentityProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!details.hasValue || !identity.hasValue || !repository.hasValue) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (details.value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Commitment unavailable.')),
      );
    }
    return _SessionHost(
      key: ValueKey('$commitmentId:$listening'),
      details: details.value!,
      deviceId: identity.value!.deviceId,
      repository: repository.value!,
      listening: listening,
    );
  }
}

class _SessionHost extends ConsumerStatefulWidget {
  const _SessionHost({
    required this.details,
    required this.deviceId,
    required this.repository,
    required this.listening,
    super.key,
  });
  final CommitmentDetails details;
  final String deviceId;
  final CommitmentRepository repository;
  final bool listening;
  @override
  ConsumerState<_SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends ConsumerState<_SessionHost> {
  late final CommitmentMeditationSessionController _controller;
  late final _BundledSessionAudio _guideAudio;
  CommitmentAudioAsset? _asset;
  MeditationSoundPreferences? _soundPreference;
  @override
  void initState() {
    super.initState();
    _guideAudio = _BundledSessionAudio();
    final minutes = widget.details.plan?.durationMinutes ?? 10;
    _controller = CommitmentMeditationSessionController(
      commitmentId: widget.details.commitment.id,
      sessionId: const Uuid().v7(),
      deviceId: widget.deviceId,
      kind: widget.listening
          ? CommitmentSessionKind.listening
          : CommitmentSessionKind.meditation,
      guideId: widget.listening
          ? 'listening_v1'
          : 'guide_${widget.details.commitment.guideId.wireValue}_v1',
      plannedDuration: Duration(
        minutes: widget.listening && minutes > 15 ? 10 : minutes,
      ),
      guide: _guideAudio,
      bell: _BundledSessionAudio(),
      bed: _BundledSessionAudio(),
      saveSession: (draft) async {
        await widget.repository.recordSession(draft);
      },
    );
    unawaited(_loadAsset());
    unawaited(_loadSound());
  }

  Future<void> _loadAsset() async {
    try {
      final asset = await loadCommitmentReading(_controller.guideId);
      if (mounted) setState(() => _asset = asset);
    } catch (_) {
      /* The session remains available without optional media. */
    }
  }

  Future<void> _loadSound() async {
    try {
      final preference = await ref
          .read(meditationSoundPreferencesProvider)
          .load();
      if (mounted) setState(() => _soundPreference = preference);
    } catch (_) {
      /* Silence remains available if preferences fail. */
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/commitments/${widget.details.commitment.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final narration = ref
        .watch(commitmentPreparedPrayerProvider(widget.details.commitment.id))
        .value;
    if (!_controller.started) {
      _controller.playPersonalPrayer = narration == null
          ? null
          : () => _guideAudio.playNarration(narration);
    }
    return CommitmentSessionView(
      details: widget.details,
      controller: _controller,
      guideAsset: _asset,
      initialSoundPreference: _soundPreference,
      onExit: _exit,
      onSoundSelected: (sound) => ref
          .read(meditationSoundPreferencesProvider)
          .save(
            MeditationSoundPreferences(
              sound: sound,
              volume: sound?.preferredVolume ?? .15,
            ),
          ),
    );
  }
}

class _BundledSessionAudio implements CommitmentSessionAudio {
  final CommitmentAudio _audio = CommitmentAudio();
  Future<void> playNarration(PrayerNarration narration) =>
      _audio.playBytes(narration.bytes, mimeType: narration.contentType);
  @override
  bool get complete => _audio.complete;
  @override
  bool get unavailable => _audio.unavailable;
  @override
  Duration get position => _audio.position;
  @override
  CommitmentAudioAsset? get asset => _audio.asset;
  @override
  void addListener(VoidCallback listener) => _audio.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _audio.removeListener(listener);
  @override
  Future<void> playGuide(String id) => _audio.play(id);
  @override
  Future<void> playPath(String path, {double volume = 1, bool loop = false}) =>
      _audio.playPath(path, volume: volume, loop: loop);
  @override
  Future<void> pause() => _audio.pause();
  @override
  Future<void> resume() => _audio.resume();
  @override
  Future<void> stop() => _audio.stop();
  @override
  Future<void> setSpeed(double speed) => _audio.setSpeed(speed);
  @override
  void dispose() => _audio.dispose();
}

/// Shared presentation for meditation and Listening. The controller is owned by
/// the parent so a background/route interruption cannot accidentally replace it.
class CommitmentSessionView extends StatefulWidget {
  const CommitmentSessionView({
    required this.details,
    required this.controller,
    required this.onExit,
    this.guideAsset,
    this.onSoundSelected,
    this.initialSoundPreference,
    super.key,
  });
  final CommitmentDetails details;
  final CommitmentMeditationSessionController controller;
  final CommitmentAudioAsset? guideAsset;
  final VoidCallback onExit;
  final Future<void> Function(MeditationSoundBed?)? onSoundSelected;
  final MeditationSoundPreferences? initialSoundPreference;
  @override
  State<CommitmentSessionView> createState() => _CommitmentSessionViewState();
}

class _CommitmentSessionViewState extends State<CommitmentSessionView> {
  CommitmentMeditationSessionController get session => widget.controller;
  MeditationSoundBed? _sound;
  String? _soundError;
  bool _framePending = false;
  bool _soundChosen = false;
  bool _recordingBusy = false;
  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    _restoreSound();
  }

  @override
  void didUpdateWidget(covariant CommitmentSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSoundPreference != widget.initialSoundPreference) {
      _restoreSound();
    }
  }

  void _restoreSound() {
    if (_soundChosen || session.started) return;
    final preference = widget.initialSoundPreference;
    if (preference == null) return;
    _sound = preference.sound;
    session.soundPath = _sound == null ? null : 'assets/${_sound!.assetPath}';
    session.soundVolume = preference.volume;
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_framePending) return;
      _framePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _framePending = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _exit() async {
    if (_recordingBusy) return;
    await session.pauseForInterruption();
    if (mounted) widget.onExit();
  }

  Future<void> _showDetails() async {
    await session.pause();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.details.commitment.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text('Needs', style: Theme.of(context).textTheme.titleMedium),
            for (final need in [
              widget.details.commitment.keyNeedOne,
              widget.details.commitment.keyNeedTwo,
              widget.details.commitment.keyNeedThree,
            ])
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(need),
              ),
            const SizedBox(height: 24),
            Text('Calling', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(widget.details.commitment.calling),
            const SizedBox(height: 24),
            Text(
              'Daily practices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final practice in widget.details.practices)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(practice.body),
              ),
            if (widget.details.declaration case final declaration?) ...[
              const SizedBox(height: 24),
              Text(
                'Declaration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(declaration.body),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listening = session.kind == CommitmentSessionKind.listening;
    return PracticeAudioScope(
      onVisibilityChanged: (visible) {
        if (visible) {
          session.becameVisible();
        } else {
          unawaited(session.pauseForInterruption());
        }
      },
      child: ScreenAwake(
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            title: Text(
              listening ? 'Listening and discernment' : 'Time with God',
            ),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: _exit,
              icon: const Icon(Icons.close),
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: .12,
                    child: Image.asset(
                      'assets/images/sanctuary/sacred_hour_portal.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                        children: session.terminal
                            ? _ending(context)
                            : switch (session.phase) {
                                CommitmentSessionPhase.preparation =>
                                  _preparation(context),
                                CommitmentSessionPhase.guiding => _guidance(
                                  context,
                                ),
                                CommitmentSessionPhase.paused => _paused(
                                  context,
                                ),
                                CommitmentSessionPhase.timing => _timing(
                                  context,
                                ),
                                _ => _settling(context),
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
  Widget _space([double height = 24]) => SizedBox(height: height);
  Widget _button(String label, VoidCallback? action) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: FilledButton(onPressed: action, child: Text(label)),
  );
  Widget _speed() => DropdownButtonFormField<double>(
    isExpanded: true,
    initialValue: session.speed,
    decoration: const InputDecoration(labelText: 'Voice speed'),
    items: [
      for (final rate in [.7, .85, 1.0, 1.15])
        DropdownMenuItem(value: rate, child: Text('${rate}x')),
    ],
    onChanged: (value) {
      if (value != null) unawaited(session.setSpeed(value));
    },
  );

  List<Widget> _preparation(BuildContext context) => [
    _heading(context, widget.details.commitment.name),
    _space(12),
    Text(
      session.kind == CommitmentSessionKind.listening
          ? 'Listen without forcing a feeling or an answer.'
          : switch (widget.details.commitment.guideId) {
              CommitmentGuideId.surrender => 'Surrender',
              CommitmentGuideId.direction => 'Direction',
              CommitmentGuideId.peace => 'Peace',
            },
      style: Theme.of(context).textTheme.titleMedium,
    ),
    _space(),
    const Text(
      'Bring your notebook and a pen. Find somewhere quiet, if you can.',
    ),
    _space(),
    DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: session.plannedDuration.inMinutes,
      decoration: const InputDecoration(labelText: 'Quiet time'),
      items: [
        for (final minutes
            in (session.kind == CommitmentSessionKind.listening
                ? [5, 10, 15]
                : [5, 10, 15, 20, 30]))
          DropdownMenuItem(value: minutes, child: Text('$minutes minutes')),
      ],
      onChanged: (value) {
        if (value != null) session.setDuration(Duration(minutes: value));
      },
    ),
    _space(),
    _speed(),
    _space(),
    if (session.playPersonalPrayer != null) ...[
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Personal prayer'),
        value: session.includePersonalPrayer,
        onChanged: (value) =>
            setState(() => session.includePersonalPrayer = value),
      ),
      _space(),
    ],
    MeditationSoundPicker(
      selected: _sound,
      onSelected: (sound) async {
        setState(() {
          _soundChosen = true;
          _sound = sound;
          _soundError = null;
        });
        session.soundPath = sound == null ? null : 'assets/${sound.assetPath}';
        session.soundVolume = sound?.preferredVolume ?? .15;
        try {
          await widget.onSoundSelected?.call(sound);
        } catch (_) {
          if (mounted) {
            setState(
              () => _soundError = 'Sound preference could not be saved.',
            );
          }
        }
      },
    ),
    if (_soundError != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_soundError!),
      ),
    _space(),
    _button('Begin session', () => unawaited(session.begin())),
    TextButton(onPressed: _showDetails, child: const Text('Review commitment')),
  ];

  List<Widget> _guidance(BuildContext context) {
    if (session.personalPrayerPlaying) {
      return [
        _heading(context, 'Personal prayer'),
        _space(40),
        _speed(),
        _space(),
        _button('Pause', () => unawaited(session.pause())),
        TextButton(
          onPressed: () => unawaited(session.end()),
          child: const Text('End'),
        ),
      ];
    }
    final asset = widget.guideAsset ?? session.guide.asset;
    final position = session.guide.position.inMilliseconds;
    final cue = asset?.captions
        .where(
          (cue) =>
              position >= (cue['startMs'] as num) &&
              position < (cue['endMs'] as num),
        )
        .firstOrNull;
    return [
      _heading(context, 'Be still.'),
      _space(),
      if (session.guideUnavailable)
        const Text('Voice is unavailable. Continue with the prayer.'),
      if (asset != null) ...[
        if (session.guideUnavailable)
          Text(
            asset.transcript,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.6),
          )
        else
          Text(
            cue?['text'] as String? ?? 'Be still, and know that I am God.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        if (session.kind == CommitmentSessionKind.meditation)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Psalm 46:10 · RSVCE'),
          ),
        _space(),
        ExpansionTile(
          title: const Text('Full prayer'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                asset.transcript,
                style: const TextStyle(height: 1.6),
              ),
            ),
          ],
        ),
      ] else
        const Text(
          'Turn toward the Father through Jesus. Present your needs, calling, and daily practices. Now listen.',
        ),
      _space(),
      _speed(),
      _space(),
      if (session.guideUnavailable)
        _button(
          'Begin quiet time',
          () => unawaited(session.continueAfterGuide()),
        )
      else
        _button('Pause', () => unawaited(session.pause())),
      TextButton(
        onPressed: () => unawaited(session.end()),
        child: const Text('End'),
      ),
    ];
  }

  Widget _clock(BuildContext context) {
    final seconds = (session.remaining.inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    return Semantics(
      label: 'Time remaining',
      value: '$minutes minutes ${seconds % 60} seconds',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$minutes:${(seconds % 60).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 80,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _timing(BuildContext context) => [
    TextButton(
      onPressed: _showDetails,
      child: Text(widget.details.commitment.name),
    ),
    _space(56),
    _clock(context),
    _space(56),
    _button('Pause', () => unawaited(session.pause())),
    TextButton(
      onPressed: () => unawaited(session.end()),
      child: const Text('End'),
    ),
  ];
  List<Widget> _paused(BuildContext context) => [
    _heading(context, 'Paused'),
    _space(),
    TextButton(
      onPressed: _showDetails,
      child: Text(widget.details.commitment.name),
    ),
    _space(24),
    _clock(context),
    _space(40),
    _button('Resume', () => unawaited(session.resume())),
    TextButton(
      onPressed: () => unawaited(session.end()),
      child: const Text('End'),
    ),
  ];
  List<Widget> _settling(BuildContext context) => [
    _space(56),
    _heading(context, 'Be still.'),
    _space(56),
    _button('Pause', () => unawaited(session.pause())),
    TextButton(
      onPressed: () => unawaited(session.end()),
      child: const Text('End'),
    ),
  ];
  List<Widget> _ending(BuildContext context) => [
    _heading(context, 'What do you want to remember from this time with God?'),
    _space(),
    if (session.kind == CommitmentSessionKind.listening) ...[
      const Text('What might need prayer, Scripture, or wise counsel?'),
      _space(),
    ],
    if (session.saving) const Text('Saving session…'),
    if (session.saveFailed) ...[
      const Text('Session could not be saved.'),
      _space(12),
      _button('Retry saving', () => unawaited(session.retrySave())),
      _space(),
    ],
    InlineMemoryRecorder(
      label: 'Record a memory',
      enabled: session.saved,
      initialDate: DateTime.tryParse(session.terminalDraft?.localDate ?? ''),
      initialTitle: 'Time with God · ${session.terminalDraft?.localDate ?? ''}',
      privateReflection: true,
      enableSoundscape: false,
      beforeStart: session.pauseForInterruption,
      onBusyChanged: (busy) {
        if (mounted) setState(() => _recordingBusy = busy);
      },
    ),
    TextButton(
      onPressed: _recordingBusy ? null : _exit,
      child: const Text('End'),
    ),
  ];
}
