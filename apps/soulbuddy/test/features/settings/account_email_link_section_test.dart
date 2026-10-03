import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/account_email_link_client.dart';
import 'package:soulbuddy/features/settings/presentation/account_email_link_section.dart';

void main() {
  testWidgets('sends a verification link for the entered email', (
    tester,
  ) async {
    String? submittedEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountEmailLinkSection(
            requestLink: (email) async {
              submittedEmail = email;
              return AccountEmailChallenge(
                id: 'challenge',
                expiresAt: DateTime.utc(2026, 10, 3, 7, 10),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'beloved@example.com');
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'beloved@example.com');
    expect(find.text('Verification link sent.'), findsOneWidget);
  });
}
