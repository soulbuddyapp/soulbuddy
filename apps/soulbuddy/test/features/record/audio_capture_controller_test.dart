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

  setUp(() {
    recorder = _FakeAudioRecorder();
    clock = _FakeElapsedClock();
    tickers = _FakeTickerFactory();
    controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take-1', locator: '/tmp/take-1.m4a'),
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
  });

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
      recorder.startGate!.complete();
      await Future.wait([start, close]);

      expect(recorder.cancelCalls, 1);
      expect(recorder.disposeCalls, 1);
    },
  );

  test('close immediately discards an unsaved review take', () async {
    await controller.start();
    clock.advance(const Duration(seconds: 1));
    await controller.stop();

    await controller.close();

    expect(recorder.discardedLocators, ['blob:recording']);
    expect(recorder.disposeCalls, 1);
  });

  test(
    'taking a reviewed draft transfers cleanup ownership to caller',
    () async {
      await controller.start();
      clock.advance(const Duration(seconds: 1));
      await controller.stop();

      final draft = controller.takeReview();
      expect(draft?.temporaryKey, 'blob:recording');
      expect(controller.state.phase, AudioCapturePhase.explaining);

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
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Object? stopError;
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
    await startGate?.future;
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
    return const AudioRecorderResult(
      locator: 'blob:recording',
      mimeType: 'audio/mp4',
    );
  }

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<void> discard(AudioRecorderResult result) async {
    discardedLocators.add(result.locator);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
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
