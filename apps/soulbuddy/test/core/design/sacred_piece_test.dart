import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/sacred_piece.dart';
import 'package:soulbuddy/core/presentation/sacred_piece_medallion.dart';

void main() {
  test('every SacredPiece has a distinct semantic label and icon', () {
    final labels = SacredPiece.values
        .map((piece) => piece.semanticLabel)
        .toSet();
    final icons = SacredPiece.values.map((piece) => piece.icon).toSet();

    expect(labels, hasLength(SacredPiece.values.length));
    expect(icons, hasLength(SacredPiece.values.length));
  });

  testWidgets('SacredPieceMedallion exposes its piece label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SacredPieceMedallion(piece: SacredPiece.prayer),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Prayer'), findsOneWidget);
    semantics.dispose();
  });
}
