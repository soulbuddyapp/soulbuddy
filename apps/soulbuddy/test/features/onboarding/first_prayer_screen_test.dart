import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/onboarding/presentation/first_prayer_screen.dart';

import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets('guides one short prayer choice at a time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FirstPrayerScreen.preview(),
        ),
      ),
    );

    expect(find.text('What are you bringing to God?'), findsOneWidget);
    expect(find.text('Guidance'), findsOneWidget);

    await tester.tap(find.text('Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('How often?'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this for?'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Which feels more natural to you?'), findsOneWidget);
    expect(find.text('Christian'), findsOneWidget);
    expect(find.text('Catholic'), findsOneWidget);
    expect(find.text('Jesus'), findsOneWidget);
    expect(find.text('All of the above'), findsOneWidget);

    await tester.tap(find.text('Jesus'));
    await tester.pumpAndSettle();
    expect(find.text('Add anything?'), findsOneWidget);
    expect(find.text('Speak'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.textContaining('external prayer-writing service'),
      findsNothing,
    );
    expect(find.textContaining('DeepSeek'), findsNothing);
    expect(find.text('Preparing your prayer…'), findsOneWidget);
    expect(find.text('Choose a prepared prayer'), findsOneWidget);
  });

  testWidgets('written detail is short and optional', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The written detail page now offers the microphone, which resolves
        // availability on mount. Answering here rather than through the plugin
        // leaves the page as it was: writable, with speech unavailable.
        overrides: [speechRecognizerProvider.overrideWithValue(NoSpeech())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FirstPrayerScreen.preview(
            initialStep: FirstPrayerPreviewStep.detailChoice,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-prayer-detail')), findsOneWidget);
    expect(find.text('Use reviewed prayer'), findsOneWidget);
    expect(find.text('Prepare prayer'), findsNothing);
    expect(find.text('Not now'), findsOneWidget);
  });
}
