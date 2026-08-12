import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/presentation/living_vine.dart';

void main() {
  for (final variant in LivingVineVariant.values) {
    testWidgets('renders ${variant.name} as a decorative fixed-height visual', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LivingVine(
              key: Key('vine-${variant.name}'),
              variant: variant,
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vine-${variant.name}')), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        tester.getSize(find.byKey(Key('vine-${variant.name}'))).height,
        56,
      );
      expect(find.bySemanticsLabel(RegExp('vine|branch')), findsNothing);
    });
  }

  testWidgets('renders its final state immediately when motion is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LivingVine(
              key: Key('reduced-motion-vine'),
              variant: LivingVineVariant.blossom,
              animate: true,
            ),
          ),
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('reduced-motion-vine')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.painter, isA<LivingVinePainter>());
    expect((paint.painter! as LivingVinePainter).reveal, 1);
  });
}
