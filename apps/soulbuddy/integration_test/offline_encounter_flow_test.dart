import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/features/scripture/data/bundled_scripture_source.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an encounter and Scripture remain available without sync', (
    tester,
  ) async {
    appRouter.go('/today');
    await tester.pumpWidget(const ProviderScope(child: SoulBuddyApp()));
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    appRouter.go('/remember');
    await tester.pumpWidget(const ProviderScope(child: SoulBuddyApp()));
    await _settle(tester);
    _expectNoException(tester, 'reopening the local database');
    expect(find.text('Help I want to remember'), findsAtLeastNWidgets(1));

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
  });
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
