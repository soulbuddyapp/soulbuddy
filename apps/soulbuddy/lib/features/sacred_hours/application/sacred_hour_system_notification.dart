import 'package:flutter/services.dart';

class SacredHourSystemNotification {
  SacredHourSystemNotification._();

  static const _channel = MethodChannel(
    'app.soulbuddy/sacred_hour_notification',
  );

  static Future<void> start({
    required String title,
    required DateTime startedAt,
    required Duration duration,
    required String route,
  }) => _invoke('start', {
    'title': title,
    'startedAtMillis': startedAt.millisecondsSinceEpoch,
    'durationMillis': duration.inMilliseconds,
    'route': route,
  });

  static Future<void> setPaused(bool paused) =>
      _invoke(paused ? 'pause' : 'resume');

  static Future<void> stop() => _invoke('stop');

  static Future<void> _invoke(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // The practice remains available when Android notifications are disabled.
    } on MissingPluginException {
      // Other platforms do not provide the Android service.
    }
  }
}
