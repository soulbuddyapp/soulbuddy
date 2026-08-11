import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';
import 'package:soulbuddy/features/prayers/presentation/personal_prayer_detail_screen.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('offers reminder choices and a quiet prayer action at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PracticeRepository();
      final enablements = <String>[];
      await tester.pumpWidget(
        _app(
          repository,
          enableDevice: (id) async {
            expect(repository.saveCalls, 1);
            enablements.add(id);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set reminder'), findsOneWidget);
      expect(find.text('I prayed this'), findsOneWidget);
      await tester.tap(find.text('Set reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Once'), findsOneWidget);
      expect(find.text('Every day'), findsOneWidget);
      expect(find.text('Selected days'), findsOneWidget);
      expect(find.byKey(const Key('prayer-reminder-time')), findsOneWidget);
      expect(find.text('Save reminder'), findsOneWidget);
      expect(find.byKey(const Key('prayer-reminder-weekdays')), findsNothing);

      await tester.tap(find.text('Selected days'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prayer-reminder-weekdays')), findsOneWidget);
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(enablements, ['reminder-1']);
      expect(repository.callOrder, ['save']);
      expect(find.text('Reminder saved on this device'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reopens an existing schedule populated', (tester) async {
    final repository = _PracticeRepository();
    final existing = _reminder(
      PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 7, minute: 30),
        timezone: 'Africa/Lagos',
      ),
    );
    await tester.pumpWidget(_app(repository, reminder: existing));
    await tester.pumpAndSettle();

    expect(find.text('Every day at 7:30 AM'), findsOneWidget);
    await tester.tap(find.text('Every day at 7:30 AM'));
    await tester.pumpAndSettle();

    final everyDay = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Every day'),
    );
    expect(everyDay.selected, isTrue);
    expect(find.text('7:30 AM'), findsOneWidget);
  });

  testWidgets(
    'validates selected days before saving or requesting permission',
    (tester) async {
      final repository = _PracticeRepository();
      var enableCalls = 0;
      await tester.pumpWidget(
        _app(
          repository,
          enableDevice: (id) async {
            enableCalls++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected days'));
      await tester.pumpAndSettle();
      final selectedChip = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .singleWhere((chip) => chip.selected);
      await tester.tap(find.byWidget(selectedChip));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Choose at least one day.'), findsOneWidget);
      expect(repository.saveCalls, 0);
      expect(enableCalls, 0);
    },
  );

  testWidgets('keeps the saved reminder when device enablement fails', (
    tester,
  ) async {
    final repository = _PracticeRepository();
    await tester.pumpWidget(
      _app(
        repository,
        enableDevice: (id) => throw StateError('private platform detail'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      find.text('Reminder saved. Notification could not be enabled just now.'),
      findsOneWidget,
    );
    expect(find.textContaining('private platform detail'), findsNothing);
  });

  testWidgets(
    'records the displayed revision once and retracts exact session',
    (tester) async {
      final repository = _PracticeRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I prayed this'));
      await tester.pumpAndSettle();

      expect(repository.recordedRevisionIds, ['revision-1']);
      expect(find.text('1 prayer time recorded'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.retractedSessionIds, ['session-1']);
    },
  );

  testWidgets(
    'blocks duplicate writes and uses generic recoverable error copy',
    (tester) async {
      final repository = _PracticeRepository()..holdRecord = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final action = find.text('I prayed this');

      await tester.tap(action);
      await tester.tap(action);
      await tester.pump();
      expect(repository.recordAttempts, 1);
      repository.completeRecordError();
      await tester.pumpAndSettle();

      expect(
        find.text('Could not record this prayer just now.'),
        findsOneWidget,
      );
      expect(find.textContaining('temporary private failure'), findsNothing);
    },
  );

  testWidgets('shows forty as plain private history without gamification', (
    tester,
  ) async {
    final repository = _PracticeRepository(initialCount: 40);
    await tester.pumpWidget(
      _app(repository, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('40 prayer times recorded'), findsOneWidget);
    expect(find.textContaining('streak', findRichText: true), findsNothing);
    expect(find.textContaining('score', findRichText: true), findsNothing);
    expect(find.textContaining('Publish', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  _PracticeRepository repository, {
  PrayerReminder? reminder,
  Future<bool> Function(String)? enableDevice,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final prayer = PersonalPrayer(
    id: 'prayer-1',
    ownerId: 'owner-1',
    title: 'Prayer for this day',
    style: 'daily',
    reach: 'personal',
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.daily,
    currentRevisionId: 'revision-1',
    body: 'Father, keep me near you and ready to love today. Amen.',
    createdAt: _date,
    updatedAt: _date,
  );
  return ProviderScope(
    overrides: [
      personalPrayerProvider(
        prayer.id,
      ).overrideWith((ref) => Stream.value(prayer)),
      prayerPracticeRepositoryProvider.overrideWith((ref) async => repository),
      prayerReminderProvider(
        prayer.id,
      ).overrideWith((ref) => Stream.value(reminder)),
      prayerSessionCountProvider(
        prayer.currentRevisionId,
      ).overrideWith((ref) => repository.counts),
      prayerDeviceTimezoneProvider.overrideWithValue(
        () async => 'Africa/Lagos',
      ),
      prayerReminderDeviceEnablerProvider.overrideWithValue(
        enableDevice ?? (id) async => true,
      ),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const Scaffold(
          body: PersonalPrayerDetailScreen(prayerId: 'prayer-1'),
        ),
      ),
    ),
  );
}

final _date = DateTime(2026, 8, 11);

PrayerReminder _reminder(PrayerReminderSchedule schedule) => PrayerReminder(
  id: 'reminder-1',
  ownerId: 'owner-1',
  personalPrayerId: 'prayer-1',
  schedule: schedule,
  enabled: true,
  createdAt: _date,
  updatedAt: _date,
);

class _PracticeRepository implements PrayerPracticeRepository {
  _PracticeRepository({int initialCount = 0}) : _count = initialCount {
    _counts.add(initialCount);
  }

  final _counts = StreamController<int>.broadcast();
  int _count;
  int saveCalls = 0;
  int recordAttempts = 0;
  bool holdRecord = false;
  Completer<PrayerSession>? _recordCompleter;
  final callOrder = <String>[];
  final recordedRevisionIds = <String>[];
  final retractedSessionIds = <String>[];

  Stream<int> get counts async* {
    yield _count;
    yield* _counts.stream;
  }

  void completeRecordError() {
    _recordCompleter?.completeError(StateError('temporary private failure'));
  }

  @override
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  }) async {
    saveCalls++;
    callOrder.add('save');
    expect(enableOnThisDevice, isFalse);
    return _reminder(schedule);
  }

  @override
  Future<PrayerSession> recordSession({
    required String personalPrayerId,
    required String revisionId,
    required String timezone,
    String? reminderId,
    String? occurrenceKey,
  }) async {
    recordAttempts++;
    recordedRevisionIds.add(revisionId);
    if (holdRecord) {
      _recordCompleter = Completer<PrayerSession>();
      return _recordCompleter!.future;
    }
    _count++;
    _counts.add(_count);
    return _session();
  }

  @override
  Future<void> retractSession(String sessionId) async {
    retractedSessionIds.add(sessionId);
    _count--;
    _counts.add(_count);
  }

  PrayerSession _session() => PrayerSession(
    id: 'session-1',
    ownerId: 'owner-1',
    personalPrayerId: 'prayer-1',
    prayerRevisionId: 'revision-1',
    source: PrayerSessionSource.manual,
    occurredAt: _date,
    localDate: _date,
    timezone: 'Africa/Lagos',
    deviceId: 'device-1',
  );

  @override
  Stream<PrayerReminder?> watchReminder(String personalPrayerId) =>
      const Stream.empty();
  @override
  Stream<PrayerReminderDevice?> watchDevice(String reminderId) =>
      const Stream.empty();
  @override
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc) =>
      const Stream.empty();
  @override
  Stream<int> watchSessionCount(String revisionId) => counts;
  @override
  Future<void> archiveReminder(String reminderId) async {}
  @override
  Future<void> setDeviceEnabled(
    String reminderId, {
    required bool enabled,
  }) async {}
  @override
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  }) async {}
  @override
  Future<void> snooze(String reminderId, DateTime untilUtc) async {}
  @override
  Future<void> dismiss(String reminderId, String occurrenceKey) async {}
}
