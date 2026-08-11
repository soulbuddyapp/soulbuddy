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

const _databaseName = 'soulbuddy-prayer-integration.db';
const _identity = LocalIdentity(
  ownerId: 'offline-prayer-integration-owner',
  deviceId: 'offline-prayer-integration-device',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a Helpful prayer and completed action persist through a real database reopen',
    (tester) async {
      final databasePath = await _testDatabasePath();
      final firstContainer = _newContainer(databasePath);
      final firstDatabase = await firstContainer.read(
        appDatabaseProvider.future,
      );
      await firstDatabase.powersync.execute(
        'DELETE FROM prayer_votes WHERE owner_id = ?',
        [_identity.ownerId],
      );
      await firstDatabase.powersync.execute(
        'DELETE FROM today_prayers WHERE owner_id = ?',
        [_identity.ownerId],
      );

      appRouter.go('/prayers');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const SoulBuddyApp(),
        ),
      );
      await _pumpUntil(tester, find.text('For this day'));
      _expectNoException(tester, 'opening the bundled prayer library');
      expect(find.text('Choose from library'), findsOneWidget);

      await tester.tap(find.byKey(const Key('grounding-general-christian')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('purpose-daily')));
      await _settle(tester);
      expect(find.text('For this day'), findsOneWidget);

      await tester.tap(find.text('For this day'));
      await _pumpUntil(tester, find.byKey(const Key('helpful-toggle')));
      _expectNoException(tester, 'opening prayer detail');

      await tester.tap(find.byKey(const Key('helpful-toggle')));
      await _pumpUntil(tester, find.byIcon(Icons.favorite));
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byKey(const Key('use-today')));
      await _pumpUntil(tester, find.byKey(const Key('confirm-use-today')));
      expect(find.text('Include the suggested action'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-use-today')));
      await _pumpUntil(tester, find.byKey(const Key('today-action-done')));
      _expectNoException(tester, 'using the prayer on Today');
      if (find.byKey(const Key('today-action-done')).evaluate().isEmpty) {
        final rows = await firstDatabase.powersync.getAll(
          'SELECT owner_id, local_date, prayer_id, include_action, '
          'action_completed FROM today_prayers',
        );
        final visibleText = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .toList(growable: false);
        fail(
          'Today action did not appear after confirmation. '
          'Rows: $rows. Visible text: $visibleText',
        );
      }
      final selectedRows = await firstDatabase.powersync.getAll(
        'SELECT owner_id, prayer_id, include_action, action_completed '
        'FROM today_prayers WHERE owner_id = ?',
        [_identity.ownerId],
      );
      expect(selectedRows, hasLength(1));
      expect(selectedRows.single['owner_id'], _identity.ownerId);
      expect(
        selectedRows.single['prayer_id'],
        '0198a100-0000-7000-8000-000000000001',
      );
      expect(selectedRows.single['include_action'], 1);
      expect(selectedRows.single['action_completed'], 0);

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
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('today-action-done')),
            )
            .value,
        isTrue,
      );
      expect(
        (await firstDatabase.powersync.get(
          'SELECT action_completed FROM today_prayers WHERE owner_id = ?',
          [_identity.ownerId],
        ))['action_completed'],
        1,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      firstContainer.dispose();
      await firstDatabase.close();

      final reopenedContainer = _newContainer(databasePath);
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
      _expectNoException(tester, 'reopening the local prayer database');
      expect(find.text('For this day'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('today-action-done')),
            )
            .value,
        isTrue,
      );
      expect(
        (await reopenedDatabase.powersync.get(
          'SELECT action_completed FROM today_prayers WHERE owner_id = ?',
          [_identity.ownerId],
        ))['action_completed'],
        1,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      reopenedContainer.dispose();
      await reopenedDatabase.close();
    },
  );
}

ProviderContainer _newContainer(String databasePath) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith(
        (ref) => AppDatabase.open(path: databasePath),
      ),
      localIdentityProvider.overrideWith((ref) async => _identity),
    ],
  );
}

Future<String> _testDatabasePath() async {
  if (kIsWeb) return _databaseName;
  final directory = await getApplicationSupportDirectory();
  return path.join(directory.path, _databaseName);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

void _expectNoException(WidgetTester tester, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
}

Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
