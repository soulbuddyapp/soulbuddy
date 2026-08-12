import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_coordinator.dart';
import 'package:soulbuddy/features/prayers/application/browser_prayer_reminder_scheduler.dart';

const _databaseName = 'soulbuddy-reminder-integration.db';
const _identity = LocalIdentity(
  ownerId: 'prayer-reminder-integration-owner',
  deviceId: 'prayer-reminder-integration-device',
);
const _prayerId = '0198c000-0000-7000-8000-000000000001';
const _revisionId = '0198c000-0000-7000-8000-000000000002';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a private reminder and prayer sessions survive a real database reopen',
    (tester) async {
      var now = DateTime.utc(2026, 8, 12, 7, 29);
      final databasePath = await _testDatabasePath();
      final firstContainer = _newContainer(databasePath, () => now);
      final firstDatabase = await firstContainer.read(
        appDatabaseProvider.future,
      );
      await _resetAndSeed(firstDatabase);

      appRouter.go('/prayers/saved/$_prayerId');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const SoulBuddyApp(),
        ),
      );
      final reminderButton = find.byKey(
        const Key('personal-prayer-reminder-control'),
      );
      final enabledReminderButton = find.byWidgetPredicate(
        (widget) =>
            widget is OutlinedButton &&
            widget.key == const Key('personal-prayer-reminder-control') &&
            widget.onPressed != null,
      );
      await _pumpUntil(tester, enabledReminderButton);
      _expectNoException(tester, 'opening the saved prayer');

      await tester.ensureVisible(reminderButton);
      await tester.pump();
      final setReminder = reminderButton.hitTestable();
      expect(setReminder, findsOneWidget);
      await tester.tap(setReminder);
      await _pumpUntil(
        tester,
        find.text('Save reminder'),
        stage: 'opening the reminder sheet',
      );
      final saveReminder = find.text('Save reminder');
      await tester.ensureVisible(saveReminder);
      await tester.pump();
      expect(saveReminder.hitTestable(), findsOneWidget);
      await tester.tap(saveReminder.hitTestable());
      await _pumpUntil(tester, find.text('Every day at 7:30 AM'));
      _expectNoException(tester, 'saving the reminder');

      final reminderRows = await firstDatabase.powersync.getAll(
        'SELECT id, schedule_type, local_time, timezone FROM prayer_reminders '
        'WHERE owner_id = ? AND personal_prayer_id = ?',
        [_identity.ownerId, _prayerId],
      );
      expect(reminderRows, hasLength(1));
      expect(reminderRows.single['schedule_type'], 'daily');
      expect(reminderRows.single['local_time'], '07:30');
      expect(reminderRows.single['timezone'], 'UTC');
      expect(
        await firstDatabase.powersync.getAll(
          'SELECT id FROM prayer_reminder_devices WHERE device_id = ?',
          [_identity.deviceId],
        ),
        hasLength(1),
      );
      await _waitForRow(
        firstDatabase,
        'SELECT next_occurrence_at FROM prayer_reminder_devices '
        'WHERE device_id = ?',
        [_identity.deviceId],
        (row) => row['next_occurrence_at'] == '2026-08-12T07:30:00.000Z',
      );

      now = DateTime.utc(2026, 8, 12, 7, 31);
      final coordinator = await firstContainer.read(
        prayerReminderCoordinatorProvider.future,
      );
      await coordinator.reconcileNow();
      final deviceAfterReconcile = await firstDatabase.powersync.get(
        'SELECT next_occurrence_at, snoozed_until, enabled_on_device '
        'FROM prayer_reminder_devices WHERE device_id = ?',
        [_identity.deviceId],
      );
      expect(
        coordinator.currentDue,
        isNotEmpty,
        reason: 'Device state after reconcile: $deviceAfterReconcile',
      );
      await _pumpUntilCondition(
        tester,
        () =>
            firstContainer
                .read(duePrayerOccurrencesProvider)
                .value
                ?.isNotEmpty ??
            false,
        failure: () =>
            'Coordinator due: ${coordinator.currentDue.length}; '
            'provider: ${firstContainer.read(duePrayerOccurrencesProvider)}',
      );
      await _pumpUntilCondition(
        tester,
        () => find.text('Open prayer').evaluate().isNotEmpty,
        failure: () =>
            'Due card absent. Coordinator due: ${coordinator.currentDue.length}; '
            'provider: ${firstContainer.read(duePrayerOccurrencesProvider)}; '
            'visible: ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).whereType<String>().toList()}',
      );
      expect(find.text('A quiet morning prayer'), findsWidgets);

      await tester.tap(find.text('I prayed this').last);
      await tester.tap(find.text('I prayed this').last);
      await _waitForRow(
        firstDatabase,
        'SELECT id FROM prayer_sessions WHERE owner_id = ? AND source = ?',
        [_identity.ownerId, 'reminder'],
        (_) => true,
      );
      await _pumpUntil(
        tester,
        find.text('Undo').hitTestable(),
        stage: 'Reminder session was stored but actionable Undo',
      );
      expect(find.text('Prayer time recorded'), findsOneWidget);
      final reminderSessions = await firstDatabase.powersync.getAll(
        'SELECT id, prayer_revision_id, retracted_at FROM prayer_sessions '
        'WHERE owner_id = ? AND source = ?',
        [_identity.ownerId, 'reminder'],
      );
      expect(reminderSessions, hasLength(1));
      expect(reminderSessions.single['prayer_revision_id'], _revisionId);
      expect(reminderSessions.single['retracted_at'], isNull);

      await tester.tap(find.text('Undo').hitTestable());
      await tester.pump();
      await _waitForRow(
        firstDatabase,
        'SELECT retracted_at FROM prayer_sessions WHERE id = ?',
        [reminderSessions.single['id']],
        (row) => row['retracted_at'] != null,
      );
      await _pumpUntil(tester, find.text('0 prayer times recorded'));

      await tester.tap(find.text('I prayed this').hitTestable());
      await tester.pump();
      await _waitForRow(
        firstDatabase,
        'SELECT id FROM prayer_sessions WHERE owner_id = ? '
        'AND source = ? AND retracted_at IS NULL',
        [_identity.ownerId, 'manual'],
        (_) => true,
      );
      await _pumpUntil(tester, find.text('1 prayer time recorded'));

      await _closeApp(tester, firstContainer, firstDatabase, coordinator);

      final reopenedContainer = _newContainer(databasePath, () => now);
      final reopenedDatabase = await reopenedContainer.read(
        appDatabaseProvider.future,
      );
      expect(
        await reopenedDatabase.powersync.getAll(
          'SELECT id FROM prayer_reminders WHERE owner_id = ?',
          [_identity.ownerId],
        ),
        hasLength(1),
      );
      expect(
        await reopenedDatabase.powersync.getAll(
          'SELECT id FROM prayer_reminder_devices WHERE device_id = ?',
          [_identity.deviceId],
        ),
        hasLength(1),
      );
      final reopenedSessions = await reopenedDatabase.powersync.getAll(
        'SELECT source, retracted_at FROM prayer_sessions WHERE owner_id = ? '
        'ORDER BY source',
        [_identity.ownerId],
      );
      expect(reopenedSessions, hasLength(2));
      expect(
        reopenedSessions.where(
          (row) => row['source'] == 'manual' && row['retracted_at'] == null,
        ),
        hasLength(1),
      );
      expect(
        reopenedSessions.where(
          (row) => row['source'] == 'reminder' && row['retracted_at'] != null,
        ),
        hasLength(1),
      );

      final reopenedCoordinator = await reopenedContainer.read(
        prayerReminderCoordinatorProvider.future,
      );
      await _closeApp(
        tester,
        reopenedContainer,
        reopenedDatabase,
        reopenedCoordinator,
      );
    },
  );
}

