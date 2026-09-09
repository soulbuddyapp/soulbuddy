import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../domain/meditation_session.dart';

class MeditationSoundPreferences {
  const MeditationSoundPreferences({this.sound, this.volume = .15});
  final MeditationSoundBed? sound;
  final double volume;
}

/// Shared by reflection readings and voice meditation, persisted on this device.
class MeditationSoundPreferencesRepository {
  MeditationSoundPreferencesRepository({
    required this.read,
    required this.write,
  });
  static const storageKey = 'meditation.background_sound.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  Future<void> _pending = Future.value();

  Future<MeditationSoundPreferences> load() async {
    await _pending;
    final raw = await read(storageKey);
    if (raw == null) return const MeditationSoundPreferences();
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return const MeditationSoundPreferences();
      final matches = MeditationSoundBed.values.where(
        (sound) => sound.name == value['sound'],
      );
      final sound = matches.firstOrNull;
      final volume = value['volume'];
      return MeditationSoundPreferences(
        sound: sound,
        volume: volume is num && volume.isFinite
            ? volume.toDouble().clamp(.05, .3)
            : sound?.preferredVolume ?? .15,
      );
    } on FormatException {
      return const MeditationSoundPreferences();
    }
  }

  Future<void> save(MeditationSoundPreferences value) {
    final encoded = jsonEncode({
      'sound': value.sound?.name,
      'volume': value.volume,
    });
    final saving = _pending.then((_) => write(storageKey, encoded));
    // A failed write must not prevent later choices from being saved.
    _pending = saving.catchError((Object _) {});
    return saving;
  }
}

final meditationSoundPreferencesProvider =
    Provider<MeditationSoundPreferencesRepository>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return MeditationSoundPreferencesRepository(
        read: (key) => storage.read(key: key),
        write: (key, value) => storage.write(key: key, value: value),
      );
    });
