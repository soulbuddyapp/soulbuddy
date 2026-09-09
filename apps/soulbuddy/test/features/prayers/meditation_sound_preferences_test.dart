import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_preferences.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';

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
}
