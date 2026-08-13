import '../data/audio_asset_store.dart';

class AudioRecorderResult {
  const AudioRecorderResult({required this.locator, required this.mimeType});

  final String locator;
  final String mimeType;
}

abstract interface class AudioRecorderGateway {
  Stream<double> get amplitudes;
  bool get canPause;

  Future<bool> requestPermission();
  Future<void> start(TemporaryAudio temporary);
  Future<void> pause();
  Future<void> resume();
  Future<AudioRecorderResult> stop();
  Future<void> cancel();
  Future<void> discard(AudioRecorderResult result);
  Future<void> dispose();
}

abstract interface class AudioElapsedClock {
  Duration get elapsed;
  void start();
  void stop();
  void reset();
}

class StopwatchAudioElapsedClock implements AudioElapsedClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void reset() => _stopwatch.reset();

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();
}

abstract interface class AudioCaptureTicker {
  void cancel();
}

typedef AudioCaptureTickerFactory =
    AudioCaptureTicker Function(Duration interval, void Function() callback);
