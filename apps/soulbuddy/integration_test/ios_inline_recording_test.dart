import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/presentation/inline_audio_capture.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inline recording can start, stop and save on iOS', (
    tester,
  ) async {
    final recorder = _Recorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'ios-test', locator: 'ios-test'),
    );
    var saved = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: InlineAudioCapture(
                onSave: (_) async {
                  saved = true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.starts, 1);
    expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(saved, isTrue);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });
}

class _Recorder implements AudioRecorderGateway {
  int starts = 0;
  @override
  Stream<double> get amplitudes => const Stream.empty();
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(TemporaryAudio temporary) async {
    starts++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<AudioRecorderResult> stop() async =>
      const AudioRecorderResult(locator: 'ios-test', mimeType: 'audio/mp4');
  @override
  Future<void> cancel() async {}
  @override
  Future<void> discard(AudioRecorderResult result) async {}
  @override
  Future<void> dispose() async {}
}
