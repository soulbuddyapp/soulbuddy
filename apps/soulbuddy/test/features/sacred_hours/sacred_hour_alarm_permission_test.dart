import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_alarm_permission.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_alarm_permission_io.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_alarm_permission_web.dart';

void main() {
  test('Android reports and requests revocable exact-alarm access', () async {
    final client = _FakeExactAlarmClient(
      canSchedule: false,
      requestResult: true,
    );
    final permission = NativeSacredHourAlarmPermission(
      client: client,
      isAndroid: true,
    );

    expect(await permission.status(), ExactAlarmPermissionStatus.denied);
    expect(await permission.request(), isTrue);
    expect(client.statusCalls, 2);
    expect(client.requestCalls, 1);
  });

  test('Android keeps a granted capability without opening settings', () async {
    final client = _FakeExactAlarmClient(
      canSchedule: true,
      requestResult: false,
    );
    final permission = NativeSacredHourAlarmPermission(
      client: client,
      isAndroid: true,
    );

    expect(await permission.status(), ExactAlarmPermissionStatus.granted);
    expect(await permission.request(), isTrue);
    expect(client.requestCalls, 0);
  });

  test('iOS and web expose precise alarms as unsupported', () async {
    final native = NativeSacredHourAlarmPermission(
      client: _FakeExactAlarmClient(canSchedule: true, requestResult: true),
      isAndroid: false,
    );
    const web = WebSacredHourAlarmPermission();

    expect(await native.status(), ExactAlarmPermissionStatus.unsupported);
    expect(await native.request(), isFalse);
    expect(await web.status(), ExactAlarmPermissionStatus.unsupported);
    expect(await web.request(), isFalse);
  });

  test('Android requests only revocable exact-alarm special access', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
    expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
    expect(
      manifest,
      isNot(contains('android.permission.USE_FULL_SCREEN_INTENT')),
    );
  });
}

class _FakeExactAlarmClient implements ExactAlarmPlatformClient {
  _FakeExactAlarmClient({
    required this.canSchedule,
    required this.requestResult,
  });

  final bool canSchedule;
  final bool requestResult;
  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<bool> canScheduleExactAlarms() async {
    statusCalls++;
    return canSchedule;
  }

  @override
  Future<bool> requestExactAlarmAccess() async {
    requestCalls++;
    return requestResult;
  }
}
