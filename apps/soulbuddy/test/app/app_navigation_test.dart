import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';

void main() {
  testWidgets('shows all five top-level destinations', (tester) async {
    await tester.pumpWidget(const SoulBuddyApp());

    for (final label in ['Today', 'Prayers', 'Record', 'Remember', 'Circles']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Remember').last);
    await tester.pumpAndSettle();

    expect(find.text('What you have recorded'), findsOneWidget);
  });
}
