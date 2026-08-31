import 'sacred_hour_alarm_permission.dart';
import 'sacred_hour_alarm_permission_web.dart'
    if (dart.library.io) 'sacred_hour_alarm_permission_io.dart'
    as platform;

SacredHourAlarmPermission createSacredHourAlarmPermission() =>
    platform.createSacredHourAlarmPermission();
