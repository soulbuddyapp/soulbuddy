enum GuardKind {
  contentFilter,
  osRestriction,
  appOrAccountRemoval,
  physicalBoundary,
  paymentFriction,
  trustedPersonControl,
}

enum GuardPlatform {
  any,
  router,
  android,
  ios,
  windows,
  macos,
  linux,
  account,
  physical,
}

class GuardDefinition {
  const GuardDefinition({
    required this.id,
    required this.contentVersion,
    required this.kind,
    required this.title,
    required this.description,
    required this.steps,
    required this.platforms,
    required this.goalContextTags,
    required this.reviewedAt,
    this.sourceUri,
    this.archived = false,
  });

  final String id;
  final int contentVersion;
  final GuardKind kind;
  final String title;
  final String description;
  final List<String> steps;
  final Set<GuardPlatform> platforms;
  final Set<String> goalContextTags;
  final DateTime reviewedAt;
  final Uri? sourceUri;
  final bool archived;
}

class GoalGuardSelection {
  const GoalGuardSelection({
    required this.id,
    required this.goalId,
    required this.ownerId,
    required this.guardDefinitionId,
    required this.guardContentVersion,
    required this.configuredAt,
    this.privateNote,
    this.archivedAt,
  });

  final String id;
  final String goalId;
  final String ownerId;
  final String guardDefinitionId;
  final int guardContentVersion;
  final String? privateNote;
  final DateTime configuredAt;
  final DateTime? archivedAt;

  factory GoalGuardSelection.fromRow(Map<String, dynamic> row) =>
      GoalGuardSelection(
        id: row['id'] as String,
        goalId: row['goal_id'] as String,
        ownerId: row['owner_id'] as String,
        guardDefinitionId: row['guard_definition_id'] as String,
        guardContentVersion: (row['guard_content_version'] as num).toInt(),
        privateNote: row['private_note'] as String?,
        configuredAt: DateTime.parse(row['configured_at'] as String),
        archivedAt: switch (row['archived_at']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
      );
}
