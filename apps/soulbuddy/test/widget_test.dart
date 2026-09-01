import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';

void main() {
  testWidgets('starts with the first-use welcome', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingCompleteProvider.overrideWith((ref) => false)],
        child: const SoulBuddyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Come as you are'), findsOneWidget);
    expect(find.text('A place to return to God'), findsNothing);
  });
}
