import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../application/audio_capture_controller.dart';
import '../domain/memory_audio.dart';

class AudioCapturePanel extends StatefulWidget {
  const AudioCapturePanel({
    required this.controller,
    required this.onWriteInstead,
    required this.onContinue,
    this.onBack,
    this.introHeading,
    this.introDescription,
    this.startLabel = 'Start recording',
    this.alternativeLabel = 'Write instead',
    super.key,
  });

  final AudioCaptureController controller;
  final VoidCallback onWriteInstead;
  final ValueChanged<RecordedAudioDraft> onContinue;
  final VoidCallback? onBack;
  final String? introHeading;
  final String? introDescription;
  final String startLabel;
  final String alternativeLabel;

  @override
  State<AudioCapturePanel> createState() => _AudioCapturePanelState();
}

class _AudioCapturePanelState extends State<AudioCapturePanel>
    with WidgetsBindingObserver {
  final AudioPlayer _reviewPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  var _playerState = PlayerState.stopped;
  var _position = Duration.zero;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerStateSubscription = _reviewPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _playerState = state);
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
      unawaited(_reviewPlayer.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_reviewPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                          onPressed: state.commandInFlight ? null : onBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Record'),
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
                    Text(
                      _description(
                        state,
                        introDescription: widget.introDescription,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.notice case final notice?) ...[
                      _QuietNotice(text: notice),
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
  }

  List<Widget> _controls(AudioCaptureState state) => switch (state.phase) {
    AudioCapturePhase.idle || AudioCapturePhase.explaining => [
      _PrimaryControl(
        semanticLabel: 'Start audio recording',
        label: widget.startLabel,
        icon: Icons.mic_none,
        onPressed: widget.controller.start,
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        label: widget.alternativeLabel,
        icon: Icons.edit_outlined,
        onPressed: widget.onWriteInstead,
      ),
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
        onPressed: state.phase == AudioCapturePhase.paused
            ? widget.controller.resume
            : widget.controller.pause,
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Stop and review recording',
        label: 'Stop',
        icon: Icons.stop_rounded,
        onPressed: widget.controller.stop,
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Discard this recording',
        label: 'Discard',
        icon: Icons.delete_outline,
        onPressed: () => _confirmDiscard(review: false),
      ),
    ],
    AudioCapturePhase.stopping || AudioCapturePhase.cancelling => const [
      Center(child: CircularProgressIndicator()),
      SizedBox(height: AppSpacing.sm),
      Center(child: Text('Keeping the recording private…')),
    ],
    AudioCapturePhase.review => _reviewControls(state),
    AudioCapturePhase.failure => [
      _QuietNotice(text: _failureText(state.failure)),
      const SizedBox(height: AppSpacing.md),
      if (state.canWriteInstead) ...[
        _PrimaryControl(
          label: widget.alternativeLabel,
          icon: Icons.edit_outlined,
          onPressed: widget.onWriteInstead,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SecondaryControl(
          label: 'Try microphone again',
          icon: Icons.mic_none,
          onPressed: widget.controller.start,
        ),
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
          onChanged: (value) =>
              _reviewPlayer.seek(Duration(milliseconds: value.round())),
        ),
      ),
      Center(
        child: Text(
          '${_durationLabel(_position)} / ${_durationLabel(review.duration)}',
        ),
      ),
      if (_playbackError case final error?) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(error, textAlign: TextAlign.center),
      ],
      const SizedBox(height: AppSpacing.md),
      _PrimaryControl(
        label: playing ? 'Pause playback' : 'Play',
        semanticLabel: playing ? 'Pause recording playback' : 'Play recording',
        icon: playing ? Icons.pause : Icons.play_arrow,
        onPressed: _togglePlayback,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PrimaryControl(
        label: 'Continue',
        icon: Icons.arrow_forward,
        onPressed: () {
          unawaited(_reviewPlayer.stop());
          widget.onContinue(review);
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        label: 'Record again',
        icon: Icons.replay,
        onPressed: () async {
          await _reviewPlayer.stop();
          await widget.controller.recordAgain();
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      _SecondaryControl(
        semanticLabel: 'Discard this recording',
        label: 'Discard',
        icon: Icons.delete_outline,
        onPressed: () => _confirmDiscard(review: true),
      ),
    ];
  }

  Future<void> _togglePlayback() async {
    final review = widget.controller.state.review;
    if (review == null) return;
    setState(() => _playbackError = null);
    try {
      if (_playerState == PlayerState.playing) {
        await _reviewPlayer.pause();
      } else if (_playerState == PlayerState.paused) {
        await _reviewPlayer.resume();
      } else {
        await _reviewPlayer.play(
          kIsWeb
              ? UrlSource(review.temporaryKey)
              : DeviceFileSource(review.temporaryKey),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _playbackError =
              'Playback is unavailable. The recording is still here.',
        );
      }
    }
  }

  Future<void> _confirmDiscard({required bool review}) async {
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
    await _reviewPlayer.stop();
    if (review) {
      await widget.controller.discard();
    } else {
      await widget.controller.cancel();
    }
  }
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
      AudioCapturePhase.review => 'Review your recording',
      AudioCapturePhase.failure => 'Speak is unavailable',
      _ => introHeading ?? 'Speak what you do not want to forget.',
    };

String _description(
  AudioCaptureState state, {
  String? introDescription,
}) => switch (state.phase) {
  AudioCapturePhase.recording =>
    'Speak at your own pace. This stays on this device.',
  AudioCapturePhase.paused => 'Nothing is being added until you resume.',
  AudioCapturePhase.review =>
    'Listen once, record again, or continue to describe the memory.',
  AudioCapturePhase.failure => 'You can keep the memory by writing instead.',
  _ =>
    introDescription ??
        'You choose when recording begins. SoulBuddy will not upload your voice.',
};

String _failureText(AudioCaptureFailure? failure) => switch (failure) {
  AudioCaptureFailure.permissionDenied => 'Microphone access was not granted.',
  AudioCaptureFailure.unavailable => 'The microphone is unavailable right now.',
  _ =>
    'The recording could not be completed. The active take can still be discarded safely.',
};

String _durationLabel(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spokenDuration(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';
