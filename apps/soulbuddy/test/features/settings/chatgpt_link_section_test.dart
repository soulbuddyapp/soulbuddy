import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/identity/chatgpt_link_client.dart';
import 'package:soulbuddy/features/settings/presentation/chatgpt_link_section.dart';

void main() {
  Widget host(ChatgptLinkSection child) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );

  testWidgets('shows a private one-use code and allows copying only on request', (
    tester,
  ) async {
    String? copied;
    var requests = 0;
    await tester.pumpWidget(host(ChatgptLinkSection(
      getStatus: () async => false,
      createCode: () async {
        requests++;
        return ChatgptLinkCode(
          code: 'abcdef0123456789abcdef0123456789',
          expiresAt: DateTime.now().add(const Duration(minutes: 8)),
        );
      },
      unlink: () async => true,
      copyCode: (value) async => copied = value,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Create link code'), findsOneWidget);
    expect(find.byKey(const Key('chatgpt-link-code')), findsNothing);
    await tester.tap(find.text('Create link code'));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.byKey(const Key('chatgpt-link-code')), findsOneWidget);
    expect(copied, isNull);
    await tester.ensureVisible(find.text('Copy code'));
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    expect(copied, 'abcdef0123456789abcdef0123456789');
    expect(find.text('Code copied. Keep it private.'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chatgpt-link-code')), findsNothing);
  });

  testWidgets('reads status and requires confirmation before removing access', (
    tester,
  ) async {
    var linked = true;
    var removes = 0;
    await tester.pumpWidget(host(ChatgptLinkSection(
      getStatus: () async => linked,
      createCode: () async => throw StateError('Not expected'),
      unlink: () async {
        removes++;
        linked = false;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Connected to your SoulBuddy account.'), findsOneWidget);
    await tester.tap(find.text('Remove ChatGPT access'));
    await tester.pumpAndSettle();
    expect(find.text('Remove SoulBuddy access from ChatGPT?'), findsOneWidget);
    await tester.tap(find.text('Keep connection'));
    await tester.pumpAndSettle();
    expect(removes, 0);

    await tester.tap(find.text('Remove ChatGPT access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove access'));
    await tester.pumpAndSettle();
    expect(removes, 1);
    expect(find.text('Create link code'), findsOneWidget);
    expect(
      find.textContaining('Also disconnect in ChatGPT'),
      findsOneWidget,
    );
  });

  testWidgets('requires verification before generating a link code', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChatgptLinkSection(
      getStatus: () async => false,
      createCode: () async => throw const ChatgptLinkException(
        'Verify your SoulBuddy email above before linking ChatGPT.',
      ),
      unlink: () async => false,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create link code'));
    await tester.pumpAndSettle();
    expect(
      find.text('Verify your SoulBuddy email above before linking ChatGPT.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chatgpt-link-code')), findsNothing);
  });

  testWidgets('a failed status request is not shown as a disconnected account', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChatgptLinkSection(
      getStatus: () async => throw const ChatgptLinkException(
        'The service is unavailable.',
      ),
      createCode: () async => throw StateError('Not expected'),
      unlink: () async => false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('The service is unavailable.'), findsOneWidget);
    expect(find.text('Create link code'), findsNothing);
    expect(find.text('Check connection'), findsOneWidget);
  });
}
