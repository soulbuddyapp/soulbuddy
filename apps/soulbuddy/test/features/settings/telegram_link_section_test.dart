import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/telegram_link_client.dart';
import 'package:soulbuddy/features/settings/presentation/telegram_link_section.dart';

void main() {
  testWidgets('shows Telegram steps before opening the bot', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelegramLinkSection(
            createLink: () async => TelegramLink(
              id: 'challenge',
              code: 'code',
              expiresAt: DateTime.utc(2026, 10, 3, 7, 10),
              startUrl: Uri.parse('https://t.me/SoulBuddyBot?start=code'),
            ),
            checkStatus: (_) async => TelegramLinkState.connected,
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

    expect(find.text('1. Open SoulBuddy on Telegram'), findsOneWidget);
    expect(find.text('2. Select Start'), findsOneWidget);
    expect(find.text('3. Confirm connection'), findsOneWidget);
    expect(opened, isNull);

    await tester.tap(find.text('Open Telegram'));
    await tester.pumpAndSettle();
    expect(opened, Uri.parse('https://t.me/SoulBuddyBot?start=code'));

    await tester.tap(find.text('Confirm connection'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram connected.'), findsOneWidget);
  });
}
