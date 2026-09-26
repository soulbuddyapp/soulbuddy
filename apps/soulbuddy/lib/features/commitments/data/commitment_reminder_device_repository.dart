import '../domain/commitment.dart';

class CommitmentReminderDeviceState {
  const CommitmentReminderDeviceState({
    required this.commitmentId,
    required this.deviceId,
    required this.mode,
    this.nextOccurrence,
    this.scheduledTimezone,
    this.notificationIds = const [],
    this.updatedAt,
  });
  final String commitmentId, deviceId;
  final CommitmentReminderMode mode;
  final DateTime? nextOccurrence, updatedAt;
  final String? scheduledTimezone;
  final List<int> notificationIds;
}

abstract interface class CommitmentReminderDeviceRepository {
  Future<CommitmentReminderDeviceState?> load(
    String commitmentId,
    String deviceId,
  );
  Future<void> save(CommitmentReminderDeviceState state);
  Future<void> clear(String commitmentId, String deviceId);
}
