import 'dart:convert';

class OrientationProgress {
  const OrientationProgress({
    this.position = Duration.zero,
    this.completed = false,
  });

  final Duration position;
  final bool completed;
}

class OrientationPreferences {
  const OrientationPreferences({this.speed = 1, this.textScale = 1});

  static const speeds = <double>[.5, .75, .85, 1, 1.25, 1.5];
  final double speed;
  final double textScale;

  static double validSpeed(double value) =>
      value.isFinite && speeds.contains(value) ? value : 1;

  static double validTextScale(double value) =>
      value.isFinite && value >= .85 && value <= 1.6 ? value : 1;
}

/// Device-local, versioned records. I/O failures are surfaced to the controller;
/// malformed stored data is treated as a fresh record.
class OrientationProgressRepository {
  OrientationProgressRepository({
    required Future<String?> Function(String) read,
    required Future<void> Function(String, String) write,
  }) : _read = read,
       _write = write;

  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  Future<void> _writes = Future.value();

  String _key(String courseId) => 'orientation.progress.v1.$courseId';
  static const _preferencesKey = 'orientation.preferences.v1';

  Future<OrientationProgress> load(String courseId) async {
    final json = _decode(await _read(_key(courseId)));
    final position = json?['positionMs'];
    return OrientationProgress(
      position: position is int && position >= 0 && position <= 86400000
          ? Duration(milliseconds: position)
          : Duration.zero,
      completed: json?['completed'] == true,
    );
  }

  Future<void> save(String courseId, OrientationProgress progress) => _enqueue(
    _key(courseId),
    jsonEncode({
      'positionMs': progress.position.inMilliseconds.clamp(0, 86400000),
      'completed': progress.completed,
    }),
  );

  Future<OrientationPreferences> loadPreferences() async {
    final json = _decode(await _read(_preferencesKey));
    return OrientationPreferences(
      speed: OrientationPreferences.validSpeed(_number(json?['speed'])),
      textScale: OrientationPreferences.validTextScale(
        _number(json?['textScale']),
      ),
    );
  }

  Future<void> savePreferences(OrientationPreferences preferences) => _enqueue(
    _preferencesKey,
    jsonEncode({
      'speed': OrientationPreferences.validSpeed(preferences.speed),
      'textScale': OrientationPreferences.validTextScale(preferences.textScale),
    }),
  );

  Future<void> _enqueue(String key, String value) {
    final write = _writes.then((_) => _write(key, value));
    // Keep subsequent writes usable even when an earlier storage write fails.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : 1;

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
