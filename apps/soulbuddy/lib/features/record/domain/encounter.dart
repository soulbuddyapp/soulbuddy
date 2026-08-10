enum EncounterSyncState { pending, synced, attention }

class Encounter {
  const Encounter({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.body,
    required this.occurredOn,
    required this.isAltar,
    required this.createdAt,
    required this.updatedAt,
    required this.currentRevisionId,
    required this.syncState,
  });

  final String id;
  final String ownerId;
  final String title;
  final String body;
  final String occurredOn;
  final bool isAltar;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String currentRevisionId;
  final EncounterSyncState syncState;
}
