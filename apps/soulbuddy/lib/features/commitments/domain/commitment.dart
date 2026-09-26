import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

enum CommitmentJourneySlot {
  primary('primary');

  const CommitmentJourneySlot(this.wireValue);
  final String wireValue;
  static CommitmentJourneySlot? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentJourneySlot fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentGuideId {
  surrender('surrender'),
  direction('direction'),
  peace('peace');

  const CommitmentGuideId(this.wireValue);
  final String wireValue;
  static CommitmentGuideId? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentGuideId fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentPracticeCategory {
  joyPleasure('joy_pleasure'),
  explorationAdventure('exploration_adventure'),
  attentionSelfEsteem('attention_self_esteem');

  const CommitmentPracticeCategory(this.wireValue);
  final String wireValue;
  static CommitmentPracticeCategory? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentPracticeCategory fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentPracticeSource {
  reviewedSuggestion('reviewed_suggestion'),
  userAuthored('user_authored');

  const CommitmentPracticeSource(this.wireValue);
  final String wireValue;
  static CommitmentPracticeSource? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentPracticeSource fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentMeditationFrequency {
  daily('daily'),
  selectedDays('selected_days');

  const CommitmentMeditationFrequency(this.wireValue);
  final String wireValue;
  static CommitmentMeditationFrequency? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentMeditationFrequency fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentSessionKind {
  meditation('meditation'),
  listening('listening');

  const CommitmentSessionKind(this.wireValue);
  final String wireValue;
  static CommitmentSessionKind? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentSessionKind fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentMeditationSessionOutcome {
  completed('completed'),
  endedEarly('ended_early');

  const CommitmentMeditationSessionOutcome(this.wireValue);
  final String wireValue;
  static CommitmentMeditationSessionOutcome? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentMeditationSessionOutcome fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentReminderMode {
  voice('voice'),
  silent('silent'),
  off('off');

  const CommitmentReminderMode(this.wireValue);
  final String wireValue;
  static CommitmentReminderMode? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentReminderMode fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentPreparationCycleState {
  active('active'),
  reviewAvailable('review_available'),
  listeningOpened('listening_opened'),
  deferred('deferred');

  const CommitmentPreparationCycleState(this.wireValue);
  final String wireValue;
  static CommitmentPreparationCycleState? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentPreparationCycleState fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

enum CommitmentJourneyStage {
  invitation('invitation'),
  quietPlace('quiet_place'),
  needs('needs'),
  calling('calling'),
  practices('practices'),
  declaration('declaration'),
  guide('guide'),
  schedule('schedule'),
  name('name'),
  summary('summary'),
  finalizing('finalizing');

  const CommitmentJourneyStage(this.wireValue);
  final String wireValue;
  static CommitmentJourneyStage? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static CommitmentJourneyStage fromWire(String value) =>
      tryFromWire(value) ??
      (throw const FormatException('Invalid commitment enum'));
}

abstract final class CommitmentTextLimits {
  static const name = 120,
      need = 500,
      calling = 1500,
      practice = 1000,
      declaration = 4000;
  static int forField(String field) => switch (field) {
    'name' => name,
    'need' => need,
    'calling' => calling,
    'practice' => practice,
    'declaration' => declaration,
    _ => throw ArgumentError('Invalid commitment field'),
  };
}

String validateCommitmentText(String field, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.runes.length > CommitmentTextLimits.forField(field)) {
    throw ArgumentError('Invalid commitment text');
  }
  return normalized;
}

void validatePracticeCount(int count) {
  if (count < 1 || count > 12) throw ArgumentError('Invalid practice count');
}

bool _timezoneReady = false;
tz.Location commitmentTimezone(String timezone) {
  if (!_timezoneReady) {
    timezone_data.initializeTimeZones();
    _timezoneReady = true;
  }
  try {
    return tz.getLocation(timezone);
  } catch (_) {
    throw ArgumentError('Invalid timezone');
  }
}

void validateCommitmentPlan({
  required CommitmentMeditationFrequency frequency,
  required String localTime,
  required String timezone,
  required int durationMinutes,
  int? weekdaysMask,
}) {
  if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(localTime) ||
      !{5, 10, 15, 20, 30}.contains(durationMinutes) ||
      (frequency == CommitmentMeditationFrequency.daily &&
          weekdaysMask != null) ||
      (frequency == CommitmentMeditationFrequency.selectedDays &&
          (weekdaysMask == null || weekdaysMask < 1 || weekdaysMask > 127))) {
    throw ArgumentError('Invalid meditation schedule');
  }
  commitmentTimezone(timezone);
}

/// Replicated SQL timestamps represent UTC even when their wire text has no
/// suffix. Do not interpret those timestamps in the device's local timezone.
DateTime parseCommitmentUtcTimestamp(String value) {
  final parsed = DateTime.parse(value);
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String commitmentLocalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime parseCommitmentLocalDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      commitmentLocalDate(parsed) != value) {
    throw ArgumentError('Invalid local date');
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String commitmentReviewLocalDate(String start) => commitmentLocalDate(
  parseCommitmentLocalDate(start).add(const Duration(days: 9)),
);
String buildCommitmentDeclarationDraft({
  required String name,
  required String calling,
  required List<String> practices,
}) =>
    'I, ${name.trim()}, pledge to pursue ${calling.trim()}.\n\n'
    'I pray that God takes and leads me as I embark on this journey to know and do ${calling.trim()}.\n\n'
    'I commit my heart and mind daily to ${practices.map((p) => p.trim()).join('; ')}.\n\n'
    'I surrender my whole self—spirit, mind, body, desires, and daily life—to Christ’s renewal.\n\n'
    'I plead the blood of Jesus, richly purchased for me, for forgiveness and cleansing.\n\n'
    'As I write these intentions, may the Holy Spirit guide me.';

class Commitment {
  const Commitment({
    required this.id,
    required this.ownerId,
    required this.journeySlot,
    required this.goalId,
    required this.name,
    required this.keyNeedOne,
    required this.keyNeedTwo,
    required this.keyNeedThree,
    required this.calling,
    required this.guideId,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final CommitmentJourneySlot journeySlot;
  final String goalId;
  final String name;
  final String keyNeedOne;
  final String keyNeedTwo;
  final String keyNeedThree;
  final String calling;
  final CommitmentGuideId guideId;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'journey_slot': journeySlot.wireValue,
    'goal_id': goalId,
    'name': name,
    'key_need_one': keyNeedOne,
    'key_need_two': keyNeedTwo,
    'key_need_three': keyNeedThree,
    'calling': calling,
    'guide_id': guideId.wireValue,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
  factory Commitment.fromRow(Map<String, dynamic> row) => Commitment(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    journeySlot: CommitmentJourneySlot.fromWire(row['journey_slot'] as String),
    goalId: row['goal_id'] as String,
    name: row['name'] as String,
    keyNeedOne: row['key_need_one'] as String,
    keyNeedTwo: row['key_need_two'] as String,
    keyNeedThree: row['key_need_three'] as String,
    calling: row['calling'] as String,
    guideId: CommitmentGuideId.fromWire(row['guide_id'] as String),
    createdAt: parseCommitmentUtcTimestamp(row['created_at'] as String),
    updatedAt: parseCommitmentUtcTimestamp(row['updated_at'] as String),
  );
}

class CommitmentPractice {
  const CommitmentPractice({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.goalActionId,
    required this.category,
    required this.body,
    required this.position,
    required this.source,
    this.suggestionId,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final String goalActionId;
  final CommitmentPracticeCategory category;
  final String body;
  final int position;
  final CommitmentPracticeSource source;
  final String? suggestionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'commitment_id': commitmentId,
    'goal_action_id': goalActionId,
    'category': category.wireValue,
    'body': body,
    'position': position,
    'source': source.wireValue,
    'suggestion_id': suggestionId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
  factory CommitmentPractice.fromRow(Map<String, dynamic> row) =>
      CommitmentPractice(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        commitmentId: row['commitment_id'] as String,
        goalActionId: row['goal_action_id'] as String,
        category: CommitmentPracticeCategory.fromWire(
          row['category'] as String,
        ),
        body: row['body'] as String,
        position: row['position'] as int,
        source: CommitmentPracticeSource.fromWire(row['source'] as String),
        suggestionId: row['suggestion_id'] as String?,
        createdAt: parseCommitmentUtcTimestamp(row['created_at'] as String),
        updatedAt: parseCommitmentUtcTimestamp(row['updated_at'] as String),
      );
}

class CommitmentDeclaration {
  const CommitmentDeclaration({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.body,
    required this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final String body;
  final DateTime reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'commitment_id': commitmentId,
    'body': body,
    'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
  factory CommitmentDeclaration.fromRow(Map<String, dynamic> row) =>
      CommitmentDeclaration(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        commitmentId: row['commitment_id'] as String,
        body: row['body'] as String,
        reviewedAt: parseCommitmentUtcTimestamp(row['reviewed_at'] as String),
        createdAt: parseCommitmentUtcTimestamp(row['created_at'] as String),
        updatedAt: parseCommitmentUtcTimestamp(row['updated_at'] as String),
      );
}

class CommitmentMeditationPlan {
  const CommitmentMeditationPlan({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.frequency,
    this.weekdaysMask,
    required this.localTime,
    required this.timezone,
    required this.durationMinutes,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final CommitmentMeditationFrequency frequency;
  final int? weekdaysMask;
  final String localTime;
  final String timezone;
  final int durationMinutes;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'commitment_id': commitmentId,
    'frequency': frequency.wireValue,
    'weekdays_mask': weekdaysMask,
    'local_time': localTime,
    'timezone': timezone,
    'duration_minutes': durationMinutes,
    'enabled': enabled ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
  factory CommitmentMeditationPlan.fromRow(Map<String, dynamic> row) =>
      CommitmentMeditationPlan(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        commitmentId: row['commitment_id'] as String,
        frequency: CommitmentMeditationFrequency.fromWire(
          row['frequency'] as String,
        ),
        weekdaysMask: row['weekdays_mask'] as int?,
        localTime: row['local_time'] as String,
        timezone: row['timezone'] as String,
        durationMinutes: row['duration_minutes'] as int,
        enabled: row['enabled'] == 1,
        createdAt: parseCommitmentUtcTimestamp(row['created_at'] as String),
        updatedAt: parseCommitmentUtcTimestamp(row['updated_at'] as String),
      );
}

class CommitmentPreparationCycle {
  const CommitmentPreparationCycle({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.startedAtUtc,
    required this.startedLocalDate,
    required this.startTimezone,
    required this.reviewLocalDate,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final DateTime startedAtUtc;
  final String startedLocalDate;
  final String startTimezone;
  final String reviewLocalDate;
  final CommitmentPreparationCycleState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'commitment_id': commitmentId,
    'started_at_utc': startedAtUtc.toUtc().toIso8601String(),
    'started_local_date': startedLocalDate,
    'start_timezone': startTimezone,
    'review_local_date': reviewLocalDate,
    'state': state.wireValue,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
  factory CommitmentPreparationCycle.fromRow(Map<String, dynamic> row) =>
      CommitmentPreparationCycle(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        commitmentId: row['commitment_id'] as String,
        startedAtUtc: parseCommitmentUtcTimestamp(
          row['started_at_utc'] as String,
        ),
        startedLocalDate: row['started_local_date'] as String,
        startTimezone: row['start_timezone'] as String,
        reviewLocalDate: row['review_local_date'] as String,
        state: CommitmentPreparationCycleState.fromWire(row['state'] as String),
        createdAt: parseCommitmentUtcTimestamp(row['created_at'] as String),
        updatedAt: parseCommitmentUtcTimestamp(row['updated_at'] as String),
      );
}

class CommitmentMeditationSession {
  const CommitmentMeditationSession({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.sessionKind,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.outcome,
    required this.deviceId,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final CommitmentSessionKind sessionKind;
  final DateTime startedAt;
  final DateTime endedAt;
  final String localDate;
  final int plannedDurationSeconds;
  final int actualDurationSeconds;
  final CommitmentMeditationSessionOutcome outcome;
  final String deviceId;
  Map<String, Object?> toRow() => {
    'id': id,
    'owner_id': ownerId,
    'commitment_id': commitmentId,
    'session_kind': sessionKind.wireValue,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'local_date': localDate,
    'planned_duration_seconds': plannedDurationSeconds,
    'actual_duration_seconds': actualDurationSeconds,
    'outcome': outcome.wireValue,
    'device_id': deviceId,
  };
  factory CommitmentMeditationSession.fromRow(Map<String, dynamic> row) =>
      CommitmentMeditationSession(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        commitmentId: row['commitment_id'] as String,
        sessionKind: CommitmentSessionKind.fromWire(
          row['session_kind'] as String,
        ),
        startedAt: parseCommitmentUtcTimestamp(row['started_at'] as String),
        endedAt: parseCommitmentUtcTimestamp(row['ended_at'] as String),
        localDate: row['local_date'] as String,
        plannedDurationSeconds: row['planned_duration_seconds'] as int,
        actualDurationSeconds: row['actual_duration_seconds'] as int,
        outcome: CommitmentMeditationSessionOutcome.fromWire(
          row['outcome'] as String,
        ),
        deviceId: row['device_id'] as String,
      );
}

class CommitmentDeclarationDraft {
  const CommitmentDeclarationDraft({
    required this.commitmentId,
    required this.body,
  });
  final String commitmentId;
  final String body;
  Map<String, Object?> toRow() => {'commitment_id': commitmentId, 'body': body};
  factory CommitmentDeclarationDraft.fromRow(Map<String, dynamic> row) =>
      CommitmentDeclarationDraft(
        commitmentId: row['commitment_id'] as String,
        body: row['body'] as String,
      );
}

class CommitmentMeditationPlanDraft {
  const CommitmentMeditationPlanDraft({
    required this.commitmentId,
    required this.frequency,
    this.weekdaysMask,
    required this.localTime,
    required this.timezone,
    required this.durationMinutes,
    required this.enabled,
  });
  final String commitmentId;
  final CommitmentMeditationFrequency frequency;
  final int? weekdaysMask;
  final String localTime;
  final String timezone;
  final int durationMinutes;
  final bool enabled;
  Map<String, Object?> toRow() => {
    'commitment_id': commitmentId,
    'frequency': frequency.wireValue,
    'weekdays_mask': weekdaysMask,
    'local_time': localTime,
    'timezone': timezone,
    'duration_minutes': durationMinutes,
    'enabled': enabled ? 1 : 0,
  };
  factory CommitmentMeditationPlanDraft.fromRow(Map<String, dynamic> row) =>
      CommitmentMeditationPlanDraft(
        commitmentId: row['commitment_id'] as String,
        frequency: CommitmentMeditationFrequency.fromWire(
          row['frequency'] as String,
        ),
        weekdaysMask: row['weekdays_mask'] as int?,
        localTime: row['local_time'] as String,
        timezone: row['timezone'] as String,
        durationMinutes: row['duration_minutes'] as int,
        enabled: row['enabled'] == 1,
      );
}

class CommitmentPreparationCycleDraft {
  const CommitmentPreparationCycleDraft({
    required this.commitmentId,
    required this.startedAtUtc,
    required this.startedLocalDate,
    required this.startTimezone,
    required this.reviewLocalDate,
    required this.state,
  });
  final String commitmentId;
  final DateTime startedAtUtc;
  final String startedLocalDate;
  final String startTimezone;
  final String reviewLocalDate;
  final CommitmentPreparationCycleState state;
  Map<String, Object?> toRow() => {
    'commitment_id': commitmentId,
    'started_at_utc': startedAtUtc.toUtc().toIso8601String(),
    'started_local_date': startedLocalDate,
    'start_timezone': startTimezone,
    'review_local_date': reviewLocalDate,
    'state': state.wireValue,
  };
  factory CommitmentPreparationCycleDraft.fromRow(Map<String, dynamic> row) =>
      CommitmentPreparationCycleDraft(
        commitmentId: row['commitment_id'] as String,
        startedAtUtc: parseCommitmentUtcTimestamp(
          row['started_at_utc'] as String,
        ),
        startedLocalDate: row['started_local_date'] as String,
        startTimezone: row['start_timezone'] as String,
        reviewLocalDate: row['review_local_date'] as String,
        state: CommitmentPreparationCycleState.fromWire(row['state'] as String),
      );
}

class CommitmentMeditationSessionDraft {
  const CommitmentMeditationSessionDraft({
    this.id,
    required this.commitmentId,
    required this.sessionKind,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.outcome,
    required this.deviceId,
  });
  final String? id;
  final String commitmentId;
  final CommitmentSessionKind sessionKind;
  final DateTime startedAt;
  final DateTime endedAt;
  final String localDate;
  final int plannedDurationSeconds;
  final int actualDurationSeconds;
  final CommitmentMeditationSessionOutcome outcome;
  final String deviceId;
  Map<String, Object?> toRow() => {
    'commitment_id': commitmentId,
    'session_kind': sessionKind.wireValue,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'local_date': localDate,
    'planned_duration_seconds': plannedDurationSeconds,
    'actual_duration_seconds': actualDurationSeconds,
    'outcome': outcome.wireValue,
    'device_id': deviceId,
  };
  factory CommitmentMeditationSessionDraft.fromRow(Map<String, dynamic> row) =>
      CommitmentMeditationSessionDraft(
        id: row['id'] as String?,
        commitmentId: row['commitment_id'] as String,
        sessionKind: CommitmentSessionKind.fromWire(
          row['session_kind'] as String,
        ),
        startedAt: parseCommitmentUtcTimestamp(row['started_at'] as String),
        endedAt: parseCommitmentUtcTimestamp(row['ended_at'] as String),
        localDate: row['local_date'] as String,
        plannedDurationSeconds: row['planned_duration_seconds'] as int,
        actualDurationSeconds: row['actual_duration_seconds'] as int,
        outcome: CommitmentMeditationSessionOutcome.fromWire(
          row['outcome'] as String,
        ),
        deviceId: row['device_id'] as String,
      );
}

class CommitmentDetails {
  const CommitmentDetails({
    required this.commitment,
    required this.practices,
    this.declaration,
    this.plan,
    this.preparationCycle,
  });
  final Commitment commitment;
  final List<CommitmentPractice> practices;
  final CommitmentDeclaration? declaration;
  final CommitmentMeditationPlan? plan;
  final CommitmentPreparationCycle? preparationCycle;
}

class CommitmentPracticeDraft {
  const CommitmentPracticeDraft({
    required this.id,
    required this.category,
    required this.body,
    this.source = CommitmentPracticeSource.userAuthored,
    this.suggestionId,
    this.position = 0,
  });
  final String id;
  final CommitmentPracticeCategory category;
  final String body;
  final CommitmentPracticeSource source;
  final String? suggestionId;
  final int position;
  Map<String, Object?> toRow() => {
    'id': id,
    'category': category.wireValue,
    'body': body,
    'source': source.wireValue,
    'suggestion_id': suggestionId,
    'position': position,
  };
  factory CommitmentPracticeDraft.fromRow(Map<String, dynamic> row) =>
      CommitmentPracticeDraft(
        id: row['id'] as String,
        category: CommitmentPracticeCategory.fromWire(
          row['category'] as String,
        ),
        body: row['body'] as String,
        source: CommitmentPracticeSource.fromWire(row['source'] as String),
        suggestionId: row['suggestion_id'] as String?,
        position: row['position'] as int,
      );
  CommitmentPracticeDraft copyWith({
    String? id,
    CommitmentPracticeCategory? category,
    String? body,
    CommitmentPracticeSource? source,
    String? suggestionId,
    int? position,
  }) => CommitmentPracticeDraft(
    id: id ?? this.id,
    category: category ?? this.category,
    body: body ?? this.body,
    source: source ?? this.source,
    suggestionId: suggestionId ?? this.suggestionId,
    position: position ?? this.position,
  );
}

class CommitmentJourneyProgress {
  const CommitmentJourneyProgress({
    this.stage = CommitmentJourneyStage.invitation,
    this.readinessTeachingSeen = false,
    this.invitationCompleted = false,
    this.keyNeedOne,
    this.keyNeedTwo,
    this.keyNeedThree,
    this.calling,
    this.guideId,
    this.personalPrayerId,
    this.personalPrayerRevisionId,
    this.declarationDraft,
    this.declarationReviewed = false,
    this.frequency,
    this.weekdaysMask,
    this.localTime,
    this.timezone,
    this.durationMinutes,
    this.reminderMode,
    this.name,
    this.deferred = false,
  });
  final CommitmentJourneyStage stage;
  final bool readinessTeachingSeen;
  final bool invitationCompleted;
  final String? keyNeedOne;
  final String? keyNeedTwo;
  final String? keyNeedThree;
  final String? calling;
  final CommitmentGuideId? guideId;
  final String? personalPrayerId;
  final String? personalPrayerRevisionId;
  final String? declarationDraft;
  final bool declarationReviewed;
  final CommitmentMeditationFrequency? frequency;
  final int? weekdaysMask;
  final String? localTime;
  final String? timezone;
  final int? durationMinutes;
  final CommitmentReminderMode? reminderMode;
  final String? name;
  final bool deferred;
  Map<String, Object?> toRow() => {
    'stage': stage.wireValue,
    'readiness_teaching_seen': readinessTeachingSeen ? 1 : 0,
    'invitation_completed': invitationCompleted ? 1 : 0,
    'key_need_one': keyNeedOne,
    'key_need_two': keyNeedTwo,
    'key_need_three': keyNeedThree,
    'calling': calling,
    'guide_id': guideId?.wireValue,
    'personal_prayer_id': personalPrayerId,
    'personal_prayer_revision_id': personalPrayerRevisionId,
    'declaration_draft': declarationDraft,
    'declaration_reviewed': declarationReviewed ? 1 : 0,
    'frequency': frequency?.wireValue,
    'weekdays_mask': weekdaysMask,
    'local_time': localTime,
    'timezone': timezone,
    'duration_minutes': durationMinutes,
    'reminder_mode': reminderMode?.wireValue,
    'name': name,
    'deferred': deferred ? 1 : 0,
  };
  CommitmentJourneyProgress copyWith({
    CommitmentJourneyStage? stage,
    bool? readinessTeachingSeen,
    bool? invitationCompleted,
    Object? keyNeedOne = _unchanged,
    Object? keyNeedTwo = _unchanged,
    Object? keyNeedThree = _unchanged,
    Object? calling = _unchanged,
    Object? guideId = _unchanged,
    Object? personalPrayerId = _unchanged,
    Object? personalPrayerRevisionId = _unchanged,
    Object? declarationDraft = _unchanged,
    bool? declarationReviewed,
    Object? frequency = _unchanged,
    Object? weekdaysMask = _unchanged,
    Object? localTime = _unchanged,
    Object? timezone = _unchanged,
    Object? durationMinutes = _unchanged,
    Object? reminderMode = _unchanged,
    Object? name = _unchanged,
    bool? deferred,
  }) => CommitmentJourneyProgress(
    stage: stage ?? this.stage,
    readinessTeachingSeen: readinessTeachingSeen ?? this.readinessTeachingSeen,
    invitationCompleted: invitationCompleted ?? this.invitationCompleted,
    keyNeedOne: identical(keyNeedOne, _unchanged)
        ? this.keyNeedOne
        : keyNeedOne as String?,
    keyNeedTwo: identical(keyNeedTwo, _unchanged)
        ? this.keyNeedTwo
        : keyNeedTwo as String?,
    keyNeedThree: identical(keyNeedThree, _unchanged)
        ? this.keyNeedThree
        : keyNeedThree as String?,
    calling: identical(calling, _unchanged) ? this.calling : calling as String?,
    guideId: identical(guideId, _unchanged)
        ? this.guideId
        : guideId as CommitmentGuideId?,
    personalPrayerId: identical(personalPrayerId, _unchanged)
        ? this.personalPrayerId
        : personalPrayerId as String?,
    personalPrayerRevisionId: identical(personalPrayerRevisionId, _unchanged)
        ? this.personalPrayerRevisionId
        : personalPrayerRevisionId as String?,
    declarationDraft: identical(declarationDraft, _unchanged)
        ? this.declarationDraft
        : declarationDraft as String?,
    declarationReviewed: declarationReviewed ?? this.declarationReviewed,
    frequency: identical(frequency, _unchanged)
        ? this.frequency
        : frequency as CommitmentMeditationFrequency?,
    weekdaysMask: identical(weekdaysMask, _unchanged)
        ? this.weekdaysMask
        : weekdaysMask as int?,
    localTime: identical(localTime, _unchanged)
        ? this.localTime
        : localTime as String?,
    timezone: identical(timezone, _unchanged)
        ? this.timezone
        : timezone as String?,
    durationMinutes: identical(durationMinutes, _unchanged)
        ? this.durationMinutes
        : durationMinutes as int?,
    reminderMode: identical(reminderMode, _unchanged)
        ? this.reminderMode
        : reminderMode as CommitmentReminderMode?,
    name: identical(name, _unchanged) ? this.name : name as String?,
    deferred: deferred ?? this.deferred,
  );
}

void validateCommitmentSession(CommitmentMeditationSessionDraft draft) {
  parseCommitmentLocalDate(draft.localDate);
  final allowed = draft.sessionKind == CommitmentSessionKind.listening
      ? {300, 600, 900}
      : {300, 600, 900, 1200, 1800};
  if (!allowed.contains(draft.plannedDurationSeconds) ||
      draft.actualDurationSeconds < 0 ||
      draft.endedAt.isBefore(draft.startedAt) ||
      (draft.outcome == CommitmentMeditationSessionOutcome.completed &&
          draft.actualDurationSeconds != draft.plannedDurationSeconds) ||
      (draft.outcome == CommitmentMeditationSessionOutcome.endedEarly &&
          draft.actualDurationSeconds >= draft.plannedDurationSeconds)) {
    throw ArgumentError('Invalid commitment session');
  }
}

const _unchanged = Object();
