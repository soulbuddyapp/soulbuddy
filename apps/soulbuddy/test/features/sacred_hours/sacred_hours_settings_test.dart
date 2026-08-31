import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_sound_player.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hour_editor_sheet.dart';
import 'package:soulbuddy/features/sacred_hours/presentation/sacred_hours_settings_section.dart';

void main() {
  testWidgets('keeps Sacred Hour management compact', (tester) async {
    var added = false;
    SacredHour? edited;
    bool? enabled;
    String? archived;
    final hour = _hour();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SacredHoursSettingsSection(
              hours: [hour],
              onAdd: () async => added = true,
              onEdit: (value) async => edited = value,
              onEnabledChanged: (value, next) async => enabled = next,
              onArchive: (value) async => archived = value.id,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sacred Hours'), findsOneWidget);
    expect(find.text('Morning Sacred Hour'), findsOneWidget);
    expect(find.text('6:00–7:00am · 15 min prayer'), findsOneWidget);
    expect(find.text('Gentle Chime'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sacred-hour-enabled-hour-1')));
    expect(enabled, isFalse);
    await tester.tap(find.byKey(const Key('sacred-hour-edit-hour-1')));
    expect(edited, hour);
    await tester.tap(find.byKey(const Key('sacred-hour-archive-hour-1')));
    expect(archived, 'hour-1');
    await tester.tap(find.text('Add Sacred Hour'));
    expect(added, isTrue);
  });

  testWidgets('editor keeps secondary choices in one scroll-safe sheet', (
    tester,
  ) async {
    SacredHourEditorValue? saved;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourEditorSheet(
            timezone: 'Africa/Lagos',
            existingHours: const [],
            prayers: const [],
            people: const [],
            soundsEnabled: true,
            player: _Player(),
            reminderMode: SacredHourReminderMode.ordinary,
            onSave: (value) async => saved = value,
          ),
        ),
      ),
    );

    expect(find.text('Add Sacred Hour'), findsOneWidget);
    expect(find.text('Prayer opening'), findsOneWidget);
    expect(find.text('Prayer (optional)'), findsOneWidget);
    expect(find.text('Person (optional)'), findsOneWidget);
    await tester.ensureVisible(find.text('30 min').first);
    await tester.tap(find.text('30 min').first);
    await tester.scrollUntilVisible(
      find.text('Reminder timing'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reminder timing'), findsOneWidget);
    expect(find.text('Ordinary'), findsOneWidget);
    expect(find.text('More precise timing'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('sacred-hour-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('sacred-hour-save')));
    await tester.pumpAndSettle();
    expect(saved?.prayerMinutes, 30);
  });

  testWidgets('precise timing shows ordinary fallback and Retry when denied', (
    tester,
  ) async {
    var requests = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SacredHourEditorSheet(
            timezone: 'Africa/Lagos',
            existingHours: const [],
            prayers: const [],
            people: const [],
            soundsEnabled: true,
            player: _Player(),
            reminderMode: SacredHourReminderMode.ordinary,
            onRequestPrecise: () async {
              requests += 1;
              return false;
            },
            onSave: (_) async {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('More precise timing'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('More precise timing'));
    await tester.pump();
    expect(requests, 1);
    expect(
      find.text('Using an ordinary reminder until access is allowed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(requests, 2);
  });
}

SacredHour _hour() => SacredHour(
  id: 'hour-1',
  ownerId: 'owner',
  purpose: SacredHourPurpose.morning,
  name: 'Morning Sacred Hour',
  localTime: PrayerLocalTime(hour: 6, minute: 0),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Player implements SacredHourSoundPlayer {
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play(SacredHourSound sound) async {}
  @override
  Future<void> stop() async {}
}
