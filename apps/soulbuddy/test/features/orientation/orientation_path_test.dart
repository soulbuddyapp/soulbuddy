import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/presentation/orientation_path.dart';

void main() {
  testWidgets('keeps a seventeen-Nugget path within a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: OrientationPath(completedCount: 3, total: 17),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
