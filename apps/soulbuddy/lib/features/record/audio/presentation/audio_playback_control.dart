import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/playback/spiritual_session.dart';
import '../../../../core/playback/spiritual_session_providers.dart';
import '../../../../core/design/app_spacing.dart';
import '../application/memory_audio_player.dart';
import '../application/memory_soundscape_player.dart';
import '../domain/memory_audio.dart';
import '../domain/memory_soundscape.dart';
import '../providers/memory_audio_providers.dart';
import 'soundscape_controls.dart';

class AudioPlaybackControl extends ConsumerStatefulWidget {
  const AudioPlaybackControl({
    required this.audio,
    this.compact = false,
    this.label = 'Voice recording',
    this.playLabel = 'Play',
    this.allowDelete = false,
    this.stopOnDispose = false,
    this.sessionKind = SpiritualSessionKind.memory,
    this.sessionRoute,
    this.onSessionComplete,
    super.key,
  });

  final MemoryAudio audio;
  final bool compact;
  final String label;
  final String playLabel;
  final bool allowDelete;
  final bool stopOnDispose;
  final SpiritualSessionKind sessionKind;
  final String? sessionRoute;
  final Future<void> Function()? onSessionComplete;

  @override
  ConsumerState<AudioPlaybackControl> createState() =>
      _AudioPlaybackControlState();
}

