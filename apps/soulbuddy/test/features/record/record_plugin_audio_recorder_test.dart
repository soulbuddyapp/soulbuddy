import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:soulbuddy/features/record/audio/application/record_plugin_audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/application/record_plugin_driver.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';

void main() {
  test('maps the stable recording contract to record package codecs', () {
    expect(
      recordConfigFor(
        const SoulAudioRecordingConfig(
          codec: SoulAudioCodec.aacLc,
          sampleRate: 44100,
          bitRate: 64000,
          channels: 1,
        ),
      ).encoder,
      AudioEncoder.aacLc,
    );
    final wav = recordConfigFor(
      const SoulAudioRecordingConfig(
        codec: SoulAudioCodec.wavPcm16,
        sampleRate: 24000,
        bitRate: 384000,
        channels: 1,
      ),
    );
    expect(wav.encoder, AudioEncoder.wav);
    expect(wav.sampleRate, 24000);
    expect(wav.numChannels, 1);
  });

  test('selects private mobile AAC and reports the actual MIME type', () async {
    final driver = _FakeRecordPluginDriver(supported: {SoulAudioCodec.aacLc});
    final recorder = RecordPluginAudioRecorder(
      driver: driver,
      isWeb: false,
      discardLocator: (_) async {},
    );

    await recorder.start(
      const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );
    driver.configChanged?.call(
      const SoulAudioRecordingConfig(
        codec: SoulAudioCodec.aacLc,
        sampleRate: 44100,
        bitRate: 64000,
        channels: 1,
      ),
    );
    final result = await recorder.stop();

    expect(driver.startedConfig!.codec, SoulAudioCodec.aacLc);
    expect(driver.startedConfig!.sampleRate, 44100);
    expect(driver.startedConfig!.bitRate, 64000);
    expect(driver.startedConfig!.channels, 1);
    expect(driver.startedPath, '/private/take.m4a');
    expect(result.locator, '/private/take.m4a');
    expect(result.mimeType, 'audio/mp4');
  });

  test('web probes Opus then AAC then bounded mono WAV fallback', () async {
    final opus = _FakeRecordPluginDriver(supported: {SoulAudioCodec.opus});
    final opusRecorder = RecordPluginAudioRecorder(
      driver: opus,
      isWeb: true,
      discardLocator: (_) async {},
    );
    await opusRecorder.start(const TemporaryAudio(key: 'take', locator: ''));
    expect(opus.startedConfig!.codec, SoulAudioCodec.opus);
    expect(opus.probes, [SoulAudioCodec.opus]);
    expect(opus.startedPath, '');

    final wav = _FakeRecordPluginDriver(supported: {SoulAudioCodec.wavPcm16});
    final wavRecorder = RecordPluginAudioRecorder(
      driver: wav,
      isWeb: true,
      discardLocator: (_) async {},
    );
    await wavRecorder.start(const TemporaryAudio(key: 'take', locator: ''));
    expect(wav.probes, [
      SoulAudioCodec.opus,
      SoulAudioCodec.aacLc,
      SoulAudioCodec.wavPcm16,
    ]);
    expect(wav.startedConfig!.sampleRate, 24000);
    expect(wav.startedConfig!.channels, 1);
    expect(wav.startedConfig!.bitRate, 384000);
  });

  test('serializes overlapping plugin commands', () async {
    final driver = _FakeRecordPluginDriver(supported: {SoulAudioCodec.aacLc})
      ..startGate = Completer<void>();
    final recorder = RecordPluginAudioRecorder(
      driver: driver,
      isWeb: false,
      discardLocator: (_) async {},
    );

    final start = recorder.start(
      const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );
    final pause = recorder.pause();
    await Future<void>.delayed(Duration.zero);

    expect(driver.events, ['start']);
    driver.startGate!.complete();
    await Future.wait([start, pause]);
    expect(driver.events, ['start', 'pause']);
  });

  test('failed native disposal is retryable without allowing new capture', () async {
    final driver = _FakeRecordPluginDriver(supported: {SoulAudioCodec.aacLc})
      ..disposeError = StateError('native disposal failed');
    final recorder = RecordPluginAudioRecorder(
      driver: driver,
      isWeb: false,
      discardLocator: (_) async {},
    );
    await recorder.start(
      const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
    );

    await expectLater(recorder.dispose(), throwsStateError);
    expect(driver.events, ['start', 'dispose']);
    expect(driver.configChanged, isNull);
    await expectLater(
      recorder.start(
        const TemporaryAudio(key: 'take-2', locator: '/private/take-2.m4a'),
      ),
      throwsStateError,
    );

    await recorder.cancel();
    driver.disposeError = null;
    await recorder.dispose();
    await recorder.dispose();

    expect(driver.events, ['start', 'dispose', 'cancel', 'dispose']);
  });

  test('normalizes dBFS amplitude and never emits invalid samples', () async {
    final driver = _FakeRecordPluginDriver(supported: {SoulAudioCodec.aacLc});
    final recorder = RecordPluginAudioRecorder(
      driver: driver,
      isWeb: false,
      discardLocator: (_) async {},
    );
    final values = <double>[];
    final subscription = recorder.amplitudes.listen(values.add);

    driver.amplitudeController
      ..add(0)
      ..add(-20)
      ..add(double.nan)
      ..add(12);
    await Future<void>.delayed(Duration.zero);

    expect(values[0], 1);
    expect(values[1], closeTo(math.pow(10, -1), 0.00001));
    expect(values[2], 0);
    expect(values[3], 1);
    await subscription.cancel();
  });

  test('discard releases the exact stopped locator', () async {
    final released = <String>[];
    final driver = _FakeRecordPluginDriver(supported: {SoulAudioCodec.opus})
      ..stopLocator = 'blob:take';
    final recorder = RecordPluginAudioRecorder(
      driver: driver,
      isWeb: true,
      discardLocator: (locator) async => released.add(locator),
    );
    await recorder.start(const TemporaryAudio(key: 'take', locator: ''));
    final result = await recorder.stop();

    await recorder.discard(result);

    expect(released, ['blob:take']);
  });
}

class _FakeRecordPluginDriver implements RecordPluginDriver {
  _FakeRecordPluginDriver({required this.supported});

  final Set<SoulAudioCodec> supported;
  final probes = <SoulAudioCodec>[];
  final events = <String>[];
  final amplitudeController = StreamController<double>.broadcast();
  Completer<void>? startGate;
  Object? disposeError;
  SoulAudioRecordingConfig? startedConfig;
  String? startedPath;
  String? stopLocator;
  void Function(SoulAudioRecordingConfig config)? configChanged;

  @override
  Stream<double> amplitudeChanged(Duration interval) =>
      amplitudeController.stream;

  @override
  bool get canPause => true;

  @override
  Future<void> cancel() async => events.add('cancel');

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (disposeError case final error?) throw error;
    await amplitudeController.close();
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isEncoderSupported(SoulAudioCodec codec) async {
    probes.add(codec);
    return supported.contains(codec);
  }

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> resume() async => events.add('resume');

  @override
  void setOnConfigChanged(
    void Function(SoulAudioRecordingConfig config)? callback,
  ) {
    configChanged = callback;
  }

  @override
  Future<void> start(SoulAudioRecordingConfig config, String path) async {
    events.add('start');
    startedConfig = config;
    startedPath = path;
    await startGate?.future;
  }

  @override
  Future<String?> stop() async {
    events.add('stop');
    return stopLocator ?? startedPath;
  }
}
