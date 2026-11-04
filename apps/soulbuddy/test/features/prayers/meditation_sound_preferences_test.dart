import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';

void main() {
  test(
    'sound and volume survive reopening; silence replaces a previous choice',
    () async {
      final storage = <String, String>{};
      MeditationSoundPreferencesRepository repository() =>
          MeditationSoundPreferencesRepository(
            read: (key) async => storage[key],
            write: (key, value) async {
              storage[key] = value;
            },
          );
      await repository().save(
        const MeditationSoundPreferences(
          sound: MeditationSoundBed.warmStrings,
          volume: .1,
        ),
      );
      final restored = await repository().load();
      expect(restored.sound, MeditationSoundBed.warmStrings);
      expect(restored.volume, .1);
      await repository().save(const MeditationSoundPreferences());
      expect((await repository().load()).sound, isNull);
    },
  );

  test('rapid selections persist in order even when storage is slow', () async {
    final gate = Completer<void>();
    String? saved;
    var writes = 0;
    final repository = MeditationSoundPreferencesRepository(
      read: (_) async => saved,
      write: (_, value) async {
        if (++writes == 1) await gate.future;
        saved = value;
      },
    );
    final first = repository.save(
      const MeditationSoundPreferences(sound: MeditationSoundBed.stillness),
    );
    final last = repository.save(
      const MeditationSoundPreferences(sound: MeditationSoundBed.hopefulPiano),
    );
    gate.complete();
    await Future.wait([first, last]);
    expect((await repository.load()).sound, MeditationSoundBed.hopefulPiano);
  });

  test('invalid saved preferences fall back to silence', () async {
    for (final raw in ['bad json', '{"sound":"removed","volume":80}', '[]']) {
      final repository = MeditationSoundPreferencesRepository(
        read: (_) async => raw,
        write: (_, _) async {},
      );
      final result = await repository.load();
      expect(result.sound, isNull);
      expect(result.volume, inInclusiveRange(.05, .3));
    }
  });

  test('nothing is chosen until it is', () {
    const preferences = MeditationSoundPreferences();
    expect(preferences.sound, isNull);
    expect(preferences.worship, isNull);
    expect(preferences.volume, .15);
  });

  test('a worship choice survives a round trip in its own slot', () async {
    final storage = <String, String>{};
    final repository = MeditationSoundPreferencesRepository(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
    );

    await repository.save(
      const MeditationSoundPreferences(
        sound: MeditationSoundBed.flowingWater,
        volume: .18,
        worship: WorshipSoundPreference(
          sound: WorshipSoundBed.animaChristi,
          volume: .1,
        ),
      ),
    );

    final loaded = await repository.load();
    expect(loaded.sound, MeditationSoundBed.flowingWater);
    expect(loaded.volume, .18);
    expect(loaded.worship?.sound, WorshipSoundBed.animaChristi);
    expect(loaded.worship?.volume, .1);
  });

  test('a worship choice never lands in the ambient slot', () async {
    final storage = <String, String>{};
    final repository = MeditationSoundPreferencesRepository(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
    );

    await repository.save(
      const MeditationSoundPreferences(
        worship: WorshipSoundPreference(
          sound: WorshipSoundBed.tenThousandReasons,
          volume: .2,
        ),
      ),
    );

    // The shared slot has no bed and no level, so a surface that reads it
    // finds silence and can never be handed a worship asset.
    final loaded = await repository.load();
    expect(loaded.sound, isNull);
    expect(loaded.worship?.sound, WorshipSoundBed.tenThousandReasons);
  });

  test('worship values that cannot be read fall back to silence', () async {
    for (final raw in [
      '{"worship":{"sound":"beStillMySoul","volume":0.2}}',
      '{"worship":[]}',
      '{"worship":"tenThousandReasons"}',
    ]) {
      final repository = MeditationSoundPreferencesRepository(
        read: (_) async => raw,
        write: (_, _) async {},
      );
      expect((await repository.load()).worship, isNull, reason: raw);
    }
  });

  test('a worship level is clamped and defaulted like any other', () async {
    final repository = MeditationSoundPreferencesRepository(
      read: (_) async =>
          '{"worship":{"sound":"tenThousandReasons","volume":9}}',
      write: (_, _) async {},
    );
    expect((await repository.load()).worship?.volume, .3);

    final without = MeditationSoundPreferencesRepository(
      read: (_) async => '{"worship":{"sound":"tenThousandReasons"}}',
      write: (_, _) async {},
    );
    expect(
      (await without.load()).worship?.volume,
      WorshipSoundBed.tenThousandReasons.preferredVolume,
    );
  });
}
