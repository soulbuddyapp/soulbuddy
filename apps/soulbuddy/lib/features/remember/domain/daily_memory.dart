import '../../record/domain/encounter.dart';

enum DailyMemoryStatus {
  active('active'),
  remembered('remembered'),
  postponed('postponed');

  const DailyMemoryStatus(this.wireValue);
  final String wireValue;

  factory DailyMemoryStatus.fromWire(String value) => values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => DailyMemoryStatus.active,
  );
}

class DailyMemory {
  const DailyMemory({
    required this.occurrenceId,
    required this.localDate,
    required this.memory,
    required this.status,
  });

  final String occurrenceId;
  final DateTime localDate;
  final Encounter memory;
  final DailyMemoryStatus status;
}
