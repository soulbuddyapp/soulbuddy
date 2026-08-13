import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/presentation/audio_capture_panel.dart';

void main() {
  late _PanelRecorder recorder;
  late AudioCaptureController controller;

  setUp(() {
    recorder = _PanelRecorder();
    controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );
  });

  tearDown(() => controller.close());

  testWidgets('explains speaking and keeps Write an equal available path', (
    tester,
  ) async {
    var writeSelected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            onWriteInstead: () => writeSelected = true,
            onContinue: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Speak what you do not want to forget.'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Write instead'), findsOneWidget);
    expect(find.bySemanticsLabel('Start audio recording'), findsOneWidget);
    expect(tester.getSize(find.text('Start recording')).height, greaterThan(0));

    await tester.tap(find.text('Write instead'));
    expect(writeSelected, isTrue);
  });

  testWidgets('permission denial stays calm and preserves Write instead', (
    tester,
  ) async {
    recorder.permissionGranted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
            onWriteInstead: () {},
            onContinue: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start recording'));
    await tester.pump();

    expect(find.text('Microphone access was not granted.'), findsOneWidget);
    expect(find.text('Write instead'), findsOneWidget);
    expect(find.text('Try microphone again'), findsOneWidget);
  });

  testWidgets('recording controls are truthful and Continue returns the take', (
    tester,
  ) async {
    MemoryAudioDraft? continued;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioCapturePanel(
            controller: controller,
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
    expect(find.bySemanticsLabel('Stop and review recording'), findsOneWidget);
    expect(find.bySemanticsLabel('Discard this recording'), findsOneWidget);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.bySemanticsLabel('Resume recording'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Review your recording'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Record again'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(continued, isNotNull);
    expect(continued!.temporaryKey, '/private/take.m4a');
  });

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
              onWriteInstead: () {},
              onContinue: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Start recording'), findsOneWidget);
      expect(find.text('Write instead'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PanelRecorder implements AudioRecorderGateway {
  bool permissionGranted = true;
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
  Future<bool> requestPermission() async => permissionGranted;

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
