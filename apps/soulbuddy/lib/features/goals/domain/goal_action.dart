enum GoalActionKind {
  nextStep('next_step'),
  commitmentPractice('commitment_practice'),
  guard('guard'),
  accountability('accountability'),
  care('care'),
  other('other');

  const GoalActionKind(this.wireValue);

  final String wireValue;

  static GoalActionKind fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal action kind: $value'),
  );
}

enum GoalScheduleType {
  today('today'),
  once('once'),
  daily('daily'),
  selectedDays('selected_days'),
  none('none');

  const GoalScheduleType(this.wireValue);

  final String wireValue;

  static GoalScheduleType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal schedule type: $value'),
  );
}

enum GoalActionEventType {
  completed('completed'),
  skipped('skipped'),
  retracted('retracted');

  const GoalActionEventType(this.wireValue);

  final String wireValue;

  static GoalActionEventType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal action event: $value'),
  );
}

class GoalActionDraft {
  const GoalActionDraft({
    required this.body,
    required this.kind,
    this.scheduleType = GoalScheduleType.none,
    this.localTime,
    this.timezone,
    this.onceAt,
    this.weekdaysMask,
    this.enabled = true,
  });

  final String body;
  final GoalActionKind kind;
  final GoalScheduleType scheduleType;
  final String? localTime;
  final String? timezone;
  final DateTime? onceAt;
  final int? weekdaysMask;
  final bool enabled;
}

class GoalAction {
  const GoalAction({
    this.commitmentPracticePosition,
    required this.id,
    required this.goalId,
    required this.ownerId,
    required this.body,
    required this.kind,
    required this.scheduleType,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.localTime,
    this.timezone,
    this.onceAt,
    this.weekdaysMask,
    this.archivedAt,
  });

  /// Read projection from the linked Commitment practice, never uploaded.
  final int? commitmentPracticePosition;
  final String id;
  final String goalId;
  final String ownerId;
  final String body;
  final GoalActionKind kind;
  final GoalScheduleType scheduleType;
  final String? localTime;
  final String? timezone;
  final DateTime? onceAt;
  final int? weekdaysMask;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory GoalAction.fromRow(Map<String, dynamic> row) => GoalAction(
    commitmentPracticePosition: (row['commitment_practice_position'] as num?)
        ?.toInt(),
    id: row['id'] as String,
    goalId: row['goal_id'] as String,
    ownerId: row['owner_id'] as String,
    body: row['body'] as String,
    kind: GoalActionKind.fromWire(row['action_kind'] as String),
    scheduleType: GoalScheduleType.fromWire(row['schedule_type'] as String),
    localTime: row['local_time'] as String?,
    timezone: row['timezone'] as String?,
    onceAt: switch (row['once_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
    weekdaysMask: (row['weekdays_mask'] as num?)?.toInt(),
    enabled: (row['enabled'] as num).toInt() == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    archivedAt: switch (row['archived_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );

  bool isScheduledOn(DateTime localDate) {
    final date = DateTime(localDate.year, localDate.month, localDate.day);
    return switch (scheduleType) {
      GoalScheduleType.today || GoalScheduleType.once =>
        onceAt != null && _sameDate(onceAt!.toLocal(), date),
      GoalScheduleType.daily => true,
      GoalScheduleType.selectedDays =>
        weekdaysMask != null &&
            (weekdaysMask! & (1 << (date.weekday - 1))) != 0,
      GoalScheduleType.none => false,
    };
  }

  String occurrenceKeyFor(DateTime localDate) =>
      '$id:${goalLocalDateKey(localDate)}';
}

class GoalActionEvent {
  const GoalActionEvent({
    required this.id,
    required this.goalActionId,
    required this.goalId,
    required this.ownerId,
    required this.type,
    required this.occurrenceKey,
    required this.occurredAt,
    required this.localDate,
    required this.deviceId,
  });

  final String id;
  final String goalActionId;
  final String goalId;
  final String ownerId;
  final GoalActionEventType type;
  final String occurrenceKey;
  final DateTime occurredAt;
  final String localDate;
  final String deviceId;

  factory GoalActionEvent.fromRow(Map<String, dynamic> row) => GoalActionEvent(
    id: row['id'] as String,
    goalActionId: row['goal_action_id'] as String,
    goalId: row['goal_id'] as String,
    ownerId: row['owner_id'] as String,
    type: GoalActionEventType.fromWire(row['event_type'] as String),
    occurrenceKey: row['occurrence_key'] as String,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    localDate: row['local_date'] as String,
    deviceId: row['device_id'] as String,
  );
}

class GoalActionOccurrence {
  const GoalActionOccurrence({
    required this.action,
    required this.occurrenceKey,
    this.latestEventType,
  });

  final GoalAction action;
  final String occurrenceKey;
  final GoalActionEventType? latestEventType;
}

String goalLocalDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
