import 'dart:convert';

import '../domain/memory_soundscape.dart';

class MemorySoundscapePreferences {
  MemorySoundscapePreferences({
    required Future<String?> Function(String) read,
    required Future<void> Function(String, String) write,
  }) : _read = read,
       _write = write;

  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  Future<void> _writes = Future.value();

  String _key(String assetId) =>
      'memory.soundscape.v1.${Uri.encodeComponent(assetId)}';

  Future<MemorySoundscapeSettings> load(String assetId) async {
    try {
      final raw = await _read(_key(assetId));
      if (raw == null) return MemorySoundscapeSettings.defaults;
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) {
        return MemorySoundscapeSettings.defaults;
      }
      final soundscape = MemorySoundscape.values
          .where((item) => item.name == value['soundscape'])
          .firstOrNull;
      final volume = value['volume'];
      return MemorySoundscapeSettings(
        soundscape: soundscape ?? MemorySoundscape.quiet,
        volume: volume is num ? volume.toDouble() : 0.15,
      ).validated;
    } on Object {
      return MemorySoundscapeSettings.defaults;
    }
  }

  Future<void> save(String assetId, MemorySoundscapeSettings settings) {
    final valid = settings.validated;
    final write = _writes.then(
      (_) => _write(
        _key(assetId),
        jsonEncode({
          'soundscape': valid.soundscape.name,
          'volume': valid.volume,
        }),
      ),
    );
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
