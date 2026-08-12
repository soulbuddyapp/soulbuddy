import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_reminder_card.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';

void main() {
  testWidgets('shows a compact private card without blocking navigation', (
    tester,
  ) async {
    final occurrence = _occurrence();
    var navigationTaps = 0;
    await tester.pumpWidget(
      _app(
        occurrence,
        body: Align(
          alignment: Alignment.topCenter,
          child: TextButton(
            onPressed: () => navigationTaps++,
            child: const Text('Keep navigating'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evening prayer'), findsOneWidget);
    expect(find.text('Father, keep this private body hidden.'), findsNothing);
    expect(find.text('Open prayer'), findsOneWidget);
    expect(find.text('I prayed this'), findsOneWidget);
    expect(find.text('Snooze 10 minutes'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.textContaining('Listen'), findsNothing);
    await tester.tap(find.text('Keep navigating'));
    expect(navigationTaps, 1);
  });

  testWidgets(
    'passes the immutable occurrence identity and offers exact undo',
    (tester) async {
      final occurrence = _occurrence();
      final actions = <(String, String, String, PrayerReminderAction)>[];
      final retractions = <String>[];
      await tester.pumpWidget(
        _app(
          occurrence,
          perform: (value, action) async {
            actions.add((
              value.reminder.personalPrayerId,
              value.prayerRevisionId,
              value.occurrenceKey,
              action,
            ));
            return action == PrayerReminderAction.prayed ? _session() : null;
          },
          retract: (id) async => retractions.add(id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I prayed this'));
      await tester.pumpAndSettle();
      expect(actions.single, (
        'prayer-1',
        'revision-1',
        occurrence.occurrenceKey,
        PrayerReminderAction.prayed,
      ));
      expect(find.text('Prayer time recorded'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(retractions, ['session-1']);
    },
  );

  testWidgets('snooze and dismiss hide only the displayed occurrence', (
    tester,
  ) async {
    final occurrence = _occurrence();
    final due = StreamController<List<DuePrayerOccurrence>>();
    final actions = <PrayerReminderAction>[];
    await tester.pumpWidget(
      _app(
        occurrence,
        due: due.stream,
        perform: (value, action) async {
          actions.add(action);
          due.add(const []);
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Snooze 10 minutes'));
    await tester.pumpAndSettle();
    expect(actions, [PrayerReminderAction.snoozeTenMinutes]);
    expect(find.text('Evening prayer'), findsNothing);
  });

  testWidgets('double taps make one private session write', (tester) async {
    final occurrence = _occurrence();
    final pending = Completer<PrayerSession?>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        occurrence,
        perform: (value, action) {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I prayed this'));
    await tester.tap(find.text('I prayed this'));
    await tester.pump();
    expect(calls, 1);
    pending.complete(_session());
    await tester.pumpAndSettle();
  });

  testWidgets('undo failure stays generic and recoverable', (tester) async {
    final occurrence = _occurrence();
    await tester.pumpWidget(
      _app(
        occurrence,
        perform: (value, action) async => _session(),
        retract: (id) => throw StateError('private database detail'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I prayed this'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not undo this prayer record just now.'),
      findsOneWidget,
    );
    expect(find.textContaining('private database detail'), findsNothing);
  });

  testWidgets('offers Undo after the completed action removes the due card', (
    tester,
  ) async {
    final occurrence = _occurrence();
    final due = StreamController<List<DuePrayerOccurrence>>();
    final completion = Completer<PrayerSession?>();
    await tester.pumpWidget(
      _app(
        occurrence,
        due: due.stream,
        perform: (value, action) => completion.future,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I prayed this'));
    due.add(const []);
    await tester.pump();
    expect(find.text('Evening prayer'), findsNothing);
    completion.complete(_session());
    await tester.pumpAndSettle();

    expect(find.text('Prayer time recorded'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('keeps Undo actionable at the compact app viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final occurrence = _occurrence();
    final due = StreamController<List<DuePrayerOccurrence>>();
    final retractions = <String>[];
    await tester.pumpWidget(
      _compactApp(
        occurrence,
        due: due.stream,
        perform: (value, action) async {
          due.add(const []);
          return _session();
        },
        retract: (id) async => retractions.add(id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I prayed this'));
    await tester.pumpAndSettle();

    expect(find.text('Undo').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Undo').hitTestable());
    await tester.pumpAndSettle();
    expect(retractions, ['session-1']);
  });
}

Widget _app(
  DuePrayerOccurrence occurrence, {
  Widget body = const SizedBox.expand(),
  Stream<List<DuePrayerOccurrence>>? due,
  Future<PrayerSession?> Function(DuePrayerOccurrence, PrayerReminderAction)?
  perform,
  Future<void> Function(String)? retract,
}) => ProviderScope(
  overrides: [
    duePrayerOccurrencesProvider.overrideWith((ref) async* {
      yield [occurrence];
      if (due != null) yield* due;
    }),
    prayerReminderActionProvider.overrideWithValue(
      perform ?? (value, action) async => null,
    ),
    prayerSessionRetractorProvider.overrideWithValue(retract ?? (id) async {}),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          body,
          const Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: PrayerReminderCardHost(),
          ),
        ],
      ),
    ),
  ),
);

Widget _compactApp(
  DuePrayerOccurrence occurrence, {
  required Stream<List<DuePrayerOccurrence>> due,
  required Future<PrayerSession?> Function(
    DuePrayerOccurrence,
    PrayerReminderAction,
  )
  perform,
  required Future<void> Function(String) retract,
}) => ProviderScope(
  overrides: [
    duePrayerOccurrencesProvider.overrideWith((ref) async* {
      yield [occurrence];
      yield* due;
    }),
    prayerReminderActionProvider.overrideWithValue(perform),
    prayerSessionRetractorProvider.overrideWithValue(retract),
  ],
  child: MaterialApp(
    builder: (context, child) => Stack(
      fit: StackFit.expand,
      children: [
        child ?? const SizedBox.shrink(),
        const Positioned(
          left: 12,
          right: 12,
          bottom: 92,
          child: PrayerReminderCardHost(),
        ),
      ],
    ),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Prayers'),
        ],
      ),
    ),
  ),
);

DuePrayerOccurrence _occurrence() {
  final at = DateTime.utc(2026, 8, 11, 18);
  return DuePrayerOccurrence(
    reminder: PrayerReminder(
      id: 'reminder-1',
      ownerId: 'owner-1',
      personalPrayerId: 'prayer-1',
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 19, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enabled: true,
      createdAt: at,
      updatedAt: at,
    ),
    device: PrayerReminderDevice(
      id: 'device-row-1',
      reminderId: 'reminder-1',
      deviceId: 'device-1',
      enabledOnDevice: true,
      nextOccurrenceAt: at,
      platformNotificationId: 77,
      scheduledTimezone: 'Africa/Lagos',
      updatedAt: at,
    ),
    prayerTitle: 'Evening prayer',
    prayerBody: 'Father, keep this private body hidden.',
    prayerRevisionId: 'revision-1',
    occurrenceAt: at,
  );
}

PrayerSession _session() => PrayerSession(
  id: 'session-1',
  ownerId: 'owner-1',
  personalPrayerId: 'prayer-1',
  prayerRevisionId: 'revision-1',
  reminderId: 'reminder-1',
  reminderOccurrenceKey: 'reminder-1@2026-08-11T18:00:00.000Z',
  source: PrayerSessionSource.reminder,
  occurredAt: DateTime.utc(2026, 8, 11, 18),
  localDate: DateTime(2026, 8, 11),
  timezone: 'Africa/Lagos',
  deviceId: 'device-1',
);
