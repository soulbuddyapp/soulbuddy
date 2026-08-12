enum EncounterSyncState { pending, synced, attention }

enum MemoryType {
  encounter('encounter'),
  promise('promise'),
  leftBehind('left_behind'),
  revelation('revelation'),
  scripture('scripture'),
  person('person'),
  family('family'),
  lesson('lesson'),
  testimony('testimony');

  const MemoryType(this.wireValue);
  final String wireValue;

  factory MemoryType.fromWire(String? value) => values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => MemoryType.encounter,
  );
}

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
    this.memoryType = MemoryType.encounter,
    this.sensitive = false,
    this.recallEnabled = true,
    this.recallPaused = false,
    this.recallIntervalDays = 7,
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
  final MemoryType memoryType;
  final bool sensitive;
  final bool recallEnabled;
  final bool recallPaused;
  final int recallIntervalDays;
}

class MemoryReflection {
  const MemoryReflection({
    required this.id,
    required this.encounterId,
    required this.ownerId,
    required this.body,
    required this.localDate,
    required this.createdAt,
    required this.deviceId,
  });

  final String id;
  final String encounterId;
  final String ownerId;
  final String body;
  final String localDate;
  final DateTime createdAt;
  final String deviceId;
}
