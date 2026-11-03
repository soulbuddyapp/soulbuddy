import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../application/audio_capture_controller.dart';
import '../application/audioplayers_memory_audio_player.dart';
import '../application/memory_soundscape_player.dart';
import '../domain/memory_audio.dart';
import '../domain/memory_soundscape.dart';

class AudioCapturePanel extends StatefulWidget {
  const AudioCapturePanel({
    required this.controller,
    required this.onContinue,
    this.onWriteInstead,
    this.onBack,
    this.handlesSystemBack = false,
    this.introHeading,
    this.introDescription,
    this.startLabel = 'Start recording',
    this.continueLabel = 'Use recording',
    this.alternativeLabel = 'Write instead',
    this.introContent,
    this.enableSoundscape = false,
    this.reviewPlayer,
    this.reviewSoundscapePlayer,
    super.key,
  }) : assert(!handlesSystemBack || onBack != null);

  final AudioCaptureController controller;
  final VoidCallback? onWriteInstead;
  final ValueChanged<RecordedAudioDraft> onContinue;
  final VoidCallback? onBack;
  final bool handlesSystemBack;
  final String? introHeading;
  final String? introDescription;
  final String startLabel;
  final String continueLabel;
  final String alternativeLabel;
  final Widget? introContent;
  final bool enableSoundscape;
  final AudioPlayer? reviewPlayer;
  final MemorySoundscapePlayer? reviewSoundscapePlayer;

  @override
  State<AudioCapturePanel> createState() => _AudioCapturePanelState();
}

