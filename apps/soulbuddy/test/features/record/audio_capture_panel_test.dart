import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/presentation/audio_capture_panel.dart';
import 'package:soulbuddy/features/record/audio/application/memory_soundscape_player.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_soundscape.dart';

void main() {
  late _PanelRecorder recorder;
  late AudioCaptureController controller;
  late _ReviewPlayer player;

  setUp(() {
    recorder = _PanelRecorder();
    player = _ReviewPlayer();
    controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );
  });

  tearDown(() => controller.close());

  testWidgets('inline capture shows live input without a nested scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AudioCapturePanel(
                controller: controller,
                inline: true,
                reviewPlayer: player,
                onContinue: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    recorder.amplitudesController.add(0.7);
    await tester.pump();
    expect(controller.state.phase, AudioCapturePhase.recording);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    await _cancelCapture(tester, controller);
  });

  testWidgets('opens capture without requesting the microphone or writing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            onContinue: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Record a memory'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Write instead'), findsNothing);
    expect(find.bySemanticsLabel('Start audio recording'), findsOneWidget);
    expect(recorder.permissionRequests, 0);
  });

  testWidgets('permission denial offers recovery without a text form', (
    tester,
  ) async {
    recorder.permissionGranted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            onContinue: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start recording'));
    await tester.pump();

    expect(find.text('Microphone access was not granted.'), findsOneWidget);
    expect(find.text('Write instead'), findsNothing);
    expect(find.text('Try microphone again'), findsOneWidget);
    expect(controller.state.phase, AudioCapturePhase.failure);
    recorder.permissionGranted = true;
    await tester.tap(find.text('Try microphone again'));
    await tester.pump();
    expect(controller.state.phase, AudioCapturePhase.recording);

    await _cancelCapture(tester, controller);
  });

  testWidgets('accepts focused prayer recording copy without duplicating UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            introHeading: 'Record this prayer',
            introDescription: 'Your recording stays private on this device.',
            startLabel: 'Start prayer recording',
            alternativeLabel: 'Not now',
            onWriteInstead: () {},
            onContinue: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Record this prayer'), findsOneWidget);
    expect(
      find.text('Your recording stays private on this device.'),
      findsOneWidget,
    );
    expect(find.text('Start prayer recording'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Speak what you do not want to forget.'), findsNothing);
  });

  testWidgets(
    'recording controls are truthful and hand off the original audio',
    (tester) async {
      MemoryAudioDraft? continued;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCapturePanel(
              controller: controller,
              reviewPlayer: player,
              onWriteInstead: () {},
              onContinue: (draft) => continued = draft,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start recording'));
      await tester.pump();
      recorder.amplitudesController.add(0.7);
      await tester.pump();

      expect(find.bySemanticsLabel('Pause recording'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Stop and review recording'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Discard this recording'), findsOneWidget);
      expect(find.byKey(const Key('audio-live-level')), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.bySemanticsLabel('Resume recording'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await tester.pump();

      expect(find.text('Your recording'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
      expect(find.text('Use recording'), findsOneWidget);

      await tester.ensureVisible(find.text('Use recording'));
      await tester.pump();
      await tester.tap(find.text('Use recording'));
      await tester.pumpAndSettle();
      expect(continued, isNotNull);
      expect(continued!.temporaryKey, '/private/take.m4a');
    },
  );

  testWidgets(
    'remains readable at 200% text without exposing level semantics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AudioCapturePanel(
              controller: controller,
              reviewPlayer: player,
              onContinue: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Start recording'), findsOneWidget);
      expect(find.text('Write instead'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unpreviewed take saves without a native audio output', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final outputCalls = <String>[];
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('xyz.luan/audioplayers'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        outputCalls.add(call.method);
        throw PlatformException(code: 'output_unavailable');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    RecordedAudioDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            enableSoundscape: true,
            onContinue: (draft) => saved = draft,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(slider.max / 2);
    slider.onChangeEnd!(slider.max / 2);
    await tester.pump();
    final background = find.byKey(const Key('recording-soundscape-stillness'));
    await tester.ensureVisible(background);
    await tester.tap(background);
    await tester.pump();
    await tester.ensureVisible(find.text('Use recording'));
    await tester.tap(find.text('Use recording'));
    await tester.pump();

    expect(saved?.temporaryKey, '/private/take.m4a');
    expect(saved?.soundscape, MemorySoundscape.stillness);
    expect(controller.hasPendingRecording, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(outputCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handoff waits for both preview layers and runs only once', (
    tester,
  ) async {
    final bed = _ReviewSoundscape();
    player.stopping = Completer<void>();
    bed.stopping = Completer<void>();
    var handedOff = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            reviewSoundscapePlayer: bed,
            onContinue: (_) => handedOff++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.ensureVisible(find.text('Use recording'));
    await tester.tap(find.text('Use recording'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    expect(controller.state.review, isNotNull);
    expect(handedOff, 0);
    player.stopping!.complete();
    await tester.pump();
    expect(handedOff, 0);
    bed.stopping!.complete();
    await tester.pump();
    expect(handedOff, 1);
    expect(player.stopCalls, 1);
    expect(bed.stopCalls, 1);
  });

  testWidgets('failed preview stop keeps the take available for retry', (
    tester,
  ) async {
    player.stopError = StateError('output unavailable');
    MemoryAudioDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            onContinue: (take) => saved = take,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.ensureVisible(find.text('Use recording'));
    await tester.tap(find.text('Use recording'));
    await tester.pump();
    expect(saved, isNull);
    expect(controller.state.review, isNotNull);
    expect(find.text('Playback could not stop. Try again.'), findsOneWidget);
    player.stopError = null;
    await tester.tap(find.text('Use recording'));
    await tester.pump();
    expect(saved?.temporaryKey, '/private/take.m4a');
  });

  testWidgets('system Back waits for both previews before delegating close', (
    tester,
  ) async {
    final bed = _ReviewSoundscape();
    player.stopping = Completer<void>();
    bed.stopping = Completer<void>();
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            reviewSoundscapePlayer: bed,
            handlesSystemBack: true,
            onBack: () => closed++,
            onContinue: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    expect(closed, 0);
    player.stopping!.complete();
    await tester.pump();
    expect(closed, 0);
    bed.stopping!.complete();
    await tester.pump();
    expect(closed, 1);
    expect(player.stopCalls, 1);
    expect(bed.stopCalls, 1);
    expect(controller.hasPendingRecording, isTrue);
  });

  testWidgets('system Back pauses the microphone before parent confirmation', (
    tester,
  ) async {
    AudioCapturePhase? phaseAtClose;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            reviewPlayer: player,
            handlesSystemBack: true,
            onBack: () => phaseAtClose = controller.state.phase,
            onContinue: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(phaseAtClose, AudioCapturePhase.paused);
    expect(controller.state.phase, AudioCapturePhase.paused);

    await _cancelCapture(tester, controller);
  });

  testWidgets(
    'discard confirmation pauses the microphone until explicit resume',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCapturePanel(
              controller: controller,
              reviewPlayer: player,
              onContinue: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start recording'));
      await tester.pump();
      await tester.ensureVisible(find.text('Discard'));
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(controller.state.phase, AudioCapturePhase.paused);
      await tester.tap(find.text('Keep recording'));
      await tester.pumpAndSettle();
      expect(controller.state.phase, AudioCapturePhase.paused);
      expect(find.text('Resume'), findsOneWidget);

      await _cancelCapture(tester, controller);
    },
  );
}

Future<void> _cancelCapture(
  WidgetTester tester,
  AudioCaptureController controller,
) async {
  // Cancel the test's active take and its fake timer here. The recorder and
  // its stream were created in setUp and are closed in the matching tearDown.
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    controller.cancel().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stackTrace) {
        failure = error;
        failureStack = stackTrace;
        completed = true;
      },
    ),
  );
  for (var frame = 0; frame < 20 && !completed; frame += 1) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(completed, isTrue, reason: 'Capture cancellation did not complete.');
  if (failure case final error?) {
    Error.throwWithStackTrace(error, failureStack!);
  }
  expect(controller.hasPendingRecording, isFalse);
  expect(controller.state.phase, AudioCapturePhase.explaining);
}

class _PanelRecorder implements AudioRecorderGateway {
  bool permissionGranted = true;
  int permissionRequests = 0;
  final amplitudesController = StreamController<double>.broadcast();

  @override
  Stream<double> get amplitudes => amplitudesController.stream;

  @override
  bool get canPause => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> discard(AudioRecorderResult result) async {}

  @override
  Future<void> dispose() => amplitudesController.close();

  @override
  Future<void> pause() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(TemporaryAudio temporary) async {}

  @override
  Future<AudioRecorderResult> stop() async => const AudioRecorderResult(
    locator: '/private/take.m4a',
    mimeType: 'audio/mp4',
  );
}

class _ReviewPlayer implements AudioPlayer {
  Completer<void>? stopping;
  Object? stopError;
  int stopCalls = 0;
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopping != null) await stopping!.future;
    if (stopError case final error?) throw error;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReviewSoundscape implements MemorySoundscapePlayer {
  Completer<void>? stopping;
  int stopCalls = 0;
  @override
  Future<void> start(
    MemorySoundscape soundscape, {
    required double volume,
  }) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopping != null) await stopping!.future;
  }

  @override
  Future<void> dispose() async {}
}
