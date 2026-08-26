import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/onboarding/data/onboarding_repository.dart';
import 'package:soulbuddy/features/onboarding/presentation/onboarding_gate.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';

void main() {
  testWidgets('first use shows welcome instead of the routed app', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository);

    expect(find.text('A place to return to God'), findsOneWidget);
    expect(find.text('Routed app'), findsNothing);
  });

  testWidgets('completed welcome shows the routed app', (tester) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    await _pumpGate(tester, repository);

    expect(find.text('Routed app'), findsOneWidget);
    expect(find.text('A place to return to God'), findsNothing);
  });

  testWidgets('final welcome action persists and opens prayer choices', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    var openedPrayerChoices = false;
    await _pumpGate(
      tester,
      repository,
      onBeginWithPrayer: () => openedPrayerChoices = true,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin with prayer'));
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(openedPrayerChoices, isTrue);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('a storage failure never traps the person in welcome', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(failWrite: true);
    await _pumpGate(tester, repository);

    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();

    expect(find.text('Routed app'), findsOneWidget);
  });
}

Future<void> _pumpGate(
  WidgetTester tester,
  OnboardingRepository repository, {
  VoidCallback? onBeginWithPrayer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingGate(
          onBeginWithPrayer: onBeginWithPrayer ?? () {},
          onSkip: () {},
          child: const Scaffold(body: Center(child: Text('Routed app'))),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryOnboardingRepository extends OnboardingRepository {
  _MemoryOnboardingRepository({this.completed = false, this.failWrite = false})
    : super(read: _unusedRead, write: _unusedWrite);

  bool completed;
  final bool failWrite;

  @override
  Future<bool> isComplete() async => completed;

  @override
  Future<void> complete() async {
    if (failWrite) throw StateError('storage unavailable');
    completed = true;
  }

  static Future<String?> _unusedRead(String key) async => null;
  static Future<void> _unusedWrite(String key, String value) async {}
}
