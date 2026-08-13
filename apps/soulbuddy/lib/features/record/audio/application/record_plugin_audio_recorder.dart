import 'dart:async';
import 'dart:math' as math;

import '../data/audio_asset_store.dart';
import 'audio_recorder.dart';

enum SoulAudioCodec { aacLc, opus, wavPcm16 }

class SoulAudioRecordingConfig {
  const SoulAudioRecordingConfig({
    required this.codec,
    required this.sampleRate,
    required this.bitRate,
    required this.channels,
  });

  final SoulAudioCodec codec;
  final int sampleRate;
  final int bitRate;
  final int channels;
}

abstract interface class RecordPluginDriver {
  Stream<double> amplitudeChanged(Duration interval);
  bool get canPause;
  Future<bool> hasPermission();
  Future<bool> isEncoderSupported(SoulAudioCodec codec);
  void setOnConfigChanged(
    void Function(SoulAudioRecordingConfig config)? callback,
  );
  Future<void> start(SoulAudioRecordingConfig config, String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordPluginAudioRecorder implements AudioRecorderGateway {
  RecordPluginAudioRecorder({
    required RecordPluginDriver driver,
    required bool isWeb,
    required Future<void> Function(String locator) discardLocator,
  }) : _driver = driver,
       _isWeb = isWeb,
       _discardLocator = discardLocator {
    _driver.setOnConfigChanged(_onConfigChanged);
    _amplitudes = _driver
        .amplitudeChanged(const Duration(milliseconds: 120))
        .map(_normalizeAmplitude)
        .asBroadcastStream();
  }

  final RecordPluginDriver _driver;
  final bool _isWeb;
  final Future<void> Function(String locator) _discardLocator;
  late final Stream<double> _amplitudes;
  Future<void> _commandTail = Future.value();
  SoulAudioRecordingConfig? _actualConfig;
  String? _startedLocator;
  bool _disposed = false;

  @override
  Stream<double> get amplitudes => _amplitudes;

  @override
  bool get canPause => _driver.canPause;

  @override
  Future<bool> requestPermission() => _serialize(_driver.hasPermission);

  @override
  Future<void> start(TemporaryAudio temporary) => _serialize(() async {
    _requireActive();
    final config = await _selectConfig();
    _actualConfig = config;
    _startedLocator = temporary.locator;
    await _driver.start(config, _isWeb ? '' : temporary.locator);
  });

  @override
  Future<void> pause() => _serialize(() async {
    _requireActive();
    await _driver.pause();
  });

  @override
  Future<void> resume() => _serialize(() async {
    _requireActive();
    await _driver.resume();
  });

  @override
  Future<AudioRecorderResult> stop() => _serialize(() async {
    _requireActive();
    final locator = await _driver.stop() ?? _startedLocator;
    final config = _actualConfig;
    if (locator == null || locator.isEmpty || config == null) {
      throw StateError('The recording did not produce a private audio take.');
    }
    return AudioRecorderResult(
      locator: locator,
      mimeType: _mimeType(config.codec),
    );
  });

  @override
  Future<void> cancel() => _serialize(() async {
    if (_disposed) return;
    await _driver.cancel();
  });

  @override
  Future<void> discard(AudioRecorderResult result) =>
      _serialize(() => _discardLocator(result.locator));

  @override
  Future<void> dispose() => _serialize(() async {
    if (_disposed) return;
    _disposed = true;
    _driver.setOnConfigChanged(null);
    await _driver.dispose();
  });

  Future<SoulAudioRecordingConfig> _selectConfig() async {
    if (!_isWeb) {
      if (!await _driver.isEncoderSupported(SoulAudioCodec.aacLc)) {
        throw StateError('Private audio recording is unavailable.');
      }
      return _aacConfig;
    }
    for (final candidate in const [
      SoulAudioCodec.opus,
      SoulAudioCodec.aacLc,
      SoulAudioCodec.wavPcm16,
    ]) {
      if (await _driver.isEncoderSupported(candidate)) {
        return switch (candidate) {
          SoulAudioCodec.opus => _opusConfig,
          SoulAudioCodec.aacLc => _aacConfig,
          SoulAudioCodec.wavPcm16 => _wavConfig,
        };
      }
    }
    throw StateError('Private audio recording is unavailable.');
  }

  void _onConfigChanged(SoulAudioRecordingConfig config) {
    _actualConfig = config;
  }

  Future<T> _serialize<T>(Future<T> Function() command) {
    final result = Completer<T>();
    _commandTail = _commandTail.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await command());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  void _requireActive() {
    if (_disposed) throw StateError('The audio recorder is closed.');
  }
}

const _aacConfig = SoulAudioRecordingConfig(
  codec: SoulAudioCodec.aacLc,
  sampleRate: 44100,
  bitRate: 64000,
  channels: 1,
);

const _opusConfig = SoulAudioRecordingConfig(
  codec: SoulAudioCodec.opus,
  sampleRate: 48000,
  bitRate: 64000,
  channels: 1,
);

const _wavConfig = SoulAudioRecordingConfig(
  codec: SoulAudioCodec.wavPcm16,
  sampleRate: 24000,
  bitRate: 384000,
  channels: 1,
);

double _normalizeAmplitude(double db) {
  if (!db.isFinite) return 0;
  return math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
}

String _mimeType(SoulAudioCodec codec) => switch (codec) {
  SoulAudioCodec.aacLc => 'audio/mp4',
  SoulAudioCodec.opus => 'audio/webm',
  SoulAudioCodec.wavPcm16 => 'audio/wav',
};
