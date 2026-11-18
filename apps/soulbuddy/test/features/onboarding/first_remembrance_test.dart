import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_remembrance_page.dart';

import '../../helpers/no_speech_recognizer.dart';

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
      _pumpable(
        FirstRemembranceWritePage(
          onSave: (body) async {
            saved = body;
            return true;
          },
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
      _pumpable(FirstRemembranceWritePage(onSave: (_) async => false)),
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

/// The write page now carries a [SayableField], which resolves speech
/// availability on mount and reads the controller at save time. Answering
/// without reaching a plugin leaves the page exactly as it was before: the
/// field writable, speech unavailable, no microphone asked for.
Widget _pumpable(Widget child) => ProviderScope(
  overrides: [speechRecognizerProvider.overrideWithValue(NoSpeech())],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);
