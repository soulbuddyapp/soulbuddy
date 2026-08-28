import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/onboarding/data/powersync_first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/data/first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_choices.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test('cleanup ownership includes a staged remembrance recording', () async {
    final repository = _FakeFirstPrayerProgressRepository(
      const FirstPrayerProgress(
        remembranceAudioTemporaryKey: 'staged:audio-temp/retry.webm',
      ),
    );

    expect(await firstPrayerOwnedTemporaryAudioKeys(repository), {
      'staged:audio-temp/retry.webm',
    });
  });

  test('cleanup ownership is empty without a staged recording', () async {
    final repository = _FakeFirstPrayerProgressRepository(
      const FirstPrayerProgress(),
    );

    expect(await firstPrayerOwnedTemporaryAudioKeys(repository), isEmpty);
  });

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
        remembranceType: 'promise',
        remembranceByVoice: true,
        selectedPrayerRevisionId: 'revision-1',
        detailByVoice: true,
        remembranceText: 'God met me here.',
        remembranceAudioTemporaryKey: 'private/temp/take.m4a',
        remembranceAudioMimeType: 'audio/mp4',
        remembranceAudioDurationMs: 1200,
        remembranceAudioWaveform: [0.1, 0.4],
      ),
    );

    final restored = await repository.load();
    expect(restored?.stage, FirstPrayerStage.language);
    expect(restored?.answers.purpose, FirstPrayerPurpose.healing);
    expect(restored?.answers.frequency, FirstPrayerFrequency.daily);
    expect(restored?.answers.audience, FirstPrayerAudience.me);
    expect(restored?.remembranceType, 'promise');
    expect(restored?.remembranceByVoice, isTrue);
    expect(restored?.selectedPrayerRevisionId, 'revision-1');
    expect(restored?.detailByVoice, isTrue);
    expect(restored?.remembranceText, 'God met me here.');
    expect(restored?.remembranceAudioTemporaryKey, 'private/temp/take.m4a');
    expect(restored?.remembranceAudioMimeType, 'audio/mp4');
    expect(restored?.remembranceAudioDurationMs, 1200);
    expect(restored?.remembranceAudioWaveform, [0.1, 0.4]);
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

class _FakeFirstPrayerProgressRepository
    implements FirstPrayerProgressRepository {
  _FakeFirstPrayerProgressRepository(this.progress);

  final FirstPrayerProgress? progress;

  @override
  Future<FirstPrayerProgress?> load() async => progress;

  @override
  Future<void> clear() async {}

  @override
  Future<void> save(FirstPrayerProgress progress) async {}
}
