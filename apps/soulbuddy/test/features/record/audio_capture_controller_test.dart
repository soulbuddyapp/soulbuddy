import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';

void main() {
  late _FakeAudioRecorder recorder;
  late _FakeElapsedClock clock;
  late _FakeTickerFactory tickers;
  late AudioCaptureController controller;
  late bool captureReserved;

  setUp(() {
    captureReserved = false;
    recorder = _FakeAudioRecorder();
    clock = _FakeElapsedClock();
    tickers = _FakeTickerFactory();
    controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take-1', locator: '/tmp/take-1.m4a'),
      beforeCapture: () async {
        captureReserved = true;
        recorder.events.add('reserve');
      },
      afterCapture: () async {
        captureReserved = false;
        recorder.events.add('release');
      },
      elapsedClock: clock,
      tickerFactory: tickers.call,
    );
  });

  tearDown(() async => controller.close());

  test('permission denial leaves speaking safely for Write instead', () async {
    recorder.permissionGranted = false;

    await controller.start();

    expect(controller.state.phase, AudioCapturePhase.failure);
    expect(controller.state.failure, AudioCaptureFailure.permissionDenied);
    expect(controller.state.canWriteInstead, isTrue);
    expect(recorder.startCalls, 0);
    expect(controller.hasPendingRecording, isFalse);
    expect(captureReserved, isFalse);
  });

  test(
    'a failed native start is cancelled before playback is released',
    () async {
      recorder
        ..startError = StateError(
          'native start failed after opening microphone',
        )
        ..cancelGate = Completer<void>();

      final starting = controller.start();
      await _flushEvents();

      expect(recorder.events, ['reserve', 'start', 'cancel']);
      expect(recorder.nativeActive, isTrue);
      expect(controller.hasPendingRecording, isTrue);
      expect(captureReserved, isTrue);

      recorder.cancelGate!.complete();
      await starting;

      expect(recorder.nativeActive, isFalse);
      expect(controller.hasPendingRecording, isFalse);
      expect(captureReserved, isFalse);
      expect(controller.state.failure, AudioCaptureFailure.unavailable);
      expect(recorder.events, ['reserve', 'start', 'cancel', 'release']);

      recorder.startError = null;
      await controller.start();
      expect(recorder.startCalls, 2);
      expect(controller.state.phase, AudioCapturePhase.recording);
    },
  );

  test(
    'failed start cleanup retains the capture lease until a retry',
    () async {
      recorder
        ..startError = StateError(
          'native start failed after opening microphone',
        )
        ..cancelError = StateError('native cancellation failed');

      await controller.start();

      expect(controller.state.phase, AudioCapturePhase.failure);
      expect(controller.state.failure, AudioCaptureFailure.unexpected);
      expect(controller.hasPendingRecording, isTrue);
      expect(captureReserved, isTrue);
      expect(recorder.nativeActive, isTrue);
      expect(recorder.events, ['reserve', 'start', 'cancel']);

      await controller.start();
      expect(recorder.startCalls, 1);

      recorder.cancelError = null;
      await controller.cancel();

      expect(recorder.cancelCalls, 2);
      expect(recorder.nativeActive, isFalse);
      expect(controller.hasPendingRecording, isFalse);
      expect(captureReserved, isFalse);
      expect(controller.state.phase, AudioCapturePhase.explaining);
    },
  );

  test('records, pauses, resumes, and stops into a bounded review', () async {
    await controller.start();
    expect(controller.state.phase, AudioCapturePhase.recording);
    expect(recorder.startCalls, 1);

    for (var index = 0; index < 200; index++) {
      recorder.amplitudeController.add(index.isEven ? 2 : -1);
    }
    await _flushEvents();
    expect(controller.state.liveWaveform, hasLength(180));
    expect(
      controller.state.liveWaveform.every((value) => value == 0 || value == 1),
      isTrue,
    );

    clock.advance(const Duration(seconds: 4));
    tickers.fire();
    expect(controller.state.elapsed, const Duration(seconds: 4));

    await controller.pause();
    expect(controller.state.phase, AudioCapturePhase.paused);
    expect(recorder.pauseCalls, 1);
    clock.advance(const Duration(seconds: 5));
    tickers.fire();
    expect(controller.state.elapsed, const Duration(seconds: 4));

    await controller.resume();
    clock.advance(const Duration(seconds: 3));
    tickers.fire();
    expect(controller.state.elapsed, const Duration(seconds: 7));

    await controller.stop();

    expect(controller.state.phase, AudioCapturePhase.review);
    expect(controller.state.review, isNotNull);
    expect(controller.state.review!.temporaryKey, 'blob:recording');
    expect(controller.state.review!.mimeType, 'audio/mp4');
    expect(controller.state.review!.duration, const Duration(seconds: 7));
    expect(controller.state.review!.waveform.length, lessThanOrEqualTo(64));
    expect(recorder.stopCalls, 1);
  });

  test('rapid duplicate controls invoke each recorder command once', () async {
    recorder.startGate = Completer<void>();

    final firstStart = controller.start();
    final secondStart = controller.start();
    await _flushEvents();
    expect(recorder.permissionCalls, 1);
    expect(recorder.startCalls, 1);

    recorder.startGate!.complete();
    await Future.wait([firstStart, secondStart]);
    recorder.stopGate = Completer<void>();

    final firstStop = controller.stop();
    final secondStop = controller.stop();
    await _flushEvents();
    expect(recorder.stopCalls, 1);

    recorder.stopGate!.complete();
    await Future.wait([firstStop, secondStop]);
    expect(controller.state.phase, AudioCapturePhase.review);
  });

  test('the fifteen minute ceiling stops exactly once', () async {
    await controller.start();
    clock.advance(const Duration(minutes: 15));

    tickers.fire();
    tickers.fire();
    await _flushEvents();

    expect(recorder.stopCalls, 1);
    expect(controller.state.phase, AudioCapturePhase.review);
    expect(controller.state.review!.duration, const Duration(minutes: 15));
  });

  test('a prayer refrain stops at its configured ceiling', () async {
    await controller.close();
    recorder = _FakeAudioRecorder();
    clock = _FakeElapsedClock();
    tickers = _FakeTickerFactory();
    controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'refrain-1', locator: '/tmp/refrain.m4a'),
      maximumDuration: const Duration(seconds: 25),
      elapsedClock: clock,
      tickerFactory: tickers.call,
    );

    await controller.start();
    clock.advance(const Duration(seconds: 25));

    tickers.fire();
    tickers.fire();
    await _flushEvents();

    expect(recorder.stopCalls, 1);
    expect(controller.state.phase, AudioCapturePhase.review);
    expect(controller.state.review!.duration, const Duration(seconds: 25));
  });

  test('a failed stop keeps the active take cancellable', () async {
    await controller.start();
    recorder.stopError = StateError('platform stop failed');

    await controller.stop();
    expect(controller.state.phase, AudioCapturePhase.failure);
    expect(controller.state.failure, AudioCaptureFailure.unexpected);

    await controller.cancel();
    expect(recorder.cancelCalls, 1);
    expect(controller.state.phase, AudioCapturePhase.explaining);
  });

  test(
    'lifecycle interruption pauses truthfully and close releases resources',
    () async {
      await controller.start();
      clock.advance(const Duration(seconds: 2));

      await controller.handleInterruption();

      expect(controller.state.phase, AudioCapturePhase.paused);
      expect(
        controller.state.notice,
        'Recording paused when SoulBuddy left the foreground',
      );
      expect(recorder.pauseCalls, 1);

      await controller.close();
      expect(recorder.cancelCalls, 1);
      expect(recorder.disposeCalls, 1);
      expect(recorder.amplitudeController.hasListener, isFalse);
      expect(tickers.latest?.cancelled, isTrue);
    },
  );

  test(
    'close waits for an in-flight start then releases its microphone',
    () async {
      recorder.startGate = Completer<void>();
      final start = controller.start();
      await _flushEvents();

      final close = controller.close();
      await _flushEvents();
      expect(controller.hasPendingRecording, isTrue);
      expect(captureReserved, isTrue);
      expect(recorder.cancelCalls, 0);
      expect(recorder.disposeCalls, 0);

      recorder.startGate!.complete();
      await Future.wait([start, close]);

      expect(recorder.cancelCalls, 1);
      expect(recorder.disposeCalls, 1);
      expect(recorder.nativeActive, isFalse);
      expect(controller.hasPendingRecording, isFalse);
      expect(captureReserved, isFalse);
      expect(tickers.latest, isNull);
      expect(recorder.events, [
        'reserve',
        'start',
        'cancel',
        'dispose',
        'release',
      ]);
    },
  );

  test(
    'concurrent closes share native disposal and retain its lease',
    () async {
      await controller.start();
      recorder
        ..cancelError = StateError('native cancellation failed')
        ..disposeGate = Completer<void>();

      final firstClose = controller.close();
      final secondClose = controller.close();
      expect(identical(firstClose, secondClose), isTrue);
      await _flushEvents();

      expect(recorder.disposeCalls, 1);
      expect(recorder.nativeActive, isTrue);
      expect(controller.hasPendingRecording, isTrue);
      expect(captureReserved, isTrue);
      expect(recorder.events, ['reserve', 'start', 'cancel', 'dispose']);

      recorder.disposeGate!.complete();
      await Future.wait([firstClose, secondClose]);

      expect(recorder.nativeActive, isFalse);
      expect(controller.hasPendingRecording, isFalse);
      expect(captureReserved, isFalse);
      expect(recorder.events.last, 'release');
      expect(identical(controller.close(), firstClose), isTrue);
    },
  );

  test('failed native close keeps the lease and retries teardown', () async {
    await controller.start();
    recorder
      ..cancelError = StateError('native cancellation failed')
      ..disposeError = StateError('native disposal failed');

    await expectLater(controller.close(), throwsStateError);

    expect(controller.hasPendingRecording, isTrue);
    expect(recorder.nativeActive, isTrue);
    expect(captureReserved, isTrue);
    expect(recorder.events, ['reserve', 'start', 'cancel', 'dispose']);
    await controller.start();
    expect(recorder.startCalls, 1);

    recorder.disposeError = null;
    await controller.close();

    expect(recorder.cancelCalls, 2);
    expect(recorder.disposeCalls, 2);
    expect(recorder.nativeActive, isFalse);
    expect(controller.hasPendingRecording, isFalse);
    expect(captureReserved, isFalse);
    expect(recorder.events.last, 'release');
  });

  test('close immediately discards an unsaved review take', () async {
    await controller.start();
    clock.advance(const Duration(seconds: 1));
    await controller.stop();

    await controller.close();

    expect(recorder.discardedLocators, ['blob:recording']);
    expect(recorder.disposeCalls, 1);
  });

  test(
    'close retains a failed review deletion for a later cleanup retry',
    () async {
      await controller.start();
      await controller.stop();
      recorder.discardError = StateError('private take deletion failed');

      await expectLater(controller.close(), throwsStateError);

      expect(controller.hasPendingRecording, isTrue);
      expect(recorder.disposeCalls, 1);
      expect(recorder.nativeActive, isFalse);
      expect(captureReserved, isFalse);

      recorder.discardError = null;
      await controller.close();

      expect(controller.hasPendingRecording, isFalse);
      expect(recorder.discardCalls, 2);
      expect(recorder.discardedLocators, ['blob:recording']);
      expect(recorder.disposeCalls, 1);
    },
  );

  test(
    'taking a reviewed draft transfers cleanup ownership to caller',
    () async {
      await controller.start();
      clock.advance(const Duration(seconds: 1));
      await controller.stop();

      final draft = controller.takeReview();
      expect(draft?.temporaryKey, 'blob:recording');
      expect(controller.state.phase, AudioCapturePhase.explaining);
      expect(controller.hasPendingRecording, isFalse);

      await controller.close();

      expect(recorder.discardedLocators, isEmpty);
    },
  );

  test('discard and record again remove the unsaved take', () async {
    await controller.start();
    clock.advance(const Duration(seconds: 1));
    await controller.stop();

    await controller.recordAgain();

    expect(recorder.discardedLocators, ['blob:recording']);
    expect(controller.state.phase, AudioCapturePhase.recording);
    expect(recorder.startCalls, 2);

    clock.advance(const Duration(seconds: 1));
    await controller.stop();
    await controller.discard();
    expect(recorder.discardedLocators, ['blob:recording', 'blob:recording']);
    expect(controller.state.phase, AudioCapturePhase.explaining);
  });

  test(
    'cancel retries a failed discard without losing the reviewed take',
    () async {
      await controller.start();
      await controller.stop();
      final review = controller.state.review;
      recorder.discardError = StateError('private take deletion failed');

      await controller.discard();

      expect(controller.state.phase, AudioCapturePhase.failure);
      expect(controller.state.review, same(review));
      expect(controller.hasPendingRecording, isTrue);
      expect(captureReserved, isFalse);
      await controller.start();
      expect(recorder.startCalls, 1);

      recorder.discardError = null;
      await controller.cancel();

      expect(recorder.discardCalls, 2);
      expect(recorder.discardedLocators, ['blob:recording']);
      expect(controller.hasPendingRecording, isFalse);
      expect(controller.state.phase, AudioCapturePhase.explaining);
    },
  );

  test('record again can retry deletion after a failed replacement', () async {
    await controller.start();
    await controller.stop();
    recorder.discardError = StateError('private take deletion failed');

    await controller.recordAgain();
    expect(controller.state.phase, AudioCapturePhase.failure);
    expect(controller.hasPendingRecording, isTrue);
    expect(recorder.startCalls, 1);

    recorder.discardError = null;
    await controller.recordAgain();

    expect(recorder.discardCalls, 2);
    expect(recorder.startCalls, 2);
    expect(controller.state.phase, AudioCapturePhase.recording);
    expect(controller.hasPendingRecording, isTrue);
    expect(captureReserved, isTrue);
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _FakeAudioRecorder implements AudioRecorderGateway {
  bool permissionGranted = true;
  bool supportsPause = true;
  int permissionCalls = 0;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  int discardCalls = 0;
  bool nativeActive = false;
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Completer<void>? cancelGate;
  Completer<void>? disposeGate;
  Object? startError;
  Object? stopError;
  Object? cancelError;
  Object? disposeError;
  Object? discardError;
  final events = <String>[];
  final amplitudeController = StreamController<double>.broadcast();
  final discardedLocators = <String>[];

  @override
  Stream<double> get amplitudes => amplitudeController.stream;

  @override
  bool get canPause => supportsPause;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<void> start(TemporaryAudio temporary) async {
    startCalls++;
    events.add('start');
    nativeActive = true;
    await startGate?.future;
    if (startError case final error?) throw error;
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<AudioRecorderResult> stop() async {
    stopCalls++;
    await stopGate?.future;
    if (stopError case final error?) throw error;
    nativeActive = false;
    return const AudioRecorderResult(
      locator: 'blob:recording',
      mimeType: 'audio/mp4',
    );
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    events.add('cancel');
    await cancelGate?.future;
    if (cancelError case final error?) throw error;
    nativeActive = false;
  }

  @override
  Future<void> discard(AudioRecorderResult result) async {
    discardCalls++;
    if (discardError case final error?) throw error;
    discardedLocators.add(result.locator);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    events.add('dispose');
    await disposeGate?.future;
    if (disposeError case final error?) throw error;
    nativeActive = false;
    await amplitudeController.close();
  }
}

class _FakeElapsedClock implements AudioElapsedClock {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration duration) {
    if (_running) _elapsed += duration;
  }

  @override
  void reset() => _elapsed = Duration.zero;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;
}

class _FakeTickerFactory {
  _FakeTicker? latest;

  AudioCaptureTicker call(Duration interval, void Function() callback) {
    latest = _FakeTicker(callback);
    return latest!;
  }

  void fire() => latest?.fire();
}

class _FakeTicker implements AudioCaptureTicker {
  _FakeTicker(this.callback);

  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;
}
