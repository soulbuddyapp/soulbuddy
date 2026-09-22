enum GoalStarterKey {
  closerToGod('closer_to_god'),
  stopControl('stop_control'),
  direction('direction'),
  difficultTime('difficult_time'),
  other('other');

  const GoalStarterKey(this.wireValue);

  final String wireValue;

  static GoalStarterKey? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum GoalMode {
  actionable('actionable'),
  petition('petition'),
  mixed('mixed');

  const GoalMode(this.wireValue);

  final String wireValue;

  static GoalMode fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal mode: $value'),
  );
}

enum GoalStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  archived('archived');

  const GoalStatus(this.wireValue);

  final String wireValue;

  static GoalStatus fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal status: $value'),
  );
}

class GoalRevision {
  const GoalRevision({
    required this.id,
    required this.goalId,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    required this.deviceId,
    this.currentSituation,
    this.whyItMatters,
  });

  final String id;
  final String goalId;
  final String ownerId;
  final String title;
  final String? currentSituation;
  final String? whyItMatters;
  final DateTime createdAt;
  final String deviceId;

  factory GoalRevision.fromRow(Map<String, dynamic> row) => GoalRevision(
    id: row['id'] as String,
    goalId: row['goal_id'] as String,
    ownerId: row['owner_id'] as String,
    title: row['title'] as String,
    currentSituation: row['current_situation'] as String?,
    whyItMatters: row['why_it_matters'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    deviceId: row['device_id'] as String,
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.ownerId,
    required this.mode,
    required this.status,
    required this.currentRevisionId,
    required this.position,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.starterKey,
    this.currentSituation,
    this.whyItMatters,
    this.nextAction,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final GoalStarterKey? starterKey;
  final GoalMode mode;
  final GoalStatus status;
  final String currentRevisionId;
  final int position;
  final String title;
  final String? currentSituation;
  final String? whyItMatters;
  final String? nextAction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  String get displayTitle {
    if (title != 'Grow closer to God') return title;
    for (final specific in [currentSituation, nextAction]) {
      final value = specific?.trim();
      if (value != null && value.isNotEmpty && value != title) return value;
    }
    return title;
  }

  factory Goal.fromRow(Map<String, dynamic> row) => Goal(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    starterKey: GoalStarterKey.tryFromWire(row['starter_key'] as String?),
    mode: GoalMode.fromWire(row['mode'] as String),
    status: GoalStatus.fromWire(row['status'] as String),
    currentRevisionId: row['current_revision_id'] as String,
    position: (row['position'] as num).toInt(),
    title: row['title'] as String,
    currentSituation: row['current_situation'] as String?,
    whyItMatters: row['why_it_matters'] as String?,
    nextAction: row['next_action'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    archivedAt: switch (row['archived_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}
