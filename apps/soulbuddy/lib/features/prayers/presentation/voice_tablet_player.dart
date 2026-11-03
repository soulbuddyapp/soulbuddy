import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_controller.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/domain/memory_soundscape.dart';
import '../../record/audio/presentation/soundscape_controls.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../data/prayer_practice_repository.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_session.dart';
import '../domain/voice_tablet.dart';
import '../providers/prayer_practice_providers.dart';
import '../providers/voice_tablet_providers.dart';
import 'voice_tablet_sheet.dart';
import 'meditation_session_sheet.dart';

class VoiceTabletSection extends ConsumerWidget {
  const VoiceTabletSection({
    required this.source,
    required this.title,
    required this.prayerBody,
    this.onKeepOnAltar,
    this.compact = false,
    this.showPrayerActions = true,
    super.key,
  });

  final VoiceTabletSource source;
  final String title;
  final String prayerBody;
  final FutureOr<void> Function(VoiceTablet)? onKeepOnAltar;
  final bool compact;
  final bool showPrayerActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablet = ref.watch(voiceTabletForSourceProvider(source));
    return tablet.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => OutlinedButton.icon(
        onPressed: () => ref.invalidate(voiceTabletForSourceProvider(source)),
        icon: const Icon(Icons.refresh),
        label: const Text('Try Voice Tablet again'),
      ),
      data: (value) => value == null
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
              ),
              onPressed: () => showVoiceTabletSheet(
                context,
                source: source,
                title: title,
                prayerBody: prayerBody,
              ),
              icon: const Icon(Icons.mic_none),
              label: const Text('Record in my voice'),
            )
          : VoiceTabletPlayer(
              tablet: value,
              onKeepOnAltar: onKeepOnAltar,
              compact: compact,
              showPrayerActions: showPrayerActions,
            ),
    );
  }
}

class VoiceTabletPlayer extends ConsumerStatefulWidget {
  const VoiceTabletPlayer({
    required this.tablet,
    this.onRecordAgain,
    this.onKeepOnAltar,
    this.onPlayed,
    this.onPrayed,
    this.compact = false,
    this.showPrayerActions = true,
    super.key,
  });

  final VoiceTablet tablet;
  final VoidCallback? onRecordAgain;
  final FutureOr<void> Function(VoiceTablet)? onKeepOnAltar;
  final FutureOr<void> Function(VoiceTabletAudio)? onPlayed;
  final FutureOr<void> Function()? onPrayed;
  final bool compact;
  final bool showPrayerActions;

  @override
  ConsumerState<VoiceTabletPlayer> createState() => _VoiceTabletPlayerState();
}

