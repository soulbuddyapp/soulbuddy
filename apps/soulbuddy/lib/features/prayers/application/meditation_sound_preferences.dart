import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../domain/meditation_session.dart';
import '../domain/worship_sound_bed.dart';

/// A worship bed and the level it was chosen at.
class WorshipSoundPreference {
  const WorshipSoundPreference({required this.sound, this.volume = .20});

  final WorshipSoundBed sound;
  final double volume;
}

class MeditationSoundPreferences {
  const MeditationSoundPreferences({
    this.sound,
    this.volume = .15,
    this.worship,
  });

  /// The bed the seven shared surfaces offer.
  final MeditationSoundBed? sound;

  /// That bed's level.
  final double volume;

  /// A worship bed chosen in the Prayer of attention, held separately from
  /// [sound] so that it can never be handed to a shared surface, which would
  /// then look for an asset path that only exists for this one practice.
  final WorshipSoundPreference? worship;
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
        worship: _worship(value['worship']),
      );
    } on FormatException {
      return const MeditationSoundPreferences();
    }
  }

  /// Reads the worship slot. An unreadable or unknown value is simply absent,
  /// which is the same as never having chosen one.
  static WorshipSoundPreference? _worship(Object? raw) {
    if (raw is! Map) return null;
    final matches = WorshipSoundBed.values.where(
      (bed) => bed.name == raw['sound'],
    );
    final bed = matches.firstOrNull;
    if (bed == null) return null;
    final volume = raw['volume'];
    return WorshipSoundPreference(
      sound: bed,
      volume: volume is num && volume.isFinite
          ? volume.toDouble().clamp(.05, .3)
          : bed.preferredVolume,
    );
  }

  Future<void> save(MeditationSoundPreferences value) {
    final worship = value.worship;
    final encoded = jsonEncode({
      'sound': value.sound?.name,
      'volume': value.volume,
      'worship': worship == null
          ? null
          : {'sound': worship.sound.name, 'volume': worship.volume},
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
