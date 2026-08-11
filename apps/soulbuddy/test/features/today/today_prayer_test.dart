import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/today/presentation/today_screen.dart';

import '../../helpers/in_memory_prayer_repository.dart';

void main() {
  test('Today prayer stream releases its watcher when the screen leaves', () {
    expect(todayPrayerDateProvider.isAutoDispose, isTrue);
    expect(todayPrayerProvider.isAutoDispose, isTrue);
  });

  testWidgets('no selection offers a working prayer-library action', (
    tester,
  ) async {
    final repository = InMemoryPrayerRepository(prayers: const [_prayer]);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Pray. Act. Remember.'), findsOneWidget);
    expect(find.text('Choose a prayer for today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('choose-prayer')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer library destination'), findsOneWidget);
    _expectNoGamification(tester);
  });

  testWidgets(
    'selection shows the full prayer and can choose a different one',
    (tester) async {
      final repository = _repository(includeAction: true);
      addTearDown(repository.close);
      await _pumpToday(tester, repository: repository);

      expect(find.text(_prayer.title), findsOneWidget);
      expect(find.text(_prayer.body), findsOneWidget);
      expect(find.text('Family · General Christian'), findsOneWidget);
      expect(find.text('Choose a different prayer'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);

      await _scrollTo(tester, const Key('choose-different-prayer'));
      await tester.tap(find.byKey(const Key('choose-different-prayer')));
      await tester.pumpAndSettle();

      expect(find.text('Prayer library destination'), findsOneWidget);
      _expectNoGamification(tester);
    },
  );

  testWidgets('included practical action persists completion and re-renders', (
    tester,
  ) async {
    final repository = _repository(includeAction: true);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    expect(find.text('Practical action'), findsOneWidget);
    expect(find.text(_prayerAction), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await _scrollTo(tester, const Key('today-action-done'));
    expect(
      tester.getSize(find.byKey(const Key('today-action-done'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pumpAndSettle();

    expect(repository.completedTodayDate, DateTime(2026, 8, 11));
    expect(repository.completedTodayValue, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    _expectNoGamification(tester);
  });

  testWidgets('completion control is disabled while persistence is pending', (
    tester,
  ) async {
    final repository = _DelayedCompletionRepository(
      prayers: const [_prayer],
      todayPrayer: _today(includeAction: true),
    );
    addTearDown(repository.release);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    await _scrollTo(tester, const Key('today-action-done'));
    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pump();
    await repository.started.future;

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);

    repository.release();
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('completion failure is generic and recoverable', (tester) async {
    final repository = _FailingCompletionRepository(
      prayers: const [_prayer],
      todayPrayer: _today(includeAction: true),
    );
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    await _scrollTo(tester, const Key('today-action-done'));
    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update the action. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining(_prayer.body), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);
  });

  testWidgets('excluded action is absent', (tester) async {
    final repository = _repository(includeAction: false);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    expect(find.text(_prayer.body), findsOneWidget);
    expect(find.text('Practical action'), findsNothing);
    expect(find.text(_prayerAction), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('uses the device local calendar day at the UTC boundary', (
    tester,
  ) async {
    final repository = _repository(includeAction: false);
    addTearDown(repository.close);
    final localBoundary = DateTime(2026, 8, 11, 0, 15);
    expect(localBoundary.isUtc, isFalse);
    await _pumpToday(tester, repository: repository, now: () => localBoundary);

    expect(repository.watchedTodayDate, DateTime(2026, 8, 11));
  });

  testWidgets('switches to the new local date at midnight while mounted', (
    tester,
  ) async {
    var currentTime = DateTime(2026, 8, 11, 23, 59, 30);
    final repository = _DatedPrayerRepository({
      DateTime(2026, 8, 11): TodayPrayer(
        prayer: _prayer,
        localDate: DateTime(2026, 8, 11),
        includeAction: false,
        actionCompleted: false,
      ),
      DateTime(2026, 8, 12): TodayPrayer(
        prayer: _nextDayPrayer,
        localDate: DateTime(2026, 8, 12),
        includeAction: false,
        actionCompleted: false,
      ),
    });
    addTearDown(repository.close);

    await _pumpToday(tester, repository: repository, now: () => currentTime);
    final providerScopeElement = tester.element(find.byType(ProviderScope));
    final todayScreenElement = tester.element(find.byType(TodayScreen));

    expect(find.text(_prayer.title), findsOneWidget);
    expect(repository.watchedDates, [DateTime(2026, 8, 11)]);

    currentTime = DateTime(2026, 8, 12);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text(_nextDayPrayer.title), findsOneWidget);
    expect(find.text(_prayer.title), findsNothing);
    expect(
      identical(
        tester.element(find.byType(ProviderScope)),
        providerScopeElement,
      ),
      isTrue,
    );
    expect(
      identical(tester.element(find.byType(TodayScreen)), todayScreenElement),
      isTrue,
    );
    expect(repository.watchedDates, [
      DateTime(2026, 8, 11),
      DateTime(2026, 8, 12),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('remains scrollable and readable at 200% text scale', (
    tester,
  ) async {
    final repository = _repository(includeAction: true);
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpToday(
      tester,
      repository: repository,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(Scrollable), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('choose-different-prayer')),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text(_prayer.body), findsOneWidget);
    expect(tester.takeException(), isNull);
    _expectNoGamification(tester);
  });
}

Future<void> _pumpToday(
  WidgetTester tester, {
  required InMemoryPrayerRepository repository,
  DateTime Function()? now,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(
        path: '/today',
        builder: (context, state) => const Scaffold(body: TodayScreen()),
      ),
      GoRoute(
        path: '/prayers',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Prayer library destination')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWith((ref) async => repository),
        prayerClockProvider.overrideWithValue(
          now ?? () => DateTime(2026, 8, 11, 12),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InMemoryPrayerRepository _repository({required bool includeAction}) {
  return InMemoryPrayerRepository(
    prayers: const [_prayer],
    todayPrayer: _today(includeAction: includeAction),
  );
}

TodayPrayer _today({required bool includeAction}) {
  return TodayPrayer(
    prayer: _prayer,
    localDate: DateTime(2026, 8, 11),
    includeAction: includeAction,
    actionCompleted: false,
  );
}

void _expectNoGamification(WidgetTester tester) {
  final copy = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join(' ')
      .toLowerCase();
  for (final forbidden in [
    'confetti',
    'points',
    'streak',
    'praise',
    'metrics',
    'leaderboard',
    'public',
  ]) {
    expect(copy, isNot(contains(forbidden)));
  }
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

class _DelayedCompletionRepository extends InMemoryPrayerRepository {
  _DelayedCompletionRepository({
    required super.prayers,
    required super.todayPrayer,
  });

  final started = Completer<void>();
  final _release = Completer<void>();

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required bool value,
  }) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    await super.completeTodayAction(localDate, value: value);
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}

class _FailingCompletionRepository extends InMemoryPrayerRepository {
  _FailingCompletionRepository({
    required super.prayers,
    required super.todayPrayer,
  });

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required bool value,
  }) async {
    throw StateError('private prayer text must never be logged');
  }
}

class _DatedPrayerRepository extends InMemoryPrayerRepository {
  _DatedPrayerRepository(this.selections)
    : super(prayers: selections.values.map((today) => today.prayer).toList());

  final Map<DateTime, TodayPrayer> selections;
  final List<DateTime> watchedDates = [];

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) async* {
    watchedDates.add(localDate);
    yield selections[localDate];
  }
}

const _prayerAction = 'Ease someone\'s burden today.';

const _prayer = LibraryPrayer(
  id: 'family',
  title: 'For my family',
  body:
      'Father, hold my family in your mercy. Teach us to listen before '
      'answering, forgive without keeping score, and meet ordinary needs with '
      'patient love. Give us our daily bread and make our home ready to welcome '
      'and serve others. In Jesus\' name. Amen.',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.family,
  helpfulCount: 12,
  viewerMarkedHelpful: false,
  action: _prayerAction,
);

const _nextDayPrayer = LibraryPrayer(
  id: 'gratitude',
  title: 'For a new day',
  body: 'Father, thank you for this new day. Keep me near you. Amen.',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.gratitude,
  helpfulCount: 4,
  viewerMarkedHelpful: false,
);
