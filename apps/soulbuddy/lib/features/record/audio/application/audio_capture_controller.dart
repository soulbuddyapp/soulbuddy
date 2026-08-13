import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/audio_asset_store.dart';
import '../domain/memory_audio.dart';
import 'audio_recorder.dart';

enum AudioCapturePhase {
  idle,
  explaining,
  requestingPermission,
  recording,
  paused,
  stopping,
  review,
  cancelling,
  failure,
}

enum AudioCaptureFailure { permissionDenied, unavailable, unexpected }

@immutable
class AudioCaptureState {
  const AudioCaptureState({
    required this.phase,
    this.elapsed = Duration.zero,
    this.liveWaveform = const [],
    this.review,
    this.failure,
    this.notice,
  });

  const AudioCaptureState.explaining()
    : this(phase: AudioCapturePhase.explaining);

  final AudioCapturePhase phase;
  final Duration elapsed;
  final List<double> liveWaveform;
  final MemoryAudioDraft? review;
  final AudioCaptureFailure? failure;
  final String? notice;

  bool get canWriteInstead =>
      failure == AudioCaptureFailure.permissionDenied ||
      failure == AudioCaptureFailure.unavailable;

  bool get commandInFlight =>
      phase == AudioCapturePhase.requestingPermission ||
      phase == AudioCapturePhase.stopping ||
      phase == AudioCapturePhase.cancelling;
}

class AudioCaptureController extends ChangeNotifier {
  AudioCaptureController({
    required AudioRecorderGateway recorder,
    required Future<TemporaryAudio> Function() allocateTemporary,
    AudioElapsedClock? elapsedClock,
    AudioCaptureTickerFactory? tickerFactory,
  }) : _recorder = recorder,
       _allocateTemporary = allocateTemporary,
       _elapsedClock = elapsedClock ?? StopwatchAudioElapsedClock(),
       _tickerFactory = tickerFactory ?? _createTimerTicker {
    _amplitudeSubscription = _recorder.amplitudes.listen(_onAmplitude);
  }

  static const _tickerInterval = Duration(milliseconds: 200);
  static const _maximumLiveSamples = 180;
  static const _maximumReviewSamples = 64;

  final AudioRecorderGateway _recorder;
  final Future<TemporaryAudio> Function() _allocateTemporary;
  final AudioElapsedClock _elapsedClock;
  final AudioCaptureTickerFactory _tickerFactory;
  late final StreamSubscription<double> _amplitudeSubscription;

  AudioCaptureState _state = const AudioCaptureState.explaining();
  AudioCaptureState get state => _state;

  final List<double> _allSamples = [];
  AudioCaptureTicker? _ticker;
  AudioRecorderResult? _reviewResult;
  Future<void>? _activeCommand;
  bool _closed = false;
  bool _recordingSessionActive = false;

  Future<void> start() => _runCommand(_beginRecording);

  Future<void> _beginRecording() async {
    if (_closed ||
        _recordingSessionActive ||
        (_state.phase != AudioCapturePhase.explaining &&
            _state.phase != AudioCapturePhase.failure &&
            _state.phase != AudioCapturePhase.idle)) {
      return;
    }
    _emit(
      AudioCaptureState(
        phase: AudioCapturePhase.requestingPermission,
        elapsed: _state.elapsed,
        liveWaveform: _state.liveWaveform,
      ),
    );
    try {
      if (!await _recorder.requestPermission()) {
        _emit(
          const AudioCaptureState(
            phase: AudioCapturePhase.failure,
            failure: AudioCaptureFailure.permissionDenied,
          ),
        );
        return;
      }
      final temporary = await _allocateTemporary();
      await _recorder.start(temporary);
      _recordingSessionActive = true;
      _elapsedClock
        ..reset()
        ..start();
      _allSamples.clear();
      _reviewResult = null;
      _ticker?.cancel();
      _ticker = _tickerFactory(_tickerInterval, _onTick);
      _emit(const AudioCaptureState(phase: AudioCapturePhase.recording));
    } catch (_) {
      _elapsedClock.stop();
      _ticker?.cancel();
      if (_recordingSessionActive) {
        try {
          await _recorder.cancel();
        } catch (_) {
          // Preserve the original unavailable state.
        }
        _recordingSessionActive = false;
      }
      _emit(
        const AudioCaptureState(
          phase: AudioCapturePhase.failure,
          failure: AudioCaptureFailure.unavailable,
        ),
      );
    }
  }

