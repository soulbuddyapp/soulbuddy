import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:soulbuddy/features/prayers/application/bundled_prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/presentation/bundled_prayer_reminder_control.dart';
import 'package:soulbuddy/features/prayers/providers/bundled_prayer_reminder_providers.dart';
import 'bundled_prayer_reminder_test.dart' as helpers;

void main() {
  testWidgets('sets a daily reminder from a built-in prayer', (tester) async {
    tzdata.initializeTimeZones();
    String? saved;
    final prayer =
        (jsonDecode(
                  File('assets/content/prayer_library.json').readAsStringSync(),
                )
                as Map)['prayers'][0]
            as Map;
    final scheduler = helpers.Scheduler();
    final service = BundledPrayerReminder(
      scheduler: scheduler,
      read: () async => saved,
      write: (v) async => saved = v,
      timezoneName: () async => 'UTC',
      clock: () => DateTime.utc(2026, 11, 18, 7),
    );
    await service.start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundledPrayerReminderProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BundledPrayerReminderControl(
              prayerId: '0198a100-0000-7000-8000-000000000001',
              body: prayer['body'] as String,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set daily reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scheduler.requests.single.soundKey, 'builtin_prayer_01');
    expect(find.text('Remove reminder'), findsOneWidget);
    expect(find.text('Prayer audio'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(scheduler.requests.last.soundKey, 'silent');
  });
}
