import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_remembrance_page.dart';

void main() {
  testWidgets('asks the approved remembrance question with four choices', (
    tester,
  ) async {
    String? choice;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FirstRemembranceTypePage(onChoose: (value) => choice = value),
        ),
      ),
    );

    expect(
      find.text(
        'Before you leave, record something you would like to remember.',
      ),
      findsOneWidget,
    );
    for (final label in [
      'Encounter',
      'Promise',
      'Scripture or lesson',
      'Nothing today',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Promise'));
    expect(choice, 'Promise');
  });

  testWidgets('keeps one written memory without extra fields', (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FirstRemembranceWritePage(
            onSave: (body) async {
              saved = body;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('first-remembrance-text')),
      'God met me here.',
    );
    await tester.tap(find.text('Keep this memory'));
    await tester.pump();
    expect(saved, 'God met me here.');
  });

  testWidgets('keeps written words visible when saving needs a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FirstRemembranceWritePage(onSave: (_) async => false),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('first-remembrance-text')),
      'God met me here.',
    );
    await tester.tap(find.text('Keep this memory'));
    await tester.pump();

    expect(find.text('God met me here.'), findsOneWidget);
    expect(find.text("Couldn't keep this memory. Try again."), findsOneWidget);
    expect(find.text('Keep this memory'), findsOneWidget);
  });
}