class _AudioCapturePanelState extends State<AudioCapturePanel>
    with WidgetsBindingObserver {
  late final AudioPlayer _reviewPlayer;
  MemorySoundscapePlayer? _reviewSoundscapePlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  var _playerState = PlayerState.stopped;
  var _position = Duration.zero;
  String? _playbackError;
  var _reviewSoundscape = MemorySoundscape.quiet;
  var _reviewSoundVolume = 0.15;
  var _reviewCommandInFlight = false;

  @override
  void initState() {
    super.initState();
    _reviewPlayer = widget.reviewPlayer ?? AudioPlayer();
    _reviewSoundscapePlayer = widget.reviewSoundscapePlayer;
    WidgetsBinding.instance.addObserver(this);
    _playerStateSubscription = _reviewPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _playerState = state);
      if (state == PlayerState.completed ||
          state == PlayerState.stopped ||
          state == PlayerState.paused) {
        unawaited(_stopSoundscapeAfterPlayback());
      }
    });
    _positionSubscription = _reviewPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.controller.handleInterruption());
      unawaited(_pauseReviewAfterInterruption());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_reviewSoundscapePlayer?.dispose() ?? Future.value());
    unawaited(_reviewPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack case final onBack?)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              state.commandInFlight || _reviewCommandInFlight
                              ? null
                              : () => _handleBack(onBack),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        _heading(state, introHeading: widget.introHeading),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_description(
                      state,
                      introDescription: widget.introDescription,
                    ) case final description?)
                      Text(description),
                    if (widget.introContent case final content?) ...[
                      const SizedBox(height: AppSpacing.md),
                      content,
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (state.notice case final notice?) ...[
                      _QuietNotice(text: notice),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_playbackError case final error?) ...[
                      _QuietNotice(text: error),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    ..._controls(state),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!widget.handlesSystemBack) return content;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack(widget.onBack!));
      },
      child: content,
    );
  }

  List<Widget> _controls(AudioCaptureState state) => switch (state.phase) {
    AudioCapturePhase.idle || AudioCapturePhase.explaining => [
      _PrimaryControl(
        semanticLabel: 'Start audio recording',
        label: widget.startLabel,
        icon: Icons.mic_none,
        onPressed: _reviewCommandInFlight ? null : widget.controller.start,
      ),
      if (widget.onWriteInstead case final writeInstead?) ...[
        const SizedBox(height: AppSpacing.sm),
        _SecondaryControl(
          label: widget.alternativeLabel,
          icon: Icons.edit_outlined,
          onPressed: writeInstead,
        ),
      ],
    ],
    AudioCapturePhase.requestingPermission => const [
      Center(child: CircularProgressIndicator()),
      SizedBox(height: AppSpacing.sm),
      Center(child: Text('Preparing the microphone…')),
    ],
    AudioCapturePhase.recording || AudioCapturePhase.paused => [
      Center(
        child: Text(
          _durationLabel(state.elapsed),
          style: Theme.of(context).textTheme.headlineSmall,
          semanticsLabel: 'Recorded ${_spokenDuration(state.elapsed)}',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      ExcludeSemantics(
        child: _AudioLevel(
          key: const Key('audio-live-level'),
          samples: state.liveWaveform,
          paused: state.phase == AudioCapturePhase.paused,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _PrimaryControl(
        semanticLabel: state.phase == AudioCapturePhase.paused
            ? 'Resume recording'
            : 'Pause recording',
        label: state.phase == AudioCapturePhase.paused ? 'Resume' : 'Pause',
        icon: state.phase == AudioCapturePhase.paused
            ? Icons.mic_none
            : Icons.pause,
        onPressed: _reviewCommandInFlight
            ? null
            : state.phase == AudioCapturePhase.paused
            ? widget.controller.resume
            : widget.controller.pause,
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Stop and review recording',
        label: 'Stop',
        icon: Icons.stop_rounded,
        onPressed: _reviewCommandInFlight ? null : widget.controller.stop,
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Discard this recording',
        label: 'Discard',
        icon: Icons.delete_outline,
        onPressed: _reviewCommandInFlight ? null : _confirmDiscard,
      ),
    ],
    AudioCapturePhase.stopping || AudioCapturePhase.cancelling => const [
      Center(child: CircularProgressIndicator()),
      SizedBox(height: AppSpacing.sm),
      Center(child: Text('Preparing recording…')),
    ],
    AudioCapturePhase.review => _reviewControls(state),
    AudioCapturePhase.failure => [
      _QuietNotice(text: _failureText(state.failure)),
      const SizedBox(height: AppSpacing.md),
      if (!widget.controller.hasPendingRecording) ...[
        _PrimaryControl(
          label: 'Try microphone again',
          icon: Icons.mic_none,
          onPressed: widget.controller.start,
        ),
        if (widget.onWriteInstead case final writeInstead?) ...[
          const SizedBox(height: AppSpacing.sm),
          _SecondaryControl(
            label: widget.alternativeLabel,
            icon: Icons.edit_outlined,
            onPressed: writeInstead,
          ),
        ],
      ] else ...[
        _PrimaryControl(
          label: 'Discard recording',
          semanticLabel: 'Discard this recording',
          icon: Icons.delete_outline,
          onPressed: widget.controller.cancel,
        ),
      ],
    ],
  };

  List<Widget> _reviewControls(AudioCaptureState state) {
    final review = state.review!;
    final playing = _playerState == PlayerState.playing;
    return [
      ExcludeSemantics(
        child: _AudioLevel(samples: review.waveform, paused: true),
      ),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        label:
            '${_spokenDuration(_position)} of ${_spokenDuration(review.duration)}',
        child: Slider(
          value: _position.inMilliseconds
              .clamp(0, review.duration.inMilliseconds)
              .toDouble(),
          max: review.duration.inMilliseconds.toDouble(),
          onChanged: _reviewCommandInFlight
              ? null
              : (value) =>
                    _reviewPlayer.seek(Duration(milliseconds: value.round())),
        ),
      ),
      Center(
        child: Text(
          '${_durationLabel(_position)} / ${_durationLabel(review.duration)}',
        ),
      ),
      if (widget.enableSoundscape) ...[
        const SizedBox(height: AppSpacing.md),
        _reviewSoundscapeControls(playing: playing),
      ],
      const SizedBox(height: AppSpacing.md),
      _PrimaryControl(
        label: playing ? 'Pause playback' : 'Play',
        semanticLabel: playing ? 'Pause recording playback' : 'Play recording',
        icon: playing ? Icons.pause : Icons.play_arrow,
        onPressed: _reviewCommandInFlight ? null : _togglePlayback,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PrimaryControl(
        label: _reviewCommandInFlight ? 'Preparing…' : widget.continueLabel,
        icon: Icons.arrow_forward,
        onPressed: _reviewCommandInFlight ? null : () => _reviewCommand(() async {
          await _stopReview();
          if (!mounted) return;
          final transferred = widget.controller.takeReview();
          if (transferred != null) {
            widget.onContinue(
              RecordedAudioDraft(
                temporaryKey: transferred.temporaryKey,
                mimeType: transferred.mimeType,
                duration: transferred.duration,
                waveform: transferred.waveform,
                soundscape: _reviewSoundscape,
                soundscapeVolume: _reviewSoundVolume,
              ),
            );
          }
        }, error: 'Playback could not stop. Try again.'),
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        label: 'Record again',
        icon: Icons.replay,
        onPressed: _reviewCommandInFlight ? null : () => _reviewCommand(() async {
          await _stopReview();
          if (!mounted) return;
          await widget.controller.recordAgain();
        }, error: 'Playback could not stop. Try again.'),
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Discard this recording',
        label: 'Discard',
        icon: Icons.delete_outline,
        onPressed: _reviewCommandInFlight
            ? null
            : _confirmDiscard,
      ),
    ];
  }

  Future<void> _togglePlayback() => _reviewCommand(() async {
    final review = widget.controller.state.review;
    if (review == null) return;
      if (_playerState == PlayerState.playing) {
        await _reviewPlayer.pause();
        await _reviewSoundscapePlayer?.stop();
      } else if (_playerState == PlayerState.paused) {
        await _reviewPlayer.resume();
        await _startReviewSoundscape();
      } else {
        await prepareVoicePlaybackPlayer(_reviewPlayer);
        await _reviewPlayer.play(
          kIsWeb
              ? UrlSource(review.temporaryKey)
              : DeviceFileSource(review.temporaryKey),
        );
        await _startReviewSoundscape();
      }
  }, error: 'Playback unavailable. Your recording is still here.');

  Future<void> _stopReview() async {
    await Future.wait([
      _reviewPlayer.stop(),
      _reviewSoundscapePlayer?.stop() ?? Future<void>.value(),
    ]);
  }

  Future<void> _stopSoundscapeAfterPlayback() async {
    try {
      await _reviewSoundscapePlayer?.stop();
    } catch (_) {
      if (mounted) {
        setState(() => _playbackError = 'Playback could not stop. Try again.');
      }
    }
  }

  Future<void> _pauseReviewAfterInterruption() async {
    try {
      await Future.wait([
        _reviewPlayer.pause(),
        _reviewSoundscapePlayer?.stop() ?? Future<void>.value(),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() => _playbackError = 'Playback could not stop. Try again.');
      }
    }
  }

  Future<void> _handleBack(VoidCallback onBack) => _reviewCommand(() async {
    if (widget.controller.state.phase == AudioCapturePhase.recording) {
      await widget.controller.handleInterruption();
    }
    if (!mounted) return;
    if (widget.controller.state.phase == AudioCapturePhase.failure &&
        widget.controller.state.review == null &&
        widget.controller.hasPendingRecording) {
      return;
    }
    if (widget.controller.state.review != null) {
      await _stopReview();
    }
    if (mounted) onBack();
  }, error: 'Playback could not stop. Try again.');

  Future<void> _reviewCommand(
    Future<void> Function() command, {
    required String error,
  }) async {
    if (_reviewCommandInFlight || !mounted) return;
    setState(() {
      _reviewCommandInFlight = true;
      _playbackError = null;
    });
    try {
      await command();
    } catch (_) {
      if (mounted) setState(() => _playbackError = error);
    } finally {
      if (mounted) setState(() => _reviewCommandInFlight = false);
    }
  }

  Widget _reviewSoundscapeControls({required bool playing}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background sound',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final soundscape in MemorySoundscape.values)
                  ChoiceChip(
                    key: Key('recording-soundscape-${soundscape.name}'),
                    label: Text(soundscape.label),
                    selected: _reviewSoundscape == soundscape,
                    onSelected: _reviewCommandInFlight ? null : (_) async {
                      setState(() => _reviewSoundscape = soundscape);
                      if (!playing || soundscape == MemorySoundscape.quiet) {
                        await _reviewSoundscapePlayer?.stop();
                      } else {
                        await _startReviewSoundscape();
                      }
                    },
                  ),
              ],
            ),
            if (_reviewSoundscape != MemorySoundscape.quiet)
              Semantics(
                label:
                    'Background volume ${(_reviewSoundVolume * 100).round()} percent',
                child: Slider(
                  key: const Key('recording-soundscape-volume'),
                  value: _reviewSoundVolume,
                  min: 0.05,
                  max: 0.35,
                  divisions: 6,
                  label: '${(_reviewSoundVolume * 100).round()}%',
                  onChanged: _reviewCommandInFlight ? null : (value) {
                    setState(() => _reviewSoundVolume = value);
                    if (playing) {
                      unawaited(
                        _reviewSoundscapePlayer?.setVolume(value) ??
                            Future.value(),
                      );
                    }
                  },
                ),
              ),
            const Text('Your original voice recording stays unchanged.'),
          ],
        ),
      ),
    );
  }

  Future<void> _startReviewSoundscape() {
    final player = _reviewSoundscapePlayer ??=
        AudioplayersMemorySoundscapePlayer();
    return player.start(_reviewSoundscape, volume: _reviewSoundVolume);
  }

  Future<void> _confirmDiscard() => _reviewCommand(() async {
    if (widget.controller.state.phase == AudioCapturePhase.recording) {
      await widget.controller.handleInterruption();
    }
    if (!mounted || widget.controller.state.phase == AudioCapturePhase.failure) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this recording?'),
        content: const Text(
          'This take has not been saved and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (widget.controller.state.review != null) await _stopReview();
    if (!mounted) return;
    await widget.controller.cancel();
  }, error: 'Playback could not stop. Try again.');
}

