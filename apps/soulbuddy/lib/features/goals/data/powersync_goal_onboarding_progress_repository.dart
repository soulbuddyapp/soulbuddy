import 'package:powersync/powersync.dart';

import '../domain/goal.dart';
import '../domain/goal_onboarding_progress.dart';
import 'goal_onboarding_progress_repository.dart';

class PowerSyncGoalOnboardingProgressRepository
    implements GoalOnboardingProgressRepository {
  PowerSyncGoalOnboardingProgressRepository({
    required this.database,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _rowId = 'current';

  final PowerSyncDatabase database;
  final DateTime Function() _now;

  @override
  Future<GoalOnboardingProgress?> load() async {
    final row = await database.getOptional(
      'SELECT * FROM goal_onboarding_progress WHERE id = ?',
      [_rowId],
    );
    if (row == null) return null;

    try {
      return GoalOnboardingProgress(
        stage: GoalOnboardingStage.values.byName(row['stage'] as String),
        starterKey: _requiredNullableEnum(
          row['starter_key'] as String?,
          GoalStarterKey.tryFromWire,
          'starter_key',
        ),
        stopBehaviorKey: _requiredNullableEnum(
          row['stop_behavior_key'] as String?,
          GoalStopBehaviorKey.tryFromWire,
          'stop_behavior_key',
        ),
        alcoholSafetyChoice: _requiredNullableEnum(
          row['alcohol_safety_choice'] as String?,
          GoalAlcoholSafetyChoice.tryFromWire,
          'alcohol_safety_choice',
        ),
        alcoholCareAcknowledged: _nullableBool(
          row['alcohol_care_acknowledged'],
        ),
        title: row['title'] as String?,
        currentSituation: row['current_situation'] as String?,
        situationByVoice: _nullableBool(row['situation_by_voice']),
        agencyChoice: _requiredNullableEnum(
          row['agency_choice'] as String?,
          GoalAgencyChoice.tryFromWire,
          'agency_choice',
        ),
        todayAction: row['today_action'] as String?,
        guardNote: row['guard_note'] as String?,
        accountabilityChoice: _requiredNullableEnum(
          row['accountability_choice'] as String?,
          GoalAccountabilityChoice.tryFromWire,
          'accountability_choice',
        ),
        prayerSource: _requiredNullableEnum(
          row['prayer_source'] as String?,
          GoalOnboardingPrayerSource.tryFromWire,
          'prayer_source',
        ),
        prayerResourceId: row['prayer_resource_id'] as String?,
        scriptureTranslation: row['scripture_translation'] as String?,
        scriptureBook: row['scripture_book'] as String?,
        scriptureChapter: (row['scripture_chapter'] as num?)?.toInt(),
        scriptureFirstVerse: (row['scripture_first_verse'] as num?)?.toInt(),
        scriptureLastVerse: (row['scripture_last_verse'] as num?)?.toInt(),
        ownPrayerText: row['own_prayer_text'] as String?,
        createdGoalId: row['created_goal_id'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(GoalOnboardingProgress progress) async {
    _bounded(progress.title, 'title', 120);
    _bounded(progress.currentSituation, 'currentSituation', 4000);
    _bounded(progress.todayAction, 'todayAction', 1000);
    _bounded(progress.guardNote, 'guardNote', 1000);
    _bounded(progress.prayerResourceId, 'prayerResourceId', 120);
    _bounded(progress.scriptureTranslation, 'scriptureTranslation', 20);
    _bounded(progress.scriptureBook, 'scriptureBook', 80);
    _bounded(progress.ownPrayerText, 'ownPrayerText', 4000);
    _bounded(progress.createdGoalId, 'createdGoalId', 120);
    _positive(progress.scriptureChapter, 'scriptureChapter');
    _positive(progress.scriptureFirstVerse, 'scriptureFirstVerse');
    _positive(progress.scriptureLastVerse, 'scriptureLastVerse');
    if (progress.scriptureFirstVerse != null &&
        progress.scriptureLastVerse != null &&
        progress.scriptureLastVerse! < progress.scriptureFirstVerse!) {
      throw ArgumentError.value(
        progress.scriptureLastVerse,
        'scriptureLastVerse',
        'must not precede the first verse',
      );
    }

    await database.execute(
      '''
      INSERT OR REPLACE INTO goal_onboarding_progress(
        id, stage, starter_key, stop_behavior_key, alcohol_safety_choice,
        alcohol_care_acknowledged, title, current_situation,
        situation_by_voice, agency_choice, today_action, guard_note,
        accountability_choice, prayer_source, prayer_resource_id,
        scripture_translation, scripture_book, scripture_chapter,
        scripture_first_verse, scripture_last_verse, own_prayer_text,
        created_goal_id, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _rowId,
        progress.stage.name,
        progress.starterKey?.wireValue,
        progress.stopBehaviorKey?.wireValue,
        progress.alcoholSafetyChoice?.wireValue,
        _boolValue(progress.alcoholCareAcknowledged),
        progress.title,
        progress.currentSituation,
        _boolValue(progress.situationByVoice),
        progress.agencyChoice?.wireValue,
        progress.todayAction,
        progress.guardNote,
        progress.accountabilityChoice?.wireValue,
        progress.prayerSource?.wireValue,
        progress.prayerResourceId,
        progress.scriptureTranslation,
        progress.scriptureBook,
        progress.scriptureChapter,
        progress.scriptureFirstVerse,
        progress.scriptureLastVerse,
        progress.ownPrayerText,
        progress.createdGoalId,
        _now().toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> clear() => database.execute(
    'DELETE FROM goal_onboarding_progress WHERE id = ?',
    [_rowId],
  );
}

T? _requiredNullableEnum<T>(
  String? value,
  T? Function(String?) parse,
  String field,
) {
  if (value == null) return null;
  final parsed = parse(value);
  if (parsed == null) throw FormatException('Invalid $field');
  return parsed;
}

bool? _nullableBool(Object? value) => switch (value) {
  null => null,
  1 => true,
  0 => false,
  _ => throw const FormatException('Invalid boolean'),
};

int? _boolValue(bool? value) => value == null ? null : (value ? 1 : 0);

void _bounded(String? value, String name, int maximum) {
  if (value != null && value.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must be at most $maximum characters',
    );
  }
}

void _positive(int? value, String name) {
  if (value != null && value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
}
