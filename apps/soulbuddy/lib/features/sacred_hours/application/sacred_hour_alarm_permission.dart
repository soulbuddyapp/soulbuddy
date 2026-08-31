enum ExactAlarmPermissionStatus { granted, denied, unsupported }

abstract interface class SacredHourAlarmPermission {
  Future<ExactAlarmPermissionStatus> status();
  Future<bool> request();
}

abstract interface class ExactAlarmPlatformClient {
  Future<bool> canScheduleExactAlarms();
  Future<bool> requestExactAlarmAccess();
}
