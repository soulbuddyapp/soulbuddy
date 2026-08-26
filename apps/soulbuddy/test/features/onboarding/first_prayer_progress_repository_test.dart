import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/onboarding/data/powersync_first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_choices.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-first-prayer-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('saves and restores guided answers and the current stage', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncFirstPrayerProgressRepository(
      database: database.powersync,
    );

    await repository.save(
      const FirstPrayerProgress(
        stage: FirstPrayerStage.language,
        answers: FirstPrayerAnswers(
          purpose: FirstPrayerPurpose.healing,
          frequency: FirstPrayerFrequency.daily,
          audience: FirstPrayerAudience.me,
        ),
      ),
    );

    final restored = await repository.load();
    expect(restored?.stage, FirstPrayerStage.language);
    expect(restored?.answers.purpose, FirstPrayerPurpose.healing);
    expect(restored?.answers.frequency, FirstPrayerFrequency.daily);
    expect(restored?.answers.audience, FirstPrayerAudience.me);
  });

  test('clear removes only the resumable first-prayer row', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncFirstPrayerProgressRepository(
      database: database.powersync,
    );
    await repository.save(const FirstPrayerProgress());

    await repository.clear();

    expect(await repository.load(), isNull);
  });
}
