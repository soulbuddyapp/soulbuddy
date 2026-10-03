import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/telegram_link_client.dart';
import 'package:soulbuddy/features/settings/presentation/telegram_link_section.dart';

void main() {
  testWidgets('opens the Telegram start link after creating a link code', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelegramLinkSection(
            createLink: () async => TelegramLink(
              code: 'code',
              expiresAt: DateTime.utc(2026, 10, 3, 7, 10),
              startUrl: Uri.parse('https://t.me/SoulBuddyBot?start=code'),
            ),
            openUri: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Connect Telegram'));
    await tester.pumpAndSettle();

    expect(opened, Uri.parse('https://t.me/SoulBuddyBot?start=code'));
    expect(find.text('Telegram opened.'), findsOneWidget);
  });
}
