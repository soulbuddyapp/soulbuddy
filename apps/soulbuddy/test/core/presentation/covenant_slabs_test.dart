import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/design/covenant_grace_tokens.dart';
import 'package:soulbuddy/core/presentation/covenant_slabs.dart';
import 'package:soulbuddy/features/today/domain/daily_practice_state.dart';

void main() {
  const allAvailable = {
    DailyPractice.pray,
    DailyPractice.act,
    DailyPractice.remember,
  };

  testWidgets('exposes factual completion and availability semantics', (
    tester,
  ) async {
    const state = DailyPracticeState(
      available: allAvailable,
      completed: {DailyPractice.pray, DailyPractice.act},
    );

    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(key: Key('slabs'), state: state, animate: true),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Today: prayer and action completed; remembrance available',
      ),
      findsOneWidget,
    );
    expect(find.text('2 of 3 practices completed'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('slabs')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as CovenantSlabsPainter).state, state);
  });

  testWidgets('describes zero, one, and all completions without scoring', (
    tester,
  ) async {
    for (final testCase in <({Set<DailyPractice> completed, String label})>[
      (
        completed: const {},
        label: 'Today: prayer, action, and remembrance available',
      ),
      (
        completed: const {DailyPractice.pray},
        label: 'Today: prayer completed; action and remembrance available',
      ),
      (
        completed: allAvailable,
        label: 'Today: prayer, action, and remembrance completed',
      ),
    ]) {
      await tester.pumpWidget(
        _testHost(
          CovenantSlabs(
            state: DailyPracticeState(
              available: allAvailable,
              completed: testCase.completed,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(testCase.label), findsOneWidget);
      expect(find.textContaining(RegExp(r'score|streak')), findsNothing);
    }
  });

  testWidgets('excludes an unavailable action from the daily count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          state: DailyPracticeState(
            available: {DailyPractice.pray, DailyPractice.remember},
            completed: {DailyPractice.pray, DailyPractice.remember},
          ),
        ),
      ),
    );

    expect(find.text('2 of 2 practices completed'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Today: prayer and remembrance completed'),
      findsOneWidget,
    );
  });

  testWidgets('uses the dark Covenant and Grace palette', (tester) async {
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: Key('dark-slabs'),
          state: DailyPracticeState(available: allAvailable, completed: {}),
        ),
        dark: true,
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('dark-slabs')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (paint.painter! as CovenantSlabsPainter).colors,
      CovenantGraceColors.dark,
    );
  });

  testWidgets('renders its true initial state without a false completion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: Key('initial-slabs'),
          state: DailyPracticeState(
            available: allAvailable,
            completed: {DailyPractice.pray},
          ),
          animate: true,
        ),
      ),
    );

    expect(_painter(tester, const Key('initial-slabs')).reveal, 1);
  });

  testWidgets('animates only after the completion state changes', (
    tester,
  ) async {
    const key = Key('animated-slabs');
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: key,
          state: DailyPracticeState(available: allAvailable, completed: {}),
          animate: true,
        ),
      ),
    );
    expect(_painter(tester, key).reveal, 1);

    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: key,
          state: DailyPracticeState(
            available: allAvailable,
            completed: {DailyPractice.pray},
          ),
          animate: true,
        ),
      ),
    );
    expect(_painter(tester, key).reveal, 0);

    await tester.pump(const Duration(milliseconds: 180));
    expect(_painter(tester, key).reveal, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_painter(tester, key).reveal, 1);
  });

  testWidgets('renders final progress immediately when motion is disabled', (
    tester,
  ) async {
    const key = Key('reduced-motion-slabs');
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: key,
          state: DailyPracticeState(available: allAvailable, completed: {}),
          animate: true,
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpWidget(
      _testHost(
        const CovenantSlabs(
          key: key,
          state: DailyPracticeState(
            available: allAvailable,
            completed: allAvailable,
          ),
          animate: true,
        ),
        disableAnimations: true,
      ),
    );

    expect(_painter(tester, key).reveal, 1);
  });

  testWidgets('remains compact and readable at 200 percent text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testHost(
        const SizedBox(
          width: 320,
          child: CovenantSlabs(
            key: Key('large-text-slabs'),
            state: DailyPracticeState(
              available: allAvailable,
              completed: {DailyPractice.pray},
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('large-text-slabs'))).height,
      lessThanOrEqualTo(220),
    );
  });
}

CovenantSlabsPainter _painter(WidgetTester tester, Key key) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
  );
  return paint.painter! as CovenantSlabsPainter;
}

Widget _testHost(
  Widget child, {
  bool dark = false,
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: textScaler,
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}
