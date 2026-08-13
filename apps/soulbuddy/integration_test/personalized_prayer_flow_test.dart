import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/prayers/data/laravel_prayer_draft_api.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';

const _databaseName = 'soulbuddy-personalized-prayer-integration.db';
const _sessionToken = 'integration-session-token';
const _identity = LocalIdentity(
  ownerId: 'personalized-prayer-integration-owner',
  deviceId: 'personalized-prayer-integration-device',
);
const _encounterId = '019c0000-0000-7000-8000-000000000001';
const _encounterRevisionId = '019c0000-0000-7000-8000-000000000002';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a private personalized prayer survives offline queue and database reopen',
    (tester) async {
      final databasePath = await _testDatabasePath();
      final endpoint = _FakeAuthenticatedLaravelDraftEndpoint();
      final firstContainer = _newContainer(databasePath, endpoint);
      final firstDatabase = await firstContainer.read(
        appDatabaseProvider.future,
      );
      await _resetFixture(firstDatabase);
      await _seedEncounter(firstDatabase);

      appRouter.go('/prayers');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const SoulBuddyApp(),
        ),
      );
      await _pumpUntil(tester, find.byKey(const Key('personalized-choice')));
      _expectNoException(tester, 'opening Prayers');

      await _tapVisible(tester, find.byKey(const Key('personalized-choice')));
      await _tapVisible(tester, find.text('Situational / special'));
      await _tapVisible(tester, find.text('Encompassing / selfless'));
      await _tapVisible(tester, find.text('General Christian'));
      await _tapVisible(tester, find.text('Family'));
      await _enterVisible(
        tester,
        find.byKey(const Key('prayer-request-field')),
        'Give our household wisdom for a difficult decision.',
      );
      await _tapVisible(tester, find.text('Continue'));
      await _tapVisible(tester, find.text('People affected by this'));
      await _tapVisible(tester, find.text('All of these'));
      await _tapVisible(tester, find.text('Act faithfully'));
      await _tapVisible(tester, find.text('I see no conflict'));
      await _pumpUntil(tester, find.text('Add context'));

      await _tapVisible(tester, find.text('Add Encounter'));
      await _pumpUntil(tester, find.text('A remembered answer'));
      await tester.tap(find.text('A remembered answer'));
      await _settle(tester);

      await _tapVisible(tester, find.text('Add Scripture'));
      await _pumpUntil(tester, find.text('Add passage'));
      expect(
        find.text('RSVCE - Scripture. Choose up to 20 consecutive verses.'),
        findsOneWidget,
      );
      await _tapVisible(tester, find.text('Add passage'));
      await _pumpUntil(tester, find.text('RSVCE - Scripture'));

      await _tapVisible(tester, find.byKey(const Key('prepare-prayer-draft')));
      await _pumpUntil(
        tester,
        find.text(
          'To prepare this draft, SoulBuddy sends your choices and only the records you selected to DeepSeek. DeepSeek processes this information under its privacy policy.',
        ),
      );
      await tester.tap(find.text('Prepare draft').last);

      final queued = await _waitForRequest(
        firstDatabase,
        failureCode: 'temporarily_unavailable',
      );
      final requestId = queued['id'] as String;
      expect(queued['status'] == 'queued', isTrue);
      expect(endpoint.postCalls, 1);
      expect(
        await _count(
          firstDatabase,
          'prayer_generation_contexts',
          'request_id',
          requestId,
        ),
        2,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final firstWorker = await firstContainer.read(
        prayerGenerationWorkerProvider.future,
      );
      final firstCoordinator = await firstContainer.read(
        prayerReminderCoordinatorProvider.future,
      );
      await firstWorker.dispose();
      await firstDatabase.powersync.execute(
        '''
        UPDATE prayer_generation_requests
        SET next_attempt_at = ?
        WHERE id = ? AND owner_id = ?
        ''',
        [DateTime.utc(2026).toIso8601String(), requestId, _identity.ownerId],
      );
      firstContainer.dispose();
      await tester.pump();
      await firstCoordinator.dispose();
      await _drainAndClose(tester, firstDatabase);

      endpoint.online = true;
      final secondContainer = _newContainer(databasePath, endpoint);
      final secondDatabase = await secondContainer.read(
        appDatabaseProvider.future,
      );
      appRouter.go('/prayers/requests/$requestId/draft');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: secondContainer,
          child: const SoulBuddyApp(),
        ),
      );
      await _pumpUntil(tester, find.byKey(const Key('draft-title-field')));
      expect(find.byKey(const Key('draft-title-field')), findsOneWidget);
      _expectNoException(tester, 'receiving the prepared draft');
      await _waitForCondition(
        () => endpoint.deleteCalls == 1,
        () =>
            'Draft acknowledgement boundary did not run. '
            'POST=${endpoint.postCalls}, DELETE=${endpoint.deleteCalls}, '
            'unauthenticated=${endpoint.unauthenticatedCalls}, '
            'offline=${endpoint.offlineCalls}.',
      );
      expect(endpoint.postCalls, 2);
      expect(endpoint.acknowledgementCalls, 1);
      expect(endpoint.lastRequestWasAuthenticated, isTrue);
      expect(endpoint.lastContextCount, 2);

      const editedTitle = 'For wisdom in our household';
      const editedBody =
          'Father, keep our household truthful, patient, and faithful. Give us wisdom to serve others in this decision. Amen.';
      await _enterVisible(
        tester,
        find.byKey(const Key('draft-title-field')),
        editedTitle,
      );
      expect(
        tester
                .widget<TextFormField>(
                  find.byKey(const Key('draft-title-field')),
                )
                .controller
                ?.text ==
            editedTitle,
        isTrue,
        reason: 'The title field did not accept the synthetic edit.',
      );
      await _enterVisible(
        tester,
        find.byKey(const Key('draft-body-field')),
        editedBody,
      );
      expect(
        tester
                .widget<TextFormField>(
                  find.byKey(const Key('draft-title-field')),
                )
                .controller
                ?.text ==
            editedTitle,
        isTrue,
      );
      expect(
        tester
                .widget<TextFormField>(
                  find.byKey(const Key('draft-body-field')),
                )
                .controller
                ?.text ==
            editedBody,
        isTrue,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await _tapVisible(tester, find.text('Use today'));
      await _pumpUntil(tester, find.byKey(const Key('today-action-done')));
      _expectNoException(tester, 'accepting the draft for Today');

      await tester.tap(find.byKey(const Key('today-action-done')));
      await _pumpUntil(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckboxListTile &&
              widget.key == const Key('today-action-done') &&
              widget.value == true,
        ),
      );
      _expectNoException(tester, 'completing the selected practice');

      expect(
        await _count(
          secondDatabase,
          'personal_prayers',
          'owner_id',
          _identity.ownerId,
        ),
        1,
      );

      final saved = await secondDatabase.powersync.get(
        '''
        SELECT id, title, current_revision_id
        FROM personal_prayers
        WHERE owner_id = ? AND archived_at IS NULL
        ''',
        [_identity.ownerId],
      );
      final prayerId = saved['id'] as String;
      final revisionId = saved['current_revision_id'] as String;
      expect(saved['title'] == editedTitle, isTrue);
      final revision = await secondDatabase.powersync.get(
        '''
        SELECT body, action
        FROM personal_prayer_revisions
        WHERE id = ? AND prayer_id = ? AND owner_id = ?
        ''',
        [revisionId, prayerId, _identity.ownerId],
      );
      expect(revision['body'] == editedBody, isTrue);
      expect((revision['action'] as String).isNotEmpty, isTrue);
      expect(
        await _count(
          secondDatabase,
          'personal_prayer_links',
          'prayer_id',
          prayerId,
        ),
        2,
      );
      final today = await secondDatabase.powersync.get(
        '''
        SELECT personal_prayer_id, include_action, action_completed
        FROM today_prayers
        WHERE owner_id = ?
        ''',
        [_identity.ownerId],
      );
      expect(today['personal_prayer_id'] == prayerId, isTrue);
      expect(today['include_action'], 1);
      expect(today['action_completed'], 1);
      expect(
        (await secondDatabase.powersync.get(
              '''
          SELECT accepted_prayer_id
          FROM prayer_generation_requests
          WHERE id = ? AND owner_id = ?
          ''',
              [requestId, _identity.ownerId],
            ))['accepted_prayer_id'] ==
            prayerId,
        isTrue,
      );

      await _closeApp(tester, secondContainer, secondDatabase);

      final reopenedContainer = _newContainer(databasePath, endpoint);
      final reopenedDatabase = await reopenedContainer.read(
        appDatabaseProvider.future,
      );
      appRouter.go('/today');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: reopenedContainer,
          child: const SoulBuddyApp(),
        ),
      );
      await _pumpUntil(tester, find.byKey(const Key('today-action-done')));
      _expectNoException(tester, 'reopening the accepted prayer');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('today-action-done')),
            )
            .value,
        isTrue,
      );
      final reopenedPrayer = await reopenedDatabase.powersync.get(
        '''
        SELECT title, current_revision_id
        FROM personal_prayers
        WHERE id = ? AND owner_id = ?
        ''',
        [prayerId, _identity.ownerId],
      );
      expect(reopenedPrayer['title'] == editedTitle, isTrue);
      expect(reopenedPrayer['current_revision_id'] == revisionId, isTrue);
      final reopenedToday = await reopenedDatabase.powersync.get(
        '''
        SELECT personal_prayer_id, action_completed
        FROM today_prayers
        WHERE owner_id = ?
        ''',
        [_identity.ownerId],
      );
      expect(reopenedToday['personal_prayer_id'] == prayerId, isTrue);
      expect(reopenedToday['action_completed'], 1);

      await _closeApp(tester, reopenedContainer, reopenedDatabase);
    },
  );
}

