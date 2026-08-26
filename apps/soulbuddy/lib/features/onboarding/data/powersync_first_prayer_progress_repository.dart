import 'dart:convert';

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
        selectedPrayerRevisionId: row['selected_prayer_revision_id'] as String?,
        detailByVoice: _nullableBool(row['detail_by_voice']),
        remembranceType: row['remembrance_type'] as String?,
        remembranceByVoice: _nullableBool(row['remembrance_by_voice']),
        remembranceText: row['remembrance_text'] as String?,
        remembranceAudioTemporaryKey:
            row['remembrance_audio_temporary_key'] as String?,
        remembranceAudioMimeType: row['remembrance_audio_mime_type'] as String?,
        remembranceAudioDurationMs:
            row['remembrance_audio_duration_ms'] as int?,
        remembranceAudioWaveform: _waveform(
          row['remembrance_audio_waveform_json'] as String?,
        ),
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
        detail, request_id, selected_prayer_type, selected_prayer_id,
        selected_prayer_revision_id, detail_by_voice, remembrance_type,
        remembrance_by_voice, remembrance_text,
        remembrance_audio_temporary_key, remembrance_audio_mime_type,
        remembrance_audio_duration_ms, remembrance_audio_waveform_json,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        progress.selectedPrayerRevisionId,
        _boolValue(progress.detailByVoice),
        progress.remembranceType,
        _boolValue(progress.remembranceByVoice),
        progress.remembranceText,
        progress.remembranceAudioTemporaryKey,
        progress.remembranceAudioMimeType,
        progress.remembranceAudioDurationMs,
        progress.remembranceAudioWaveform == null
            ? null
            : jsonEncode(progress.remembranceAudioWaveform),
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

bool? _nullableBool(Object? value) => switch (value) {
  1 => true,
  0 => false,
  _ => null,
};

int? _boolValue(bool? value) => value == null ? null : (value ? 1 : 0);

List<double>? _waveform(String? value) {
  if (value == null) return null;
  final decoded = jsonDecode(value);
  if (decoded is! List) throw const FormatException('Invalid waveform');
  return decoded.map((item) => (item as num).toDouble()).toList();
}