  Future<void> pause() => _runCommand(() async {
    if (_state.phase != AudioCapturePhase.recording) return;
    try {
      await _recorder.pause();
      _elapsedClock.stop();
      _emit(_captureState(AudioCapturePhase.paused));
    } catch (_) {
      _emit(_failureState());
    }
  });

  Future<void> resume() => _runCommand(() async {
    if (_state.phase != AudioCapturePhase.paused) return;
    try {
      await _recorder.resume();
      _elapsedClock.start();
      _emit(_captureState(AudioCapturePhase.recording));
    } catch (_) {
      _emit(_failureState());
    }
  });

  Future<void> stop() => _runCommand(_stopWithinCommand);

  Future<void> _stopWithinCommand() async {
    if (_state.phase != AudioCapturePhase.recording &&
        _state.phase != AudioCapturePhase.paused) {
      return;
    }
    _elapsedClock.stop();
    final elapsed = _boundedElapsed();
    _emit(
      AudioCaptureState(
        phase: AudioCapturePhase.stopping,
        elapsed: elapsed,
        liveWaveform: _liveSamples(),
      ),
    );
    try {
      final result = await _recorder.stop();
      _recordingSessionActive = false;
      _ticker?.cancel();
      _reviewResult = result;
      final review = MemoryAudioDraft(
        temporaryKey: result.locator,
        mimeType: result.mimeType,
        duration: elapsed,
        waveform: _reviewWaveform(),
      );
      _emit(
        AudioCaptureState(
          phase: AudioCapturePhase.review,
          elapsed: elapsed,
          liveWaveform: _liveSamples(),
          review: review,
        ),
      );
    } catch (_) {
      _emit(_failureState(elapsed: elapsed));
    }
  }

  Future<void> cancel() => _runCommand(() async {
    if (!_recordingSessionActive ||
        (_state.phase != AudioCapturePhase.recording &&
            _state.phase != AudioCapturePhase.paused &&
            _state.phase != AudioCapturePhase.failure)) {
      return;
    }
    _emit(_captureState(AudioCapturePhase.cancelling));
    try {
      await _recorder.cancel();
      _recordingSessionActive = false;
      _resetToExplaining();
    } catch (_) {
      _emit(_failureState());
    }
  });

  Future<void> discard() => _runCommand(() async {
    final result = _reviewResult;
    if (_state.phase != AudioCapturePhase.review || result == null) return;
    _emit(
      AudioCaptureState(
        phase: AudioCapturePhase.cancelling,
        elapsed: _state.elapsed,
        liveWaveform: _state.liveWaveform,
        review: _state.review,
      ),
    );
    try {
      await _recorder.discard(result);
      _resetToExplaining();
    } catch (_) {
      _emit(_failureState(elapsed: _state.elapsed));
    }
  });

  Future<void> recordAgain() => _runCommand(() async {
    final result = _reviewResult;
    if (_state.phase != AudioCapturePhase.review || result == null) return;
    try {
      await _recorder.discard(result);
      _resetToExplaining();
      await _beginRecording();
    } catch (_) {
      _emit(_failureState(elapsed: _state.elapsed));
    }
  });