class _VoiceTabletPlayerState extends ConsumerState<VoiceTabletPlayer> {
  late VoiceTabletAudioKind _selectedKind;
  var _savingPrayer = false;
  var _removing = false;
  PrayerSession? _lastSession;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _selectedKind = VoiceTabletAudioKind.fullPrayer;
  }

  VoiceTabletAudio? get _selectedAudio =>
      _selectedKind == VoiceTabletAudioKind.refrain
      ? widget.tablet.refrainAudio
      : widget.tablet.fullAudio;

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(memoryAudioPlaybackCoordinatorProvider);
    final spiritualSession = ref.watch(spiritualSessionControllerProvider);
    return ClipPath(
      clipper: const _VoiceTabletClipper(),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: widget.compact
              ? const EdgeInsets.all(AppSpacing.sm)
              : const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.compact) ...[
                    const CovenantPairedSlabMark(),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.compact)
                          Text(
                            'Voice Tablet',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        Text(
                          widget.compact ? 'My recording' : widget.tablet.title,
                          style: widget.compact
                              ? Theme.of(context).textTheme.titleSmall
                              : Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_TabletAction>(
                    tooltip: 'Voice Tablet options',
                    enabled: !_removing,
                    onSelected: _handleMenu,
                    itemBuilder: (_) => [
                      if (widget.compact && widget.onKeepOnAltar != null)
                        const PopupMenuItem(
                          value: _TabletAction.keepOnAltar,
                          child: Text('Keep on my Altar'),
                        ),
                      if (widget.onRecordAgain != null)
                        const PopupMenuItem(
                          value: _TabletAction.recordAgain,
                          child: Text('Record again'),
                        ),
                      const PopupMenuItem(
                        value: _TabletAction.remove,
                        child: Text('Remove Voice Tablet'),
                      ),
                    ],
                  ),
                ],
              ),
              if (!widget.compact) const CovenantIncisedDivider(),
              if (widget.tablet.refrainAudio != null) ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Full prayer'),
                      selected:
                          _selectedKind == VoiceTabletAudioKind.fullPrayer,
                      onSelected: (_) => _select(
                        VoiceTabletAudioKind.fullPrayer,
                        coordinator.value,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Refrain'),
                      selected: _selectedKind == VoiceTabletAudioKind.refrain,
                      onSelected: (_) => _select(
                        VoiceTabletAudioKind.refrain,
                        coordinator.value,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: widget.compact ? AppSpacing.xs : AppSpacing.md,
                ),
              ],
              if (_selectedAudio case final audio?) ...[
                if (!widget.compact) ...[
                  _Waveform(samples: audio.waveform),
                  const SizedBox(height: AppSpacing.sm),
                ],
                coordinator.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Text(
                    'Playback is unavailable just now.',
                    textAlign: TextAlign.center,
                  ),
                  data: (value) => _PlaybackControls(
                    coordinator: value,
                    audio: audio,
                    onPlayed: widget.onPlayed,
                    spiritualSession: spiritualSession,
                    title: widget.tablet.title,
                    route: _tabletRoute(widget.tablet.source),
                    prepareSessionComplete: _preparePrayerCompletion,
                    compact: widget.compact,
                  ),
                ),
              ] else
                const Text(
                  'This recording is not on this device.',
                  textAlign: TextAlign.center,
                ),
              if (!widget.compact) ...[
                if (_selectedAudio case final selectedAudio?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                    ),
                    onPressed: () => showMeditationSessionSheet(
                      context,
                      ref,
                      tablet: widget.tablet,
                      selectedAudio: selectedAudio,
                    ),
                    icon: const Icon(Icons.self_improvement_outlined),
                    label: const Text('Pray and remain'),
                  ),
                ],
              ],
              if (widget.showPrayerActions) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                  ),
                  onPressed: _savingPrayer ? null : _recordPrayer,
                  icon: _savingPrayer
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _lastSession == null ? 'I prayed' : 'Prayed today',
                  ),
                ),
                if (_lastSession != null)
                  Center(
                    child: TextButton(
                      onPressed: _savingPrayer ? null : _undoPrayer,
                      child: const Text('Undo'),
                    ),
                  ),
              ],
              if (!widget.compact && widget.onKeepOnAltar != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                  ),
                  onPressed: () => widget.onKeepOnAltar!(widget.tablet),
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Keep on my Altar'),
                ),
              ],
              if (_actionError case final error?) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    VoiceTabletAudioKind kind,
    MemoryAudioPlaybackCoordinator? coordinator,
  ) async {
    if (kind == _selectedKind) return;
    final audioId = _selectedAudio?.id;
    if (audioId != null && coordinator?.state.assetId == audioId) {
      final spiritual = ref.read(spiritualSessionControllerProvider);
      if (spiritual.state.session?.id == 'prayer:$audioId') {
        await spiritual.close();
      } else {
        await ref.read(memorySoundscapePlaybackProvider).stop(audioId);
        await coordinator?.stop();
      }
    }
    if (mounted) setState(() => _selectedKind = kind);
  }

  Future<void> _recordPrayer() async {
    if (_savingPrayer) return;
    setState(() {
      _savingPrayer = true;
      _actionError = null;
    });
    try {
      final recordPrayer = _preparePrayerCompletion();
      await recordPrayer();
      if (mounted) setState(() => _savingPrayer = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _actionError = 'Could not record this prayer just now.';
        });
      }
    }
  }

  Future<void> Function() _preparePrayerCompletion() {
    final onPrayed = widget.onPrayed;
    if (onPrayed != null) return () async => onPrayed();
    final source = widget.tablet.source;
    final timezoneName = ref.read(prayerDeviceTimezoneProvider);
    // Resolve the repository while this provider scope is alive. Handling the
    // Future here keeps listening independent of a failed practice database;
    // the error is surfaced only if the person chooses to mark prayer done.
    final repository = ref
        .read(prayerPracticeRepositoryProvider.future)
        .then<AsyncValue<PrayerPracticeRepository>>(
          (value) => AsyncData(value),
          onError: (Object error, StackTrace stackTrace) =>
              AsyncError<PrayerPracticeRepository>(error, stackTrace),
        );
    return () async {
      final practice = (await repository).requireValue;
      final session = await practice.recordSession(
        prayer: source.type == VoiceTabletSourceType.personalPrayer
            ? PrayerReference.personal(source.prayerId)
            : PrayerReference.library(source.prayerId),
        revisionId: source.revisionId,
        timezone: await timezoneName(),
      );
      if (mounted) setState(() => _lastSession = session);
    };
  }

  Future<void> _undoPrayer() async {
    final session = _lastSession;
    if (_savingPrayer || session == null) return;
    setState(() => _savingPrayer = true);
    try {
      final repository = await ref.read(
        prayerPracticeRepositoryProvider.future,
      );
      await repository.retractSession(session.id);
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _lastSession = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _actionError = 'Could not undo this prayer record just now.';
        });
      }
    }
  }

  Future<void> _handleMenu(_TabletAction action) async {
    if (action == _TabletAction.keepOnAltar) {
      if (widget.onKeepOnAltar != null) {
        await widget.onKeepOnAltar!(widget.tablet);
      }
      return;
    }
    if (action == _TabletAction.recordAgain) {
      widget.onRecordAgain?.call();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this Voice Tablet?'),
        content: const Text(
          'Its private recordings will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final audioIds = {
        if (widget.tablet.fullAudio case final audio?) audio.id,
        if (widget.tablet.refrainAudio case final audio?) audio.id,
      };
      final spiritual = ref.read(spiritualSessionControllerProvider);
      if (audioIds.any((id) => spiritual.state.session?.id == 'prayer:$id')) {
        await spiritual.close();
      }
      final repository = await ref.read(voiceTabletRepositoryProvider.future);
      final store = await ref.read(audioAssetStoreProvider.future);
      final keys = await repository.archive(widget.tablet.id);
      for (final key in keys) {
        await store.delete(key);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _removing = false;
          _actionError = 'The Voice Tablet could not be removed just now.';
        });
      }
    }
  }
}

