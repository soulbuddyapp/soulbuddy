import 'package:powersync/powersync.dart';

import '../domain/first_prayer_choices.dart';
import '../domain/first_prayer_progress.dart';
import 'first_prayer_progress_repository.dart';

class PowerSyncFirstPrayerProgressRepository
    implements FirstPrayerProgressRepository {
  const PowerSyncFirstPrayerProgressRepository({required this.database});

  static const _rowId = 'current';

  final PowerSyncDatabase database;

  @override
  Future<FirstPrayerProgress?> load() async {
    final row = await database.getOptional(
      'SELECT * FROM first_prayer_progress WHERE id = ?',
      [_rowId],
    );
    if (row == null) return null;
    try {
      final stage = FirstPrayerStage.values.byName(row['stage'] as String);
      return FirstPrayerProgress(
        stage: stage,
        answers: FirstPrayerAnswers(
          purpose: FirstPrayerPurpose.tryFromWire(row['purpose'] as String?),
          frequency: FirstPrayerFrequency.tryFromWire(
            row['frequency'] as String?,
          ),
          audience: FirstPrayerAudience.tryFromWire(row['audience'] as String?),
          language: PrayerLanguagePreference.tryFromWire(
            row['language_preference'] as String?,
          ),
          detail: row['detail'] as String?,
        ),
        requestId: row['request_id'] as String?,
        selectedPrayerType: row['selected_prayer_type'] as String?,
        selectedPrayerId: row['selected_prayer_id'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(FirstPrayerProgress progress) async {
    await database.execute(
      '''
      INSERT OR REPLACE INTO first_prayer_progress(
        id, stage, purpose, frequency, audience, language_preference,
        detail, request_id, selected_prayer_type, selected_prayer_id, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _rowId,
        progress.stage.name,
        progress.answers.purpose?.wireValue,
        progress.answers.frequency?.wireValue,
        progress.answers.audience?.wireValue,
        progress.answers.language?.wireValue,
        progress.answers.detail,
        progress.requestId,
        progress.selectedPrayerType,
        progress.selectedPrayerId,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> clear() {
    return database.execute('DELETE FROM first_prayer_progress WHERE id = ?', [
      _rowId,
    ]);
  }
}
