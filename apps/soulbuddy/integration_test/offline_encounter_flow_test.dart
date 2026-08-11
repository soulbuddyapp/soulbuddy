import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/scripture/data/bundled_scripture_source.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';

const _databasePath = 'soulbuddy-encounter-integration.db';
const _identity = LocalIdentity(
  ownerId: 'offline-encounter-integration-owner',
  deviceId: 'offline-encounter-integration-device',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an encounter and Scripture survive a real database reopen', (
    tester,
  ) async {
    final firstContainer = _newContainer();
    final firstDatabase = await firstContainer.read(appDatabaseProvider.future);
    await firstDatabase.powersync.execute(
      'DELETE FROM encounter_revisions WHERE owner_id = ?',
      [_identity.ownerId],
    );
    await firstDatabase.powersync.execute(
      'DELETE FROM encounters WHERE owner_id = ?',
      [_identity.ownerId],
    );

    appRouter.go('/today');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: firstContainer,
        child: const SoulBuddyApp(),
      ),
    );
    await _settle(tester);
    _expectNoException(tester, 'initial local database startup');

    appRouter.go('/record');
    await _settle(tester);
    await tester.tap(find.text('Encounter'));
    await _settle(tester);
    _expectNoException(tester, 'opening the Encounter form');

    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'Help I want to remember',
    );
    await tester.enterText(
      find.byKey(const Key('encounter-body')),
      'I received help when I needed it.',
    );
    await tester.ensureVisible(find.text('Save encounter'));
    await tester.tap(find.text('Save encounter'));
    await _settle(tester);
    _expectNoException(tester, 'saving the Encounter');

    appRouter.go('/remember');
    await _settle(tester);
    _expectNoException(tester, 'opening Remember');
    expect(find.text('Help I want to remember'), findsAtLeastNWidgets(1));
    final savedRows = await firstDatabase.powersync.getAll(
      'SELECT id, owner_id, title, body, current_revision_id '
      'FROM encounters WHERE owner_id = ?',
      [_identity.ownerId],
    );
    expect(savedRows, hasLength(1));
    expect(savedRows.single['owner_id'], _identity.ownerId);
    expect(savedRows.single['title'], 'Help I want to remember');
    expect(savedRows.single['body'], 'I received help when I needed it.');
    expect(
      await firstDatabase.powersync.getAll(
        'SELECT id FROM encounter_revisions '
        'WHERE owner_id = ? AND encounter_id = ?',
        [_identity.ownerId, savedRows.single['id']],
      ),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    firstContainer.dispose();
    await firstDatabase.close();

    final reopenedContainer = _newContainer();
    final reopenedDatabase = await reopenedContainer.read(
      appDatabaseProvider.future,
    );
    appRouter.go('/remember');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: reopenedContainer,
        child: const SoulBuddyApp(),
      ),
    );
    await _pumpUntil(tester, find.text('Help I want to remember'));
    _expectNoException(tester, 'reopening the local database');
    expect(find.text('Help I want to remember'), findsAtLeastNWidgets(1));
    final reopenedRows = await reopenedDatabase.powersync.getAll(
      'SELECT id, title, body FROM encounters WHERE owner_id = ?',
      [_identity.ownerId],
    );
    expect(reopenedRows, hasLength(1));
    expect(reopenedRows.single['id'], savedRows.single['id']);
    expect(reopenedRows.single['title'], 'Help I want to remember');
    expect(reopenedRows.single['body'], 'I received help when I needed it.');

    await tester.tap(find.text('Open John 3').first);
    await _pumpUntil(tester, find.textContaining('RSVCE'));
    _expectNoException(tester, 'opening bundled Scripture');
    if (find.textContaining('RSVCE').evaluate().isEmpty) {
      try {
        await loadBundledChapter(book: 'John', chapter: 3);
      } on ScriptureSourceUnavailable catch (error) {
        fail('Bundled Scripture failed to open: ${error.cause}');
      }
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      fail('Scripture did not finish opening. Visible text: $visibleText');
    }
    expect(find.text('John 3'), findsOneWidget);
    expect(find.textContaining('RSVCE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    reopenedContainer.dispose();
    await reopenedDatabase.close();
  });
}

ProviderContainer _newContainer() {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith(
        (ref) => AppDatabase.open(path: _databasePath),
      ),
      localIdentityProvider.overrideWith((ref) async => _identity),
    ],
  );
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