  Future<void> handleInterruption() => _runCommand(() async {
    if (_state.phase != AudioCapturePhase.recording) return;
    if (!_recorder.canPause) {
      await _stopWithinCommand();
      return;
    }
    try {
      await _recorder.pause();
      _elapsedClock.stop();
      _emit(
        AudioCaptureState(
          phase: AudioCapturePhase.paused,
          elapsed: _boundedElapsed(),
          liveWaveform: _liveSamples(),
          notice: 'Recording paused when SoulBuddy left the foreground',
        ),
      );
    } catch (_) {
      await _stopWithinCommand();
    }
  });

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _activeCommand;
    } catch (_) {
      // The state already carries a privacy-safe recoverable failure.
    }
    _ticker?.cancel();
    _elapsedClock.stop();
    await _amplitudeSubscription.cancel();
    if (_recordingSessionActive) {
      try {
        await _recorder.cancel();
      } catch (_) {
        // Disposal must continue so the microphone is released.
      }
      _recordingSessionActive = false;
    }
    await _recorder.dispose();
  }

  Future<void> _runCommand(Future<void> Function() command) {
    final active = _activeCommand;
    if (active != null) return active;
    late final Future<void> future;
    future = command().whenComplete(() {
      if (identical(_activeCommand, future)) _activeCommand = null;
    });
    _activeCommand = future;
    return future;
  }

  void _onAmplitude(double value) {
    if (_closed || _state.phase != AudioCapturePhase.recording) return;
    final normalized = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    _allSamples.add(normalized);
    _emit(_captureState(AudioCapturePhase.recording));
  }

  void _onTick() {
    if (_closed || _state.phase != AudioCapturePhase.recording) return;
    final elapsed = _boundedElapsed();
    _emit(_captureState(AudioCapturePhase.recording));
    if (elapsed >= maximumMemoryAudioDuration) {
      unawaited(stop());
    }
  }

  AudioCaptureState _captureState(AudioCapturePhase phase) => AudioCaptureState(
    phase: phase,
    elapsed: _boundedElapsed(),
    liveWaveform: _liveSamples(),
    notice: _state.notice,
  );

  AudioCaptureState _failureState({Duration? elapsed}) => AudioCaptureState(
    phase: AudioCapturePhase.failure,
    elapsed: elapsed ?? _boundedElapsed(),
    liveWaveform: _liveSamples(),
    failure: AudioCaptureFailure.unexpected,
  );

  Duration _boundedElapsed() {
    final elapsed = _elapsedClock.elapsed;
    if (elapsed >= maximumMemoryAudioDuration) {
      return maximumMemoryAudioDuration;
    }
    return elapsed < const Duration(milliseconds: 1)
        ? const Duration(milliseconds: 1)
        : elapsed;
  }

  List<double> _liveSamples() => List.unmodifiable(
    _allSamples.length <= _maximumLiveSamples
        ? _allSamples
        : _allSamples.sublist(_allSamples.length - _maximumLiveSamples),
  );

  List<double> _reviewWaveform() {
    if (_allSamples.isEmpty) return const [0.0];
    if (_allSamples.length <= _maximumReviewSamples) {
      return List.unmodifiable(_allSamples);
    }
    final bucketSize = (_allSamples.length / _maximumReviewSamples).ceil();
    final peaks = <double>[];
    for (var start = 0; start < _allSamples.length; start += bucketSize) {
      final end = math.min(start + bucketSize, _allSamples.length);
      var peak = 0.0;
      for (var index = start; index < end; index++) {
        peak = math.max(peak, _allSamples[index]);
      }
      peaks.add(peak);
    }
    return List.unmodifiable(peaks);
  }

  void _resetToExplaining() {
    _ticker?.cancel();
    _elapsedClock
      ..stop()
      ..reset();
    _allSamples.clear();
    _reviewResult = null;
    _emit(const AudioCaptureState.explaining());
  }

  void _emit(AudioCaptureState value) {
    if (_closed) return;
    _state = value;
    notifyListeners();
  }
}

AudioCaptureTicker _createTimerTicker(
  Duration interval,
  void Function() callback,
) => _TimerAudioCaptureTicker(Timer.periodic(interval, (_) => callback()));

class _TimerAudioCaptureTicker implements AudioCaptureTicker {
  const _TimerAudioCaptureTicker(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
