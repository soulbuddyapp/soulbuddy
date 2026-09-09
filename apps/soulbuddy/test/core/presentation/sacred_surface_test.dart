import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/presentation/sacred_surface.dart';

void main() {
  testWidgets('marble sacred surface keeps texture behind its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SacredSurface(
            marble: true,
            child: Text('A quiet place'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sacred-surface-marble')), findsOneWidget);
    expect(find.text('A quiet place'), findsOneWidget);
  });
}