class _AudioPlaybackControlState extends ConsumerState<AudioPlaybackControl>
    with WidgetsBindingObserver {
  MemoryAudioPlaybackCoordinator? _coordinator;
  MemoryAudioPlaybackCoordinator? _preparedCoordinator;
  String? _preparedAudioId;
  Future<bool>? _preparation;
  bool _deleting = false;
  MemorySoundscapePlaybackCoordinator? _soundscapePlayback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_pauseForInterruption());
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlaybackControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio.id != widget.audio.id) {
      unawaited(_soundscapePlayback?.stop(oldWidget.audio.id));
      _preparedCoordinator = null;
      _preparedAudioId = null;
      _preparation = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final coordinator = _coordinator;
    if (widget.stopOnDispose && coordinator?.state.assetId == widget.audio.id) {
      unawaited(coordinator!.stop());
      unawaited(_soundscapePlayback?.stop(widget.audio.id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinatorAsync = ref.watch(memoryAudioPlaybackCoordinatorProvider);
    return coordinatorAsync.when(
      loading: () => _loadingControl(),
      error: (_, _) =>
          Text('${widget.label} · ${_durationLabel(widget.audio.duration)}'),
      data: (coordinator) {
        _coordinator = coordinator;
        _soundscapePlayback = ref.watch(memorySoundscapePlaybackProvider);
        final soundscape =
            ref
                .watch(memorySoundscapeSettingsProvider(widget.audio.id))
                .value ??
            MemorySoundscapeSettings.defaults;
        final preparation = _prepare(coordinator);
        return FutureBuilder<bool>(
          future: preparation,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _loadingControl();
            }
            if (snapshot.data != true) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '${widget.label} · This audio is not available on this device.',
                    ),
                  ),
                  TextButton(
                    onPressed: _retryPreparation,
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            return AnimatedBuilder(
              animation: coordinator,
              builder: (context, _) => widget.compact
                  ? _compactControl(coordinator, soundscape)
                  : _fullControl(coordinator, soundscape),
            );
          },
        );
      },
    );
  }

  Future<bool> _prepare(MemoryAudioPlaybackCoordinator coordinator) {
    if (_preparedCoordinator != coordinator ||
        _preparedAudioId != widget.audio.id) {
      _preparedCoordinator = coordinator;
      _preparedAudioId = widget.audio.id;
      _preparation = coordinator.prepare(widget.audio);
    }
    return _preparation!;
  }

  Widget _loadingControl() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          '${widget.label} · ${_durationLabel(widget.audio.duration)}',
        ),
      ),
    ],
  );

  Widget _compactControl(
    MemoryAudioPlaybackCoordinator coordinator,
    MemorySoundscapeSettings soundscape,
  ) {
    final state = coordinator.state;
    final active = state.assetId == widget.audio.id;
    final playing = active && state.status == MemoryAudioPlaybackStatus.playing;
    final busy = active && state.status == MemoryAudioPlaybackStatus.loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label),
                  Text(
                    _durationLabel(widget.audio.duration),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => _togglePlayback(
                        coordinator,
                        soundscape,
                        playing: playing,
                      ),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
                label: Text(playing ? 'Pause' : widget.playLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullControl(
    MemoryAudioPlaybackCoordinator coordinator,
    MemorySoundscapeSettings soundscape,
  ) {
    final state = coordinator.state;
    final active = state.assetId == widget.audio.id;
    final status = active ? state.status : MemoryAudioPlaybackStatus.idle;
    final position = active ? state.position : Duration.zero;
    final duration = active && state.duration > Duration.zero
        ? state.duration
        : widget.audio.duration;
    final playing = status == MemoryAudioPlaybackStatus.playing;
    final busy = status == MemoryAudioPlaybackStatus.loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text('Audio saved on this device'),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label:
                  '${_spokenDuration(position)} of ${_spokenDuration(duration)}',
              child: Slider(
                value: position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble(),
                max: duration.inMilliseconds.toDouble(),
                onChanged: active && !busy
                    ? (value) => coordinator.seek(
                        Duration(milliseconds: value.round()),
                      )
                    : null,
              ),
            ),
            Text(
              '${_durationLabel(position)} / ${_durationLabel(duration)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            _soundscapeControls(soundscape, playing: playing),
            if (active && state.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(state.error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _togglePlayback(
                            coordinator,
                            soundscape,
                            playing: playing,
                          ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                    label: Text(playing ? 'Pause' : widget.playLabel),
                  ),
                ),
                if (active && status != MemoryAudioPlaybackStatus.idle)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              await coordinator.stop();
                              await _soundscapePlayback?.stop(widget.audio.id);
                            },
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                if (widget.allowDelete)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton.icon(
                      onPressed: _deleting ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(_deleting ? 'Deleting…' : 'Delete audio'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _soundscapeControls(
    MemorySoundscapeSettings settings, {
    required bool playing,
  }) {
    return SoundscapeControls(
      settings: settings,
      enabled: !_deleting,
      onSelected: (soundscape) => _selectSoundscape(
        settings.copyWith(soundscape: soundscape),
        playing: playing,
      ),
      onVolumeChanged: (volume) => _changeSoundscapeVolume(
        settings.copyWith(volume: volume),
        playing: playing,
      ),
    );
  }

  Future<void> _pauseForInterruption() async {
    final coordinator = _coordinator;
    final sessionController = ref.read(spiritualSessionControllerProvider);
    if (sessionController.state.session?.id == _sessionId) {
      await sessionController.pause();
      return;
    }
    await _soundscapePlayback?.stop(widget.audio.id);
    if (coordinator?.state.assetId == widget.audio.id &&
        coordinator?.state.status == MemoryAudioPlaybackStatus.playing) {
      await coordinator?.pause();
    }
  }

  void _retryPreparation() {
    setState(() {
      _preparedCoordinator = null;
      _preparedAudioId = null;
      _preparation = null;
    });
  }

  Future<void> _togglePlayback(
    MemoryAudioPlaybackCoordinator coordinator,
    MemorySoundscapeSettings settings, {
    required bool playing,
  }) async {
    final sessionController = ref.read(spiritualSessionControllerProvider);
    if (playing) {
      if (sessionController.state.session?.id == _sessionId) {
        await sessionController.pause();
      } else {
        await coordinator.pause();
        await _soundscapePlayback?.stop(widget.audio.id);
      }
      return;
    }
    if (sessionController.state.session?.id == _sessionId &&
        sessionController.state.status == SpiritualSessionStatus.paused) {
      await sessionController.resume();
      return;
    }
    final audio = widget.audio;
    final sessionId = _sessionId;
    final soundscapePlayback = _soundscapePlayback;
    final preferences = ref.read(memorySoundscapePreferencesProvider);
    final onComplete = widget.onSessionComplete;
    final messenger = ScaffoldMessenger.of(context);
    var starting = true;
    late VoidCallback sessionListener;
    sessionListener = () {
      final state = coordinator.state;
      if (sessionController.state.session?.id != sessionId) {
        coordinator.removeListener(sessionListener);
        return;
      }
      if (state.assetId != audio.id) {
        if (!starting) {
          coordinator.removeListener(sessionListener);
          unawaited(soundscapePlayback?.stop(audio.id));
          sessionController.finishPlayback(sessionId);
        }
        return;
      }
      sessionController.updateProgress(
        sessionId: sessionId,
        position: state.position,
        duration: state.duration,
        status: state.status == MemoryAudioPlaybackStatus.paused
            ? SpiritualSessionStatus.paused
            : state.status == MemoryAudioPlaybackStatus.playing
            ? SpiritualSessionStatus.playing
            : null,
      );
      if (!starting &&
          (state.status == MemoryAudioPlaybackStatus.completed ||
              state.status == MemoryAudioPlaybackStatus.idle ||
              state.status == MemoryAudioPlaybackStatus.error)) {
        coordinator.removeListener(sessionListener);
        unawaited(soundscapePlayback?.stop(audio.id));
        sessionController.finishPlayback(sessionId);
      } else if (state.status == MemoryAudioPlaybackStatus.paused) {
        unawaited(soundscapePlayback?.stop(audio.id));
      }
    };

    Future<void> startPlayback(MemorySoundscapeSettings selected) async {
      starting = true;
      try {
        await coordinator.play(audio);
        if (coordinator.state.assetId != audio.id ||
            coordinator.state.status != MemoryAudioPlaybackStatus.playing ||
            sessionController.state.session?.id != sessionId) {
          return;
        }
        try {
          await soundscapePlayback?.start(audio.id, selected);
        } on Object {
          if (messenger.mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Background sound unavailable.')),
            );
          }
        }
        if (coordinator.state.assetId != audio.id ||
            coordinator.state.status != MemoryAudioPlaybackStatus.playing) {
          await soundscapePlayback?.stop(audio.id);
        }
      } finally {
        starting = false;
        sessionListener();
      }
    }

    Future<void> stopPlayback() async {
      coordinator.removeListener(sessionListener);
      await soundscapePlayback?.stop(audio.id);
      if (coordinator.state.assetId == audio.id) await coordinator.stop();
    }

    await sessionController.begin(
      SpiritualSession(
        id: sessionId,
        kind: widget.sessionKind,
        title: widget.label,
        route: widget.sessionRoute ?? '/remember/${audio.encounterId}',
        canPause: true,
        completionLabel: onComplete == null ? 'Close' : 'Complete',
        onStart: () async {
          coordinator.addListener(sessionListener);
          await startPlayback(settings);
        },
        onPause: () async {
          await soundscapePlayback?.stop(audio.id);
          if (coordinator.state.assetId == audio.id) await coordinator.pause();
        },
        onResume: () async {
          await startPlayback(await preferences.load(audio.id));
        },
        onComplete: () async {
          await stopPlayback();
          await onComplete?.call();
        },
        onClose: stopPlayback,
      ),
    );
  }

  String get _sessionId => '${widget.sessionKind.name}:${widget.audio.id}';

  Future<void> _selectSoundscape(
    MemorySoundscapeSettings settings, {
    required bool playing,
  }) async {
    final assetId = widget.audio.id;
    final playback = _soundscapePlayback;
    final coordinator = _coordinator;
    await ref.read(memorySoundscapePreferencesProvider).save(assetId, settings);
    if (mounted) ref.invalidate(memorySoundscapeSettingsProvider(assetId));
    if (!playing ||
        coordinator?.state.assetId != assetId ||
        coordinator?.state.status != MemoryAudioPlaybackStatus.playing ||
        settings.soundscape == MemorySoundscape.quiet) {
      await playback?.stop(assetId);
      return;
    }
    await playback?.start(assetId, settings);
    if (coordinator?.state.assetId != assetId ||
        coordinator?.state.status != MemoryAudioPlaybackStatus.playing) {
      await playback?.stop(assetId);
    }
  }

  Future<void> _changeSoundscapeVolume(
    MemorySoundscapeSettings settings, {
    required bool playing,
  }) async {
    final assetId = widget.audio.id;
    final playback = _soundscapePlayback;
    await ref.read(memorySoundscapePreferencesProvider).save(assetId, settings);
    if (mounted) ref.invalidate(memorySoundscapeSettingsProvider(assetId));
    if (playing) {
      await playback?.setVolume(assetId, settings.volume);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this audio?'),
        content: const Text(
          'This audio cannot be recovered from SoulBuddy. The written memory will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep audio'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove audio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final coordinator = _coordinator;
      if (coordinator?.state.assetId == widget.audio.id) {
        await coordinator!.stop();
      }
      final deletion = await ref.read(memoryAudioDeletionProvider.future);
      await deletion.deleteForEncounter(widget.audio.encounterId);
      ref.invalidate(memoryAudioForEncounterProvider(widget.audio.encounterId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The audio could not be removed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

String _durationLabel(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spokenDuration(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';
