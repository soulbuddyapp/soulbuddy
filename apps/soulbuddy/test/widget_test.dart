import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';

void main() {
  testWidgets('starts with the Today guide', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SoulBuddyApp()));

    expect(find.text('Pray. Act. Remember.'), findsOneWidget);
  });
}