class _PrimaryControl extends StatelessWidget {
  const _PrimaryControl({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final FutureOr<void> Function()? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: semanticLabel != null,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FilledButton.icon(
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: Icon(icon),
        label: Text(label),
      ),
    ),
  );
}

class _SecondaryControl extends StatelessWidget {
  const _SecondaryControl({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final FutureOr<void> Function()? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: semanticLabel != null,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton.icon(
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: Icon(icon),
        label: Text(label),
      ),
    ),
  );
}

class _AudioLevel extends StatelessWidget {
  const _AudioLevel({required this.samples, required this.paused, super.key});

  final List<double> samples;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shown = samples.isEmpty ? const [0.08] : samples;
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final value
              in shown.length > 32 ? shown.sublist(shown.length - 32) : shown)
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 8 + (value * 56),
                  decoration: BoxDecoration(
                    color: paused
                        ? colors.outlineVariant
                        : colors.primary.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuietNotice extends StatelessWidget {
  const _QuietNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(text),
    ),
  );
}

String _heading(AudioCaptureState state, {String? introHeading}) =>
    switch (state.phase) {
      AudioCapturePhase.recording => 'Recording',
      AudioCapturePhase.paused => 'Recording paused',
      AudioCapturePhase.review => 'Your recording',
      AudioCapturePhase.failure => 'Recording unavailable',
      _ => introHeading ?? 'Record a memory',
    };

String? _description(
  AudioCaptureState state, {
  String? introDescription,
}) => switch (state.phase) {
  AudioCapturePhase.recording => 'On this device only',
  AudioCapturePhase.paused ||
  AudioCapturePhase.review ||
  AudioCapturePhase.failure => null,
  _ => introDescription,
};

String _failureText(AudioCaptureFailure? failure) => switch (failure) {
  AudioCaptureFailure.permissionDenied => 'Microphone access was not granted.',
  AudioCaptureFailure.unavailable => 'The microphone is unavailable right now.',
  _ => 'Recording interrupted. Discard to try again.',
};

String _durationLabel(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spokenDuration(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';
