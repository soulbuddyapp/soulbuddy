import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soulbuddy/features/prayers/application/native_prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';

const _notificationId = 94701;
const _reminderId = '0198c100-0000-7000-8000-000000000001';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native reminder exposes a private actionable notification', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final scheduler = NativePrayerReminderScheduler(
      client: FlutterLocalNotificationsPrayerClient(),
    );
    await scheduler.initialize();
    await scheduler.cancel(_notificationId);
    expect(await scheduler.requestPermission(), isTrue);

    final scheduledAt = DateTime.now().toUtc().add(const Duration(seconds: 8));
    final occurrenceKey = '$_reminderId@${scheduledAt.toIso8601String()}';
    final response = scheduler.responses.first.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw TestFailure(
        'The native prayer reminder action was not received.',
      ),
    );
    await scheduler.schedule(
      PrayerScheduledNotification(
        platformNotificationId: _notificationId,
        reminderId: _reminderId,
        occurrenceKey: occurrenceKey,
        scheduledAtUtc: scheduledAt,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Android reminder ready'))),
      ),
    );
    await tester.pump();

    final action = await response;
    expect(action.action, PrayerReminderAction.prayed);
    expect(action.reminderId, _reminderId);
    expect(action.occurrenceKey, occurrenceKey);
    await scheduler.cancel(_notificationId);
  });
}