class _PlaybackControls extends ConsumerStatefulWidget {
  const _PlaybackControls({
    required this.coordinator,
    required this.audio,
    required this.onPlayed,
    required this.spiritualSession,
    required this.title,
    required this.route,
    required this.prepareSessionComplete,
    required this.compact,
  });

  final MemoryAudioPlaybackCoordinator coordinator;
  final VoiceTabletAudio audio;
  final FutureOr<void> Function(VoiceTabletAudio)? onPlayed;
  final SpiritualSessionController spiritualSession;
  final String title;
  final String route;
  final Future<void> Function() Function() prepareSessionComplete;
  final bool compact;

  @override
  ConsumerState<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends ConsumerState<_PlaybackControls>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.coordinator.addListener(_changed);
    widget.spiritualSession.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _PlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeListener(_changed);
      widget.coordinator.addListener(_changed);
    }
    if (oldWidget.spiritualSession != widget.spiritualSession) {
      oldWidget.spiritualSession.removeListener(_changed);
      widget.spiritualSession.addListener(_changed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.coordinator.removeListener(_changed);
    widget.spiritualSession.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (widget.spiritualSession.state.session?.id ==
        'prayer:${widget.audio.id}') {
      unawaited(widget.spiritualSession.pause().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.coordinator.state;
    final settings =
        ref.watch(memorySoundscapeSettingsProvider(widget.audio.id)).value ??
        MemorySoundscapeSettings.defaults;
    final blocked = widget.spiritualSession.isCapturing;
    final selected = state.assetId == widget.audio.id;
    final playing =
        selected && state.status == MemoryAudioPlaybackStatus.playing;
    final position = selected ? state.position : Duration.zero;
    if (widget.compact) {
      return Row(
        children: [
          IconButton.filledTonal(
            tooltip: playing ? 'Pause' : 'Listen',
            onPressed: blocked ? null : () => _toggle(playing, settings),
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          Expanded(
            child: Slider(
              value: position.inMilliseconds
                  .clamp(0, widget.audio.duration.inMilliseconds)
                  .toDouble(),
              max: widget.audio.duration.inMilliseconds.toDouble(),
              onChanged: selected
                  ? (value) => widget.coordinator.seek(
                      Duration(milliseconds: value.round()),
                    )
                  : null,
            ),
          ),
          Text(
            '${_clock(position)} / ${_clock(widget.audio.duration)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          IconButton(
            tooltip: 'Background sound',
            onPressed: blocked ? null : _showBackgroundControls,
            icon: const Icon(Icons.graphic_eq),
          ),
        ],
      );
    }
    return Column(
      children: [
        Semantics(
          label: '${_spoken(position)} of ${_spoken(widget.audio.duration)}',
          child: Slider(
            value: position.inMilliseconds
                .clamp(0, widget.audio.duration.inMilliseconds)
                .toDouble(),
            max: widget.audio.duration.inMilliseconds.toDouble(),
            onChanged: selected
                ? (value) => widget.coordinator.seek(
                    Duration(milliseconds: value.round()),
                  )
                : null,
          ),
        ),
        Text(
          '${_clock(position)} / ${_clock(widget.audio.duration)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
          ),
          onPressed: blocked ? null : () => _toggle(playing, settings),
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          label: Text(playing ? 'Pause' : 'Listen'),
        ),
        const SizedBox(height: AppSpacing.sm),
        SoundscapeControls(
          settings: settings,
          enabled: !blocked,
          onSelected: (soundscape) =>
              _changeBackground(settings.copyWith(soundscape: soundscape)),
          onVolumeChanged: (volume) => _changeBackground(
            settings.copyWith(volume: volume),
            volumeOnly: true,
          ),
        ),
        if (selected && state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(bool playing, MemorySoundscapeSettings settings) async {
    final audio = widget.audio;
    final coordinator = widget.coordinator;
    final spiritual = widget.spiritualSession;
    if (spiritual.isCapturing) return;
    final sessionId = 'prayer:${audio.id}';
    final activeSession = spiritual.state.session?.id == sessionId;
    if (playing) {
      if (activeSession) {
        await spiritual.pause();
      } else {
        await coordinator.pause();
        await ref.read(memorySoundscapePlaybackProvider).stop(audio.id);
      }
      return;
    }
    final onPlayed = widget.onPlayed;
    if (activeSession &&
        spiritual.state.status == SpiritualSessionStatus.paused) {
      await spiritual.resume();
      if (coordinator.state.assetId == audio.id &&
          coordinator.state.status == MemoryAudioPlaybackStatus.playing) {
        await onPlayed?.call(audio);
      }
      return;
    }
    final background = ref.read(memorySoundscapePlaybackProvider);
    final preferences = ref.read(memorySoundscapePreferencesProvider);
    final recordPrayer = widget.prepareSessionComplete();
    final messenger = ScaffoldMessenger.of(context);
    var starting = true;
    late VoidCallback sessionListener;
    sessionListener = () {
      final playback = coordinator.state;
      if (spiritual.state.session?.id != sessionId) {
        coordinator.removeListener(sessionListener);
        return;
      }
      if (playback.assetId != audio.id) {
        if (!starting) {
          coordinator.removeListener(sessionListener);
          unawaited(background.stop(audio.id));
          spiritual.finishPlayback(sessionId);
        }
        return;
      }
      spiritual.updateProgress(
        sessionId: sessionId,
        position: playback.position,
        duration: playback.duration,
        status: playback.status == MemoryAudioPlaybackStatus.paused
            ? SpiritualSessionStatus.paused
            : playback.status == MemoryAudioPlaybackStatus.playing
            ? SpiritualSessionStatus.playing
            : null,
      );
      if (!starting &&
          (playback.status == MemoryAudioPlaybackStatus.completed ||
              playback.status == MemoryAudioPlaybackStatus.idle ||
              playback.status == MemoryAudioPlaybackStatus.error)) {
        coordinator.removeListener(sessionListener);
        unawaited(background.stop(audio.id));
        spiritual.finishPlayback(sessionId);
      } else if (playback.status == MemoryAudioPlaybackStatus.paused) {
        unawaited(background.stop(audio.id));
      }
    };

    Future<void> startPlayback(MemorySoundscapeSettings selected) async {
      starting = true;
      try {
        await coordinator.playTrack(_track(audio));
        if (coordinator.state.assetId != audio.id ||
            coordinator.state.status != MemoryAudioPlaybackStatus.playing ||
            spiritual.state.session?.id != sessionId) {
          return;
        }
        try {
          await background.start(audio.id, selected);
        } on Object {
          if (messenger.mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Background sound unavailable.')),
            );
          }
        }
        if (coordinator.state.assetId != audio.id ||
            coordinator.state.status != MemoryAudioPlaybackStatus.playing) {
          await background.stop(audio.id);
        }
      } finally {
        starting = false;
        sessionListener();
      }
    }

    Future<void> stopPlayback() async {
      coordinator.removeListener(sessionListener);
      await background.stop(audio.id);
      if (coordinator.state.assetId == audio.id) await coordinator.stop();
    }

    await spiritual.begin(
      SpiritualSession(
        id: sessionId,
        kind: SpiritualSessionKind.prayer,
        title: widget.title,
        route: widget.route,
        canPause: true,
        completionLabel: 'I prayed',
        onStart: () async {
          coordinator.addListener(sessionListener);
          await startPlayback(settings);
        },
        onPause: () async {
          await background.stop(audio.id);
          if (coordinator.state.assetId == audio.id) await coordinator.pause();
        },
        onResume: () async {
          await startPlayback(await preferences.load(audio.id));
        },
        onComplete: () async {
          await stopPlayback();
          await recordPrayer();
        },
        onClose: stopPlayback,
      ),
    );
    if (coordinator.state.assetId == audio.id &&
        coordinator.state.status == MemoryAudioPlaybackStatus.playing) {
      await onPlayed?.call(audio);
    }
  }

  Future<void> _showBackgroundControls() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final settings =
            ref
                .watch(memorySoundscapeSettingsProvider(widget.audio.id))
                .value ??
            MemorySoundscapeSettings.defaults;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SoundscapeControls(
              settings: settings,
              onSelected: (soundscape) =>
                  _changeBackground(settings.copyWith(soundscape: soundscape)),
              onVolumeChanged: (volume) => _changeBackground(
                settings.copyWith(volume: volume),
                volumeOnly: true,
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _changeBackground(
    MemorySoundscapeSettings settings, {
    bool volumeOnly = false,
  }) async {
    final assetId = widget.audio.id;
    final coordinator = widget.coordinator;
    final spiritual = widget.spiritualSession;
    final background = ref.read(memorySoundscapePlaybackProvider);
    await ref.read(memorySoundscapePreferencesProvider).save(assetId, settings);
    if (mounted) ref.invalidate(memorySoundscapeSettingsProvider(assetId));
    if (spiritual.isCapturing ||
        coordinator.state.assetId != assetId ||
        coordinator.state.status != MemoryAudioPlaybackStatus.playing ||
        settings.soundscape == MemorySoundscape.quiet) {
      await background.stop(assetId);
    } else if (volumeOnly) {
      await background.setVolume(assetId, settings.volume);
    } else {
      await background.start(assetId, settings);
      if (spiritual.isCapturing ||
          coordinator.state.assetId != assetId ||
          coordinator.state.status != MemoryAudioPlaybackStatus.playing) {
        await background.stop(assetId);
      }
    }
  }
}

String _tabletRoute(VoiceTabletSource source) =>
    source.type == VoiceTabletSourceType.personalPrayer
    ? '/prayers/saved/${source.prayerId}'
    : '/prayers/${source.prayerId}';

class _Waveform extends StatelessWidget {
  const _Waveform({required this.samples});

  final List<double> samples;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final sample in samples.take(48))
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 6 + sample * 36,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.72),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _VoiceTabletClipper extends CustomClipper<Path> {
  const _VoiceTabletClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(6, 4)
    ..lineTo(size.width * 0.28, 0)
    ..lineTo(size.width * 0.66, 3)
    ..lineTo(size.width - 5, 1)
    ..lineTo(size.width, size.height * 0.38)
    ..lineTo(size.width - 2, size.height - 7)
    ..lineTo(size.width * 0.72, size.height)
    ..lineTo(size.width * 0.31, size.height - 3)
    ..lineTo(3, size.height)
    ..lineTo(0, size.height * 0.43)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

PrivateAudioTrack _track(VoiceTabletAudio audio) => PrivateAudioTrack(
  id: audio.id,
  storageKey: audio.storageKey,
  duration: audio.duration,
);

String _clock(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spoken(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';

enum _TabletAction { recordAgain, keepOnAltar, remove }
