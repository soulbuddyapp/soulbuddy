import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';

void main() {
  late Map<String, String> storage;
  late OrientationProgressRepository repository;
  setUp(() {
    storage = {};
    repository = OrientationProgressRepository(
      read: (key) async => storage[key],
      write: (key, value) async {
        storage[key] = value;
      },
    );
  });

  test(
    'saves independent course positions, completion and preferences',
    () async {
      await repository.save(
        'a',
        const OrientationProgress(
          position: Duration(seconds: 8),
          completed: true,
        ),
      );
      await repository.save(
        'b',
        const OrientationProgress(position: Duration(seconds: 2)),
      );
      await repository.savePreferences(
        const OrientationPreferences(speed: .85, textScale: 1.4),
      );
      expect((await repository.load('a')).completed, true);
      expect((await repository.load('b')).position.inSeconds, 2);
      expect((await repository.loadPreferences()).speed, .85);
      expect((await repository.loadPreferences()).textScale, 1.4);
    },
  );

  test('missing and malformed records safely fall back', () async {
    expect((await repository.loadPreferences()).speed, .85);
    expect((await repository.load('a')).position, Duration.zero);
    await repository.save('a', const OrientationProgress());
    storage.updateAll((_, __) => '{broken');
    expect((await repository.load('a')).completed, false);
    await repository.savePreferences(const OrientationPreferences());
    final key = storage.keys.last;
    storage[key] = jsonEncode({'speed': 3, 'textScale': -1});
    expect((await repository.loadPreferences()).speed, .85);
    expect((await repository.loadPreferences()).textScale, 1);
    storage.updateAll(
      (_, __) => jsonEncode({'positionMs': -50, 'completed': 'yes'}),
    );
    expect((await repository.load('a')).position, Duration.zero);
  });

  test('invalid preferences cannot be persisted', () async {
    await repository.savePreferences(
      OrientationPreferences(speed: double.nan, textScale: double.infinity),
    );
    final preferences = await repository.loadPreferences();
    expect(preferences.speed, .85);
    expect(preferences.textScale, 1);
  });
}
