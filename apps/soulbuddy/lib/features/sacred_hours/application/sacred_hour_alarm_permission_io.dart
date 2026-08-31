import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'sacred_hour_alarm_permission.dart';

class NativeSacredHourAlarmPermission implements SacredHourAlarmPermission {
  NativeSacredHourAlarmPermission({
    ExactAlarmPlatformClient? client,
    bool? isAndroid,
  }) : _client = client ?? FlutterExactAlarmPlatformClient(),
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final ExactAlarmPlatformClient _client;
  final bool _isAndroid;

  @override
  Future<ExactAlarmPermissionStatus> status() async {
    if (!_isAndroid) return ExactAlarmPermissionStatus.unsupported;
    return await _client.canScheduleExactAlarms()
        ? ExactAlarmPermissionStatus.granted
        : ExactAlarmPermissionStatus.denied;
  }

  @override
  Future<bool> request() async {
    if (!_isAndroid) return false;
    if (await _client.canScheduleExactAlarms()) return true;
    return _client.requestExactAlarmAccess();
  }
}

class FlutterExactAlarmPlatformClient implements ExactAlarmPlatformClient {
  FlutterExactAlarmPlatformClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> canScheduleExactAlarms() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<bool> requestExactAlarmAccess() async =>
      await _android?.requestExactAlarmsPermission() ?? false;
}

SacredHourAlarmPermission createSacredHourAlarmPermission() =>
    NativeSacredHourAlarmPermission();
