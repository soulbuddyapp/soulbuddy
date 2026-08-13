import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/presentation/covenant_marks.dart';

void main() {
  testWidgets('gathered mark is semantic, deterministic, and non-botanical', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: GatheredInscriptionMark(key: Key('gathered')),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Three illuminated inscriptions gathered in one place.',
      ),
      findsOneWidget,
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('gathered')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (paint.painter! as CovenantMarkPainter).kind,
      CovenantMarkKind.gathered,
    );
    semantics.dispose();
  });

  testWidgets('incised and paired marks survive dark theme and large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Column(
              children: [
                CovenantIncisedDivider(key: Key('incised')),
                CovenantPairedSlabMark(key: Key('paired')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('incised')), findsOneWidget);
    expect(find.byKey(const Key('paired')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
