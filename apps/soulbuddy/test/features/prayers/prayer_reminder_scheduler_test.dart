import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/browser_prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/application/native_prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

void main() {
  test(
    'schedules one generic inexact notification with private payload',
    () async {
      final client = _FakeNativeNotificationClient();
      final scheduler = NativePrayerReminderScheduler(client: client);

      await scheduler.initialize();
      expect(
        await scheduler.permissionStatus(),
        NotificationPermissionStatus.granted,
      );
      expect(await scheduler.requestPermission(), isTrue);
      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: 123,
          reminderId: '0198aa00-0000-7000-8000-000000000001',
          occurrenceKey:
              '0198aa00-0000-7000-8000-000000000001@2026-08-12T06:30:00.000Z',
          scheduledAtUtc: DateTime.utc(2026, 8, 12, 6, 30),
        ),
      );

      expect(client.initializeCalls, 1);
      expect(client.permissionCalls, 1);
      final request = client.requests.single;
      expect(request.title, 'Prayer reminder');
      expect(request.body, 'Time set aside for prayer');
      expect(
        request.scheduleMode,
        NativePrayerScheduleMode.inexactAllowWhileIdle,
      );
      expect(request.startsAudio, isFalse);
      expect(jsonDecode(request.payload), {
        'reminder_id': '0198aa00-0000-7000-8000-000000000001',
        'occurrence_key':
            '0198aa00-0000-7000-8000-000000000001@2026-08-12T06:30:00.000Z',
        'kind': 'prayer',
      });
      expect(request.actions.map((action) => action.id), [
        'PRAYED',
        'SNOOZE_10',
        'DISMISS',
      ]);
      expect(
        request.actions.every((action) => action.showsUserInterface),
        isTrue,
      );
      await scheduler.showTestReminder();
      final testRequest = client.immediateRequests.single;
      expect(testRequest.title, 'Prayer reminder');
      expect(testRequest.body, 'Your reminders are ready on this device');
      expect(testRequest.startsAudio, isFalse);
      expect(testRequest.payload, isNull);
    },
  );

  test(
    'schedules an Altar reminder with private copy and open action',
    () async {
      final client = _FakeNativeNotificationClient();
      final scheduler = NativePrayerReminderScheduler(client: client);

      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: 321,
          reminderId: 'altar-ritual-1',
          occurrenceKey: 'altar-ritual-1@2026-08-27T06:30:00.000Z',
          scheduledAtUtc: DateTime.utc(2026, 8, 27, 6, 30),
          kind: ReminderNotificationKind.altar,
        ),
      );

      final request = client.requests.single;
      expect(request.title, 'At your Altar');
      expect(request.body, 'Time set aside to pray and remember');
      expect(request.actions, isEmpty);
      expect(jsonDecode(request.payload)['kind'], 'altar');
    },
  );

  test(
    'schedules a private Sacred Hour invitation with sound and precision',
    () async {
      final client = _FakeNativeNotificationClient();
      final scheduler = NativePrayerReminderScheduler(client: client);

      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: 400,
          reminderId: 'sacred-hour-1',
          occurrenceKey: 'sacred-hour-1@2026-08-31T05:00:00.000Z',
          scheduledAtUtc: DateTime.utc(2026, 8, 31, 5),
          kind: ReminderNotificationKind.sacredHour,
          soundKey: 'sacred_gentle_chime',
        ),
      );
      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: 401,
          reminderId: 'sacred-hour-2',
          occurrenceKey: 'sacred-hour-2@2026-08-31T21:00:00.000Z',
          scheduledAtUtc: DateTime.utc(2026, 8, 31, 21),
          kind: ReminderNotificationKind.sacredHour,
          soundKey: 'silent',
          precision: ReminderSchedulePrecision.exact,
        ),
      );
      await scheduler.schedule(
        PrayerScheduledNotification(
          platformNotificationId: 402,
          reminderId: 'sacred-hour-3',
          occurrenceKey: 'sacred-hour-3@2026-09-01T05:00:00.000Z',
          scheduledAtUtc: DateTime.utc(2026, 9, 1, 5),
          kind: ReminderNotificationKind.sacredHour,
          soundKey: 'device',
        ),
      );

      final gentle = client.requests[0];
      expect(gentle.title, 'Your Sacred Hour');
      expect(gentle.body, 'Begin with prayer. Bring this hour before God.');
      expect(gentle.payload, isNot(contains('prayer')));
      expect(
        gentle.scheduleMode,
        NativePrayerScheduleMode.inexactAllowWhileIdle,
      );
      expect(gentle.playSound, isTrue);
      expect(gentle.soundKey, 'sacred_gentle_chime');
      expect(gentle.actions.map((action) => (action.id, action.label)), [
        ('BEGIN', 'Begin'),
        ('SNOOZE_10', 'In 10 minutes'),
        ('DISMISS', 'Not now'),
      ]);

      final silent = client.requests[1];
      expect(silent.scheduleMode, NativePrayerScheduleMode.exactAllowWhileIdle);
      expect(silent.playSound, isFalse);
      expect(silent.soundKey, isNull);

      final device = client.requests[2];
      expect(device.playSound, isTrue);
      expect(device.soundKey, isNull);
    },
  );

  test('maps native taps and actions into private domain responses', () async {
    final client = _FakeNativeNotificationClient();
    final scheduler = NativePrayerReminderScheduler(client: client);
    await scheduler.initialize();
    final responses = <PrayerReminderResponse>[];
    final subscription = scheduler.responses.listen(responses.add);
    addTearDown(subscription.cancel);

    for (final actionId in [null, 'PRAYED', 'SNOOZE_10', 'DISMISS']) {
      client.emit(
        NativeNotificationResponseData(
          actionId: actionId,
          payload: jsonEncode({
            'reminder_id': 'reminder-1',
            'occurrence_key': 'reminder-1@2026-08-12T06:30:00.000Z',
          }),
        ),
      );
    }
    await pumpEventQueue();

    expect(responses.map((response) => response.action), [
      PrayerReminderAction.open,
      PrayerReminderAction.prayed,
      PrayerReminderAction.snoozeTenMinutes,
      PrayerReminderAction.dismiss,
    ]);
    expect(
      responses.every(
        (response) =>
            response.reminderId == 'reminder-1' &&
            response.occurrenceKey == 'reminder-1@2026-08-12T06:30:00.000Z',
      ),
      isTrue,
    );
  });

  test('decodes Sacred Hour Begin and Not now responses', () async {
    final client = _FakeNativeNotificationClient();
    final scheduler = NativePrayerReminderScheduler(client: client);
    final responses = <PrayerReminderResponse>[];
    final subscription = scheduler.responses.listen(responses.add);
    addTearDown(subscription.cancel);
    final payload = jsonEncode({
      'reminder_id': 'sacred-hour-1',
      'occurrence_key': 'sacred-hour-1@2026-08-31T05:00:00.000Z',
      'kind': 'sacredHour',
    });

    client.emit(
      NativeNotificationResponseData(actionId: 'BEGIN', payload: payload),
    );
    client.emit(
      NativeNotificationResponseData(actionId: 'DISMISS', payload: payload),
    );
    await pumpEventQueue();

    expect(responses.map((response) => response.kind), [
      ReminderNotificationKind.sacredHour,
      ReminderNotificationKind.sacredHour,
    ]);
    expect(responses.map((response) => response.action), [
      PrayerReminderAction.begin,
      PrayerReminderAction.dismiss,
    ]);
  });

  test('rejects notification payloads with private or unknown keys', () async {
    final client = _FakeNativeNotificationClient();
    final scheduler = NativePrayerReminderScheduler(client: client);
    await scheduler.initialize();
    final error = expectLater(
      scheduler.responses,
      emitsError(isA<FormatException>()),
    );

    client.emit(
      NativeNotificationResponseData(
        actionId: 'PRAYED',
        payload: jsonEncode({
          'reminder_id': 'reminder-1',
          'occurrence_key': 'occurrence-1',
          'prayer_body': 'must never be accepted',
        }),
      ),
    );

    await error;
  });

  test('browser scheduler keeps permission and delivery in app', () async {
    final scheduler = BrowserPrayerReminderScheduler();

    await scheduler.initialize();
    expect(await scheduler.requestPermission(), isFalse);
    expect(
      await scheduler.permissionStatus(),
      NotificationPermissionStatus.unsupported,
    );
    await scheduler.showTestReminder();
    await scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: 1,
        reminderId: 'reminder-1',
        occurrenceKey: 'occurrence-1',
        scheduledAtUtc: DateTime.utc(2026, 8, 12),
      ),
    );
    await scheduler.cancel(1);

    expect(scheduler.responses, emitsDone);
  });
}

class _FakeNativeNotificationClient implements NativePrayerNotificationClient {
  final _responses =
      StreamController<NativeNotificationResponseData>.broadcast();
  final requests = <NativeNotificationRequest>[];
  final immediateRequests = <NativeImmediateNotificationRequest>[];
  int initializeCalls = 0;
  int permissionCalls = 0;

  @override
  Stream<NativeNotificationResponseData> get responses => _responses.stream;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return true;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<void> showImmediate(NativeImmediateNotificationRequest request) async {
    immediateRequests.add(request);
  }

  @override
  Future<void> schedule(NativeNotificationRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> cancel(int platformNotificationId) async {}

  void emit(NativeNotificationResponseData response) {
    _responses.add(response);
  }
}