class _FakeAuthenticatedLaravelDraftEndpoint {
  bool online = false;
  int postCalls = 0;
  int deleteCalls = 0;
  int acknowledgementCalls = 0;
  int unauthenticatedCalls = 0;
  int offlineCalls = 0;
  bool lastRequestWasAuthenticated = false;
  int lastContextCount = 0;

  Future<http.Response> call(http.Request request) async {
    if (request.method == 'DELETE') deleteCalls++;
    final authenticated =
        request.headers['authorization'] == 'Bearer $_sessionToken';
    if (!authenticated) {
      unauthenticatedCalls++;
      return http.Response('{"code":"unauthenticated"}', 401);
    }
    if (request.method == 'POST') postCalls++;
    if (!online) {
      offlineCalls++;
      throw http.ClientException('offline');
    }
    lastRequestWasAuthenticated = true;
    if (request.method == 'DELETE') {
      acknowledgementCalls++;
      return http.Response('', 204);
    }
    final payload = jsonDecode(request.body) as Map<String, dynamic>;
    final contexts = payload['contexts'] as List<dynamic>;
    lastContextCount = contexts.length;
    return http.Response(
      jsonEncode({
        'attempt_id': payload['attempt_id'],
        'prompt_version': 'integration-1',
        'draft': {
          'title': 'For patient wisdom',
          'body':
              'Father, give our household wisdom, patience, and love. Keep us truthful and ready to serve others. Amen.',
          'action': 'Listen before choosing a response.',
        },
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

ProviderContainer _newContainer(
  String databasePath,
  _FakeAuthenticatedLaravelDraftEndpoint endpoint,
) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith(
        (ref) => AppDatabase.open(path: databasePath),
      ),
      localIdentityProvider.overrideWith((ref) async => _identity),
      appSessionTokenReaderProvider.overrideWith(
        (ref) =>
            () async => _sessionToken,
      ),
      prayerDraftApiProvider.overrideWith((ref) {
        final client = MockClient(endpoint.call);
        ref.onDispose(client.close);
        return LaravelPrayerDraftApi(
          apiBaseUri: Uri.parse('https://integration.soulbuddy.test'),
          accessToken: ref.watch(appSessionTokenReaderProvider),
          client: client,
        );
      }),
    ],
  );
}

Future<void> _resetFixture(AppDatabase database) async {
  for (final table in [
    'personal_prayer_links',
    'personal_prayer_revisions',
    'personal_prayers',
    'today_prayers',
    'prayer_generation_contexts',
    'prayer_generation_requests',
    'encounter_revisions',
    'encounters',
  ]) {
    if (table == 'prayer_generation_contexts') {
      await database.powersync.execute('DELETE FROM $table');
    } else {
      await database.powersync.execute(
        'DELETE FROM $table WHERE owner_id = ?',
        [_identity.ownerId],
      );
    }
  }
}

Future<void> _closeApp(
  WidgetTester tester,
  ProviderContainer container,
  AppDatabase database,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final worker = await container.read(prayerGenerationWorkerProvider.future);
  final coordinator = await container.read(
    prayerReminderCoordinatorProvider.future,
  );
  await worker.dispose();
  container.dispose();
  await tester.pump();
  await coordinator.dispose();
  await _drainAsyncDisposals(tester);
  await _drainAndClose(tester, database);
}

Future<void> _drainAsyncDisposals(WidgetTester tester) async {
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
    await tester.pump();
  }
}

Future<void> _drainAndClose(WidgetTester tester, AppDatabase database) async {
  await tester.pump();
  await database.powersync.get('SELECT 1 AS ready');
  await database.close();
}

Future<void> _seedEncounter(AppDatabase database) async {
  final timestamp = DateTime.utc(2026, 8, 11, 8).toIso8601String();
  await database.powersync.execute(
    '''
    INSERT INTO encounters(
      id, owner_id, title, body, occurred_on, is_altar, created_at, updated_at,
      archived_at, current_revision_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
    ''',
    [
      _encounterId,
      _identity.ownerId,
      'A remembered answer',
      'We received peace while listening before making a decision.',
      '2026-08-11',
      1,
      timestamp,
      timestamp,
      _encounterRevisionId,
    ],
  );
  await database.powersync.execute(
    '''
    INSERT INTO encounter_revisions(
      id, encounter_id, owner_id, title, body, created_at, device_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      _encounterRevisionId,
      _encounterId,
      _identity.ownerId,
      'A remembered answer',
      'We received peace while listening before making a decision.',
      timestamp,
      _identity.deviceId,
    ],
  );
}

Future<Map<String, dynamic>> _waitForRequest(
  AppDatabase database, {
  required String failureCode,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final rows = await database.powersync.getAll(
      '''
      SELECT id, status, failure_code
      FROM prayer_generation_requests
      WHERE owner_id = ?
      ''',
      [_identity.ownerId],
    );
    if (rows.length == 1 && rows.single['failure_code'] == failureCode) {
      return Map<String, dynamic>.from(rows.single);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('The queued request did not reach the expected safe status.');
}

Future<void> _waitForCondition(
  bool Function() condition,
  String Function() safeFailure,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail(safeFailure());
}

Future<int> _count(
  AppDatabase database,
  String table,
  String column,
  String value,
) async {
  final row = await database.powersync.get(
    'SELECT COUNT(*) AS total FROM $table WHERE $column = ?',
    [value],
  );
  return row['total'] as int;
}

Future<String> _testDatabasePath() async {
  if (kIsWeb) return _databaseName;
  final directory = await getApplicationSupportDirectory();
  return path.join(directory.path, _databaseName);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120 && finder.evaluate().isEmpty; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await _pumpUntil(tester, finder);
  }
  if (finder.evaluate().isEmpty) {
    fail('The requested control did not become available: $finder');
  }
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final target = finder.hitTestable();
  if (target.evaluate().isEmpty) {
    fail('The requested control was present but not tappable: $finder');
  }
  await tester.tap(target.first, warnIfMissed: true);
  await _settle(tester);
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  final editable = find.descendant(
    of: finder,
    matching: find.byType(EditableText),
  );
  await tester.tap(editable);
  await tester.pump();
  await tester.enterText(editable, value);
  await tester.pump();
}

void _expectNoException(WidgetTester tester, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
}
