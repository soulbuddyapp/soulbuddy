import '../../prayers/domain/prayer_reminder.dart';

class CircleReminder {
  CircleReminder({
    required this.circleId,
    required this.circleName,
    required this.localTime,
    required this.timezone,
    required this.platformNotificationId,
  }) {
    if (circleId.trim().isEmpty || circleId.length > 160) {
      throw ArgumentError.value(circleId, 'circleId');
    }
    if (circleName.trim().isEmpty || circleName.length > 160) {
      throw ArgumentError.value(circleName, 'circleName');
    }
    if (timezone.trim().isEmpty || timezone.length > 64) {
      throw ArgumentError.value(timezone, 'timezone');
    }
    if (platformNotificationId < 0 || platformNotificationId > 2147483647) {
      throw ArgumentError.value(
        platformNotificationId,
        'platformNotificationId',
      );
    }
  }

  final String circleId;
  final String circleName;
  final PrayerLocalTime localTime;
  final String timezone;
  final int platformNotificationId;

  static int platformNotificationIdFor(String circleId) {
    var hash = 2166136261;
    for (final codeUnit in circleId.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return 1400000000 + (hash % 400000000);
  }

  Map<String, Object> toJson() => {
    'circle_id': circleId,
    'circle_name': circleName,
    'local_time': localTime.wireValue,
    'timezone': timezone,
    'platform_notification_id': platformNotificationId,
  };

  factory CircleReminder.fromJson(Map<String, Object?> value) {
    final circleId = value['circle_id'];
    final circleName = value['circle_name'];
    final localTime = value['local_time'];
    final timezone = value['timezone'];
    final platformNotificationId = value['platform_notification_id'];
    if (circleId is! String ||
        circleName is! String ||
        localTime is! String ||
        timezone is! String ||
        platformNotificationId is! int) {
      throw const FormatException('Invalid Circle reminder');
    }
    return CircleReminder(
      circleId: circleId,
      circleName: circleName,
      localTime: PrayerLocalTime.parse(localTime),
      timezone: timezone,
      platformNotificationId: platformNotificationId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CircleReminder &&
      other.circleId == circleId &&
      other.circleName == circleName &&
      other.localTime == localTime &&
      other.timezone == timezone &&
      other.platformNotificationId == platformNotificationId;

  @override
  int get hashCode => Object.hash(
    circleId,
    circleName,
    localTime,
    timezone,
    platformNotificationId,
  );
}
