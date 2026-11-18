import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'prayer_narration_playback_policy.dart';

class BundledPrayerAudioCatalog {
  BundledPrayerAudioCatalog._(this._entries);
  final Map<String, ({String path, String hash})> _entries;

  factory BundledPrayerAudioCatalog.fromJson(Map<dynamic, dynamic> data) {
    final raw = data['prayers'];
    if (raw is! List) {
      throw const FormatException('Invalid prayer audio catalog');
    }
    final entries = <String, ({String path, String hash})>{};
    for (final item in raw) {
      if (item is! Map) throw const FormatException('Invalid prayer audio');
      final id = item['id'];
      final file = item['file'];
      final hash = item['body_sha256'];
      if (id is! String ||
          id.isEmpty ||
          entries.containsKey(id) ||
          file is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]+\.mp3$').hasMatch(file) ||
          hash is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw const FormatException('Invalid prayer audio');
      }
      entries[id] = (path: 'audio/prayers/$file', hash: hash);
    }
    return BundledPrayerAudioCatalog._(entries);
  }
  static Future<BundledPrayerAudioCatalog> load() async =>
      BundledPrayerAudioCatalog.fromJson(
        jsonDecode(
              await rootBundle.loadString('assets/audio/prayers/manifest.json'),
            )
            as Map,
      );
  String? assetFor(String id, String body) {
    final entry = _entries[id];
    if (entry == null ||
        sha256.convert(utf8.encode(body)).toString() != entry.hash) {
      return null;
    }
    return entry.path;
  }
}

/// Called only after an explicit reminder open. iOS cannot report Focus or the
/// silent switch; its ambient audio session respects the silent switch instead.
bool allowBundledReminderAutoplay({
  required bool isIOS,
  required PrayerAudioRoute route,
  required bool interruptionsAllowed,
}) =>
    isIOS ||
    (interruptionsAllowed &&
        (route == PrayerAudioRoute.speaker ||
            route == PrayerAudioRoute.headphones));
