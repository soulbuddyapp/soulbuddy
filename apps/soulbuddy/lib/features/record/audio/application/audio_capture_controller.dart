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
  final RecordedAudioDraft? review;
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
    Future<void> Function()? beforeCapture,
    Future<void> Function()? afterCapture,
    this.maximumDuration = maximumMemoryAudioDuration,
    AudioElapsedClock? elapsedClock,
    AudioCaptureTickerFactory? tickerFactory,
  }) : _recorder = recorder,
       _allocateTemporary = allocateTemporary,
       _beforeCapture = beforeCapture,
       _afterCapture = afterCapture,
       _elapsedClock = elapsedClock ?? StopwatchAudioElapsedClock(),
       _tickerFactory = tickerFactory ?? _createTimerTicker {
    if (maximumDuration <= Duration.zero ||
        maximumDuration > maximumMemoryAudioDuration) {
      throw ArgumentError.value(maximumDuration, 'maximumDuration');
    }
    _amplitudeSubscription = _recorder.amplitudes.listen(_onAmplitude);
  }

  static const _tickerInterval = Duration(milliseconds: 200);
  static const _maximumLiveSamples = 180;
  static const _maximumReviewSamples = 64;

  final AudioRecorderGateway _recorder;
  final Future<TemporaryAudio> Function() _allocateTemporary;
  final Future<void> Function()? _beforeCapture;
  final Future<void> Function()? _afterCapture;
  bool _audioLeaseAcquired = false;
  final Duration maximumDuration;
  final AudioElapsedClock _elapsedClock;
  final AudioCaptureTickerFactory _tickerFactory;
  late final StreamSubscription<double> _amplitudeSubscription;

  AudioCaptureState _state = const AudioCaptureState.explaining();
  AudioCaptureState get state => _state;

  /// Includes failed starts and failed review deletion until cleanup succeeds.
  /// A draft handed off with [takeReview] is owned by its caller instead.
  bool get hasPendingRecording =>
      _recordingSessionActive || _reviewResult != null;

  final List<double> _allSamples = [];
  AudioCaptureTicker? _ticker;
  AudioRecorderResult? _reviewResult;
  Future<void>? _activeCommand;
  bool _closed = false;
  bool _recordingSessionActive = false;
  bool _recorderDisposed = false;
  bool _closeComplete = false;
  Future<void>? _closeFuture;

  Future<void> start() => _runCommand(_beginRecording);

  Future<void> _beginRecording() async {
    if (_closed ||
        _recordingSessionActive ||
        _reviewResult != null ||
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
      if (_closed) return;
      _audioLeaseAcquired = _beforeCapture != null;
      await _beforeCapture?.call();
      if (_closed) return;
      final temporary = await _allocateTemporary();
      if (_closed) return;
      // A native start may activate the microphone before its Future fails.
      // Retain ownership until cancellation or disposal confirms it is closed.
      _recordingSessionActive = true;
      await _recorder.start(temporary);
      if (_closed) return;
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
          _recordingSessionActive = false;
        } catch (_) {
          // The microphone may still be active. Keep the playback reservation
          // and allow the person to retry cleanup instead of starting again.
          _emit(_failureState());
          return;
        }
      }
      await _releaseAudioLease();
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
    if (_closed || _state.phase != AudioCapturePhase.paused) return;
    try {
      _audioLeaseAcquired = _beforeCapture != null;
      await _beforeCapture?.call();
      if (_closed) return;
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
    RecordedAudioDraft? review;
    try {
      final result = await _recorder.stop();
      _recordingSessionActive = false;
      _ticker?.cancel();
      _reviewResult = result;
      review = RecordedAudioDraft(
        temporaryKey: result.locator,
        mimeType: result.mimeType,
        duration: elapsed,
        waveform: _reviewWaveform(),
      );
      await _releaseAudioLease();
      _emit(
        AudioCaptureState(
          phase: AudioCapturePhase.review,
          elapsed: elapsed,
          liveWaveform: _liveSamples(),
          review: review,
        ),
      );
    } catch (_) {
      _emit(_failureState(elapsed: elapsed, review: review));
    }
  }

  Future<void> cancel() => _runCommand(() async {
    if (!_recordingSessionActive && _reviewResult != null) {
      await _discardWithinCommand();
      return;
    }
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
      await _releaseAudioLease();
      _resetToExplaining();
    } catch (_) {
      _emit(_failureState());
    }
  });

  Future<void> discard() => _runCommand(_discardWithinCommand);

  Future<void> _discardWithinCommand() async {
    final result = _reviewResult;
    if (result == null ||
        (_state.phase != AudioCapturePhase.review &&
            _state.phase != AudioCapturePhase.failure)) {
      return;
    }
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
      await _releaseAudioLease();
      _resetToExplaining();
    } catch (_) {
      _emit(_failureState(elapsed: _state.elapsed));
    }
  }

  /// Hands the reviewed temporary recording to the caller without deleting it.
  ///
  /// After this call the caller owns the draft and must either commit or
  /// discard it. Closing this controller will no longer remove the take.
  RecordedAudioDraft? takeReview() {
    if (_closed || _state.phase != AudioCapturePhase.review) return null;
    final draft = _state.review;
    if (draft == null || _reviewResult == null) return null;
    _reviewResult = null;
    _resetToExplaining();
    return draft;
  }

  Future<void> recordAgain() => _runCommand(() async {
    if (_reviewResult == null) return;
    await _discardWithinCommand();
    if (_reviewResult == null && _state.phase == AudioCapturePhase.explaining) {
      await _beginRecording();
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

  Future<void> close() {
    final pending = _closeFuture;
    if (pending != null) return pending;
    _closed = true;
    late final Future<void> closing;
    closing = _closeResources().whenComplete(() {
      if (!_closeComplete && identical(_closeFuture, closing)) {
        _closeFuture = null;
      }
    });
    _closeFuture = closing;
    return closing;
  }

  Future<void> _closeResources() async {
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
        _recordingSessionActive = false;
      } catch (_) {
        // Disposal must continue so the microphone is released.
      }
    }
    Object? reviewCleanupError;
    StackTrace? reviewCleanupStack;
    if (_reviewResult case final result?) {
      try {
        await _recorder.discard(result);
        _reviewResult = null;
      } catch (error, stackTrace) {
        // Release the microphone even if deleting its private take fails,
        // while retaining the take so a subsequent close can retry deletion.
        reviewCleanupError = error;
        reviewCleanupStack = stackTrace;
      }
    }
    try {
      if (!_recorderDisposed) {
        await _recorder.dispose();
        _recorderDisposed = true;
        _recordingSessionActive = false;
      }
    } finally {
      // If both native cancellation and disposal fail, playback stays locked.
      // A later close() retries teardown without permitting another capture.
      if (!_recordingSessionActive) await _releaseAudioLease();
    }
    if (reviewCleanupError != null) {
      Error.throwWithStackTrace(reviewCleanupError, reviewCleanupStack!);
    }
    _closeComplete = true;
  }

  Future<void> _releaseAudioLease() async {
    if (!_audioLeaseAcquired) return;
    await _afterCapture?.call();
    _audioLeaseAcquired = false;
  }

  Future<void> _runCommand(Future<void> Function() command) {
    if (_closed) return Future.value();
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
    if (elapsed >= maximumDuration) {
      unawaited(stop());
    }
  }

  AudioCaptureState _captureState(AudioCapturePhase phase) => AudioCaptureState(
    phase: phase,
    elapsed: _boundedElapsed(),
    liveWaveform: _liveSamples(),
    notice: _state.notice,
  );

  AudioCaptureState _failureState({
    Duration? elapsed,
    RecordedAudioDraft? review,
  }) => AudioCaptureState(
    phase: AudioCapturePhase.failure,
    elapsed: elapsed ?? _boundedElapsed(),
    liveWaveform: _liveSamples(),
    review: review ?? _state.review,
    failure: AudioCaptureFailure.unexpected,
  );

  Duration _boundedElapsed() {
    final elapsed = _elapsedClock.elapsed;
    if (elapsed >= maximumDuration) {
      return maximumDuration;
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
