import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/guide/presentation/guide_intro_sheet.dart';

void main() {
  testWidgets('custom name is saved and failed save can be retried', (
    tester,
  ) async {
    var tries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideIntroSheet(
            initialName: 'Arel',
            onSave: (name) async {
              tries++;
              expect(name, 'Neri');
              if (tries == 1) throw StateError('disk');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Neri');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(find.text('Neri'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tries, 2);
  });
}
