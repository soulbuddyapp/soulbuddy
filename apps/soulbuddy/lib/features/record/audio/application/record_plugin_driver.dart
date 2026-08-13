import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../data/audio_asset_store.dart';
import 'audio_recorder.dart';
import 'record_plugin_audio_recorder.dart';

class RecordPackageDriver implements RecordPluginDriver {
  RecordPackageDriver({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  void Function(SoulAudioRecordingConfig config)? _configChanged;

  @override
  Stream<double> amplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval).map((value) => value.current);

  @override
  bool get canPause => true;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> isEncoderSupported(SoulAudioCodec codec) =>
      _recorder.isEncoderSupported(_encoderFor(codec));

  @override
  void setOnConfigChanged(
    void Function(SoulAudioRecordingConfig config)? callback,
  ) {
    _configChanged = callback;
  }

  @override
  Future<void> start(SoulAudioRecordingConfig config, String path) async {
    await _recorder.start(recordConfigFor(config), path: path);
    // record 6.2.1 is the newest release compatible with Dart 3.9 and does not
    // expose 7.x's effective-config callback. Encoder support is probed before
    // this call, so the accepted requested configuration is authoritative.
    _configChanged?.call(config);
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

RecordConfig recordConfigFor(SoulAudioRecordingConfig config) => RecordConfig(
  encoder: _encoderFor(config.codec),
  sampleRate: config.sampleRate,
  bitRate: config.bitRate,
  numChannels: config.channels,
  audioInterruption: AudioInterruptionMode.pause,
);

AudioEncoder _encoderFor(SoulAudioCodec codec) => switch (codec) {
  SoulAudioCodec.aacLc => AudioEncoder.aacLc,
  SoulAudioCodec.opus => AudioEncoder.opus,
  SoulAudioCodec.wavPcm16 => AudioEncoder.wav,
};

AudioRecorderGateway createRecordPluginAudioRecorder(
  AudioAssetStore assetStore,
) => RecordPluginAudioRecorder(
  driver: RecordPackageDriver(),
  isWeb: kIsWeb,
  discardLocator: assetStore.discardTemporary,
);
