import 'sacred_hour_alarm_permission.dart';

class WebSacredHourAlarmPermission implements SacredHourAlarmPermission {
  const WebSacredHourAlarmPermission();

  @override
  Future<ExactAlarmPermissionStatus> status() async =>
      ExactAlarmPermissionStatus.unsupported;

  @override
  Future<bool> request() async => false;
}

SacredHourAlarmPermission createSacredHourAlarmPermission() =>
    const WebSacredHourAlarmPermission();