ProviderContainer _newContainer(
  String databasePath,
  DateTime Function() clock,
) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith(
      (ref) => AppDatabase.open(path: databasePath),
    ),
    localIdentityProvider.overrideWith((ref) async => _identity),
    prayerPracticeClockProvider.overrideWithValue(clock),
    prayerDeviceTimezoneProvider.overrideWithValue(() async => 'UTC'),
    prayerReminderSchedulerProvider.overrideWithValue(
      const BrowserPrayerReminderScheduler(),
    ),
  ],
);

Future<void> _resetAndSeed(AppDatabase database) async {
  for (final table in [
    'prayer_sessions',
    'prayer_reminder_devices',
    'prayer_reminders',
    'personal_prayer_revisions',
    'personal_prayers',
  ]) {
    await database.powersync.execute('DELETE FROM $table');
  }
  await database.powersync.execute(
    '''
    INSERT INTO personal_prayers(
      id, owner_id, title, style, reach, grounding, purpose,
      current_revision_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      _prayerId,
      _identity.ownerId,
      'A quiet morning prayer',
      'daily',
      'personal',
      'general_christian',
      'daily',
      _revisionId,
      '2026-08-12T07:00:00.000Z',
      '2026-08-12T07:00:00.000Z',
    ],
  );
  await database.powersync.execute(
    '''
    INSERT INTO personal_prayer_revisions(
      id, prayer_id, owner_id, body, action, created_at, device_id
    ) VALUES (?, ?, ?, ?, NULL, ?, ?)
    ''',
    [
      _revisionId,
      _prayerId,
      _identity.ownerId,
      'Father, keep me near you and ready to love today. Amen.',
      '2026-08-12T07:00:00.000Z',
      _identity.deviceId,
    ],
  );
}

Future<void> _closeApp(
  WidgetTester tester,
  ProviderContainer container,
  AppDatabase database,
  PrayerReminderCoordinator coordinator,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final worker = await _awaitStage(
    'reading the prayer worker during close',
    container.read(prayerGenerationWorkerProvider.future),
  );
  await _awaitStage('disposing the prayer worker', worker.dispose());
  container.dispose();
  await tester.pump();
  await _awaitStage(
    'disposing the reminder coordinator',
    coordinator.dispose(),
  );
  await _drainAsyncDisposals(tester);
  await _awaitStage(
    'draining the database before close',
    database.powersync.get('SELECT 1 AS ready'),
  );
  await _awaitStage('closing the database', database.close());
}

Future<void> _drainAsyncDisposals(WidgetTester tester) async {
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
    await tester.pump();
  }
}

Future<T> _awaitStage<T>(String stage, Future<T> future) => future.timeout(
  const Duration(seconds: 15),
  onTimeout: () => throw TestFailure('Timed out while $stage.'),
);

Future<String> _testDatabasePath() async {
  if (kIsWeb) return _databaseName;
  final directory = await getApplicationSupportDirectory();
  return path.join(directory.path, _databaseName);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  String? stage,
}) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  if (finder.evaluate().isEmpty) {
    final exception = tester.takeException();
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    fail(
      '${stage ?? 'Expected UI'} did not appear. '
      'Exception: $exception. Visible text: $visibleText',
    );
  }
}

Future<void> _waitForRow(
  AppDatabase database,
  String sql,
  List<Object?> parameters,
  bool Function(Map<String, dynamic>) predicate,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final row = await database.powersync.getOptional(sql, parameters);
    if (row != null && predicate(row)) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Expected database state was not reached.');
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  required String Function() failure,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
  fail(failure());
}

void _expectNoException(WidgetTester tester, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
}
