import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/data/daily_formation_repository.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_progress.dart';

void main() {
  test('keeps a selected option and advances only after completion', () async {
    String? stored;
    final repository = DailyFormationRepository(
      read: (_) async => stored,
      write: (_, value) async => stored = value,
    );

    await repository.select(day: 1, videoId: 'V002');
    expect((await repository.load()).selectedVideoId, 'V002');
    expect((await repository.load()).currentDay, 1);

    await repository.complete(
      FormationCompletion(
        day: 1,
        videoId: 'V002',
        completedAt: DateTime.utc(2026, 9, 16),
        reflection: 'I will make room to listen.',
        reflectionEncounterId: 'recording-after-v002',
        action: 'Pray before my first decision.',
      ),
    );

    final progress = await repository.load();
    expect(progress.currentDay, 2);
    expect(progress.selectedVideoId, isNull);
    expect(progress.completions.single.videoId, 'V002');
    expect(
      progress.completions.single.reflectionEncounterId,
      'recording-after-v002',
    );
    expect(
      progress.completions.single.reflection,
      'I will make room to listen.',
    );
    expect(jsonDecode(stored!)['completions'], hasLength(1));
  });

  test(
    'does not add a duplicate completion when a completed day is retried',
    () async {
      String? stored;
      final repository = DailyFormationRepository(
        read: (_) async => stored,
        write: (_, value) async => stored = value,
      );
      final completion = FormationCompletion(
        day: 1,
        videoId: 'V001',
        completedAt: DateTime.utc(2026, 9, 16),
      );

      await repository.complete(completion);
      await repository.complete(completion);

      final progress = await repository.load();
      expect(progress.currentDay, 2);
      expect(progress.completions, hasLength(1));
      expect(progress.completions.single.reflectionEncounterId, isNull);
    },
  );
  test('does not overwrite progress when reading it fails', () async {
    var wrote = false;
    final repository = DailyFormationRepository(
      read: (_) async => throw StateError('storage unavailable'),
      write: (_, _) async {
        wrote = true;
      },
    );
    await expectLater(
      repository.complete(
        FormationCompletion(
          day: 1,
          videoId: 'V1',
          completedAt: DateTime.utc(2026),
        ),
      ),
      throwsStateError,
    );
    expect(wrote, isFalse);
  });
}
