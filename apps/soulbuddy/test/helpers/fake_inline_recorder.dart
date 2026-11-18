import 'dart:async';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';

class FakeInlineRecorder implements AudioRecorderGateway {
  bool started = false;
  @override
  Stream<double> get amplitudes => const Stream.empty();
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(TemporaryAudio temporary) async {
    started = true;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<AudioRecorderResult> stop() async =>
      const AudioRecorderResult(locator: '/take', mimeType: 'audio/mp4');
  @override
  Future<void> cancel() async {}
  @override
  Future<void> discard(AudioRecorderResult result) async {}
  @override
  Future<void> dispose() async {}
}
