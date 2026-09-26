import 'package:powersync/powersync.dart';
import '../domain/commitment.dart';
import 'commitment_journey_progress_repository.dart';

class PowerSyncCommitmentJourneyProgressRepository
    implements CommitmentJourneyProgressRepository {
  PowerSyncCommitmentJourneyProgressRepository({
    required this.database,
    required this.ownerId,
  });
  final PowerSyncDatabase database;
  final String ownerId;
  String get _id => 'current:$ownerId';
  @override
  Future<CommitmentProgressLoadResult> load() async {
    final row = await database.getOptional(
      'SELECT * FROM commitment_journey_progress WHERE id=? AND owner_id=?',
      [_id, ownerId],
    );
    if (row == null) return const CommitmentProgressLoadResult();
    final discarded = <String>{};
    T? parse<T>(String key, T Function(Object) read) {
      final value = row[key];
      if (value == null) return null;
      try {
        return read(value);
      } catch (_) {
        discarded.add(key);
        return null;
      }
    }

    String? text(String key, String kind) =>
        parse(key, (v) => validateCommitmentText(kind, v as String));
    bool flag(String key) =>
        parse(key, (v) {
          if (v != 0 && v != 1) throw const FormatException();
          return v == 1;
        }) ??
        false;
    final frequency = parse(
      'frequency',
      (v) => CommitmentMeditationFrequency.fromWire(v as String),
    );
    var validSchedule = true;
    if ([
      'frequency',
      'weekdays_mask',
      'local_time',
      'timezone',
      'duration_minutes',
    ].any((k) => row[k] != null)) {
      try {
        validateCommitmentPlan(
          frequency: frequency!,
          localTime: row['local_time'] as String,
          timezone: row['timezone'] as String,
          durationMinutes: row['duration_minutes'] as int,
          weekdaysMask: row['weekdays_mask'] as int?,
        );
      } catch (_) {
        validSchedule = false;
        discarded.add('schedule');
      }
    }
    String? prayerId = parse('personal_prayer_id', (v) => _identifier(v));
    String? revisionId = parse(
      'personal_prayer_revision_id',
      (v) => _identifier(v),
    );
    if ((prayerId == null) != (revisionId == null)) {
      prayerId = null;
      revisionId = null;
      discarded.add('personal_prayer');
    }
    final progress = CommitmentJourneyProgress(
      stage:
          parse('stage', (v) => CommitmentJourneyStage.fromWire(v as String)) ??
          CommitmentJourneyStage.invitation,
      readinessTeachingSeen: flag('readiness_teaching_seen'),
      invitationCompleted: flag('invitation_completed'),
      keyNeedOne: text('key_need_one', 'need'),
      keyNeedTwo: text('key_need_two', 'need'),
      keyNeedThree: text('key_need_three', 'need'),
      calling: text('calling', 'calling'),
      name: text('name', 'name'),
      declarationDraft: text('declaration_draft', 'declaration'),
      declarationReviewed: flag('declaration_reviewed'),
      guideId: parse(
        'guide_id',
        (v) => CommitmentGuideId.fromWire(v as String),
      ),
      personalPrayerId: prayerId,
      personalPrayerRevisionId: revisionId,
      frequency: validSchedule ? frequency : null,
      weekdaysMask: validSchedule ? row['weekdays_mask'] as int? : null,
      localTime: validSchedule ? row['local_time'] as String? : null,
      timezone: validSchedule ? row['timezone'] as String? : null,
      durationMinutes: validSchedule ? row['duration_minutes'] as int? : null,
      reminderMode: parse(
        'reminder_mode',
        (v) => CommitmentReminderMode.fromWire(v as String),
      ),
      deferred: flag('deferred'),
    );
    if (discarded.isNotEmpty) await save(progress);
    return CommitmentProgressLoadResult(
      progress: progress,
      discardedFields: Set.unmodifiable(discarded),
    );
  }

  @override
  Future<void> save(CommitmentJourneyProgress progress) async {
    final row = progress.toRow();
    for (final entry in {
      'key_need_one': 'need',
      'key_need_two': 'need',
      'key_need_three': 'need',
      'calling': 'calling',
      'name': 'name',
      'declaration_draft': 'declaration',
    }.entries) {
      final value = row[entry.key];
      if (value != null) {
        row[entry.key] = (value as String).trim().isEmpty
            ? null
            : validateCommitmentText(entry.value, value);
      }
    }
    if (progress.frequency != null ||
        progress.localTime != null ||
        progress.timezone != null ||
        progress.durationMinutes != null ||
        progress.weekdaysMask != null) {
      validateCommitmentPlan(
        frequency:
            progress.frequency ?? (throw ArgumentError('Invalid schedule')),
        localTime: progress.localTime ?? '',
        timezone: progress.timezone ?? '',
        durationMinutes: progress.durationMinutes ?? 0,
        weekdaysMask: progress.weekdaysMask,
      );
    }
    if ((progress.personalPrayerId == null) !=
        (progress.personalPrayerRevisionId == null)) {
      throw ArgumentError('Invalid personal prayer reference');
    }
    if (progress.personalPrayerId != null) {
      _identifier(progress.personalPrayerId!);
      _identifier(progress.personalPrayerRevisionId!);
    }
    row.addAll({
      'id': _id,
      'owner_id': ownerId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await database.execute(
      'INSERT OR REPLACE INTO commitment_journey_progress (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
      row.values.toList(),
    );
  }

  @override
  Future<void> clear() async {
    await database.execute(
      'DELETE FROM commitment_journey_progress WHERE id=? AND owner_id=?',
      [_id, ownerId],
    );
  }
}

String _identifier(Object value) {
  if (value is! String || value.trim().isEmpty || value.length > 120) {
    throw const FormatException('Invalid identifier');
  }
  return value;
}
