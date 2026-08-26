import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/presentation/covenant_slabs.dart';
import 'package:soulbuddy/features/prayers/data/prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/remember/providers/daily_memory_providers.dart';
import 'package:soulbuddy/features/today/domain/daily_practice_state.dart';
import 'package:soulbuddy/features/today/presentation/today_screen.dart';

import '../../helpers/in_memory_prayer_repository.dart';

void main() {
  test('Today date and prayer providers are autoDispose', () {
    expect(todayPrayerDateProvider.isAutoDispose, isTrue);
    expect(todayPrayerProvider.isAutoDispose, isTrue);
  });

  testWidgets('no selection offers a calm guided start', (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = InMemoryPrayerRepository(prayers: const [_prayer]);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Pray. Act. Remember.'), findsOneWidget);
    expect(find.byKey(const Key('today-start-guide')), findsOneWidget);
    expect(find.byKey(const Key('today-covenant-slabs')), findsOneWidget);
    expect(find.byType(CovenantSlabs), findsOneWidget);
    expect(find.text('Begin today\'s communion.'), findsOneWidget);
    expect(
      find.text(
        'Pray with attention. Carry one faithful step. Keep what God gives '
        'you.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose a prayer'), findsOneWidget);
    expect(find.text('Record something'), findsOneWidget);
    expect(
      find.byKey(const Key('choose-prayer')).hitTestable(),
      findsOneWidget,
    );
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(find.byKey(const Key('today-start-guide-end'))).dy,
      lessThanOrEqualTo(viewportHeight),
    );

    await _scrollTo(tester, const Key('choose-prayer'));
    await tester.tap(find.byKey(const Key('choose-prayer')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer library destination'), findsOneWidget);
    _expectNoGamification(tester);
    semantics.dispose();
  });

  testWidgets('signature guide fits above real shell navigation', (
    tester,
  ) async {
    final repository = InMemoryPrayerRepository(prayers: const [_prayer]);
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpToday(
      tester,
      repository: repository,
      includeShellNavigation: true,
    );

    final guideBottom = tester
        .getBottomLeft(find.byKey(const Key('today-start-guide-end')))
        .dy;
    final navigationTop = tester
        .getTopLeft(find.byKey(const Key('test-shell-navigation')))
        .dy;
    expect(guideBottom, lessThanOrEqualTo(navigationTop));
    expect(
      find.byKey(const Key('choose-prayer')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('today-record-memory')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('signature guide yields visual space at 200% text scale', (
    tester,
  ) async {
    final repository = InMemoryPrayerRepository(prayers: const [_prayer]);
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpToday(
      tester,
      repository: repository,
      textScaler: const TextScaler.linear(2),
      includeShellNavigation: true,
    );

    expect(find.byKey(const Key('today-covenant-slabs')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('today-record-memory')));
    expect(find.byKey(const Key('today-record-memory')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guided start opens Record from its secondary action', (
    tester,
  ) async {
    final repository = InMemoryPrayerRepository(prayers: const [_prayer]);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);

    await _scrollTo(tester, const Key('today-record-memory'));
    await tester.tap(find.byKey(const Key('today-record-memory')));
    await tester.pumpAndSettle();

    expect(find.text('Record destination'), findsOneWidget);
  });

  testWidgets(
    'selection shows the full prayer and can choose a different one',
    (tester) async {
      final repository = _repository(includeAction: true);
      addTearDown(repository.close);
      await _pumpToday(tester, repository: repository);

      expect(find.text(_prayer.title), findsOneWidget);
      expect(find.text(_prayer.body), findsOneWidget);
      expect(find.byKey(const Key('today-covenant-slabs')), findsOneWidget);
      expect(find.text('Family · General Christian'), findsOneWidget);
      expect(find.text('I prayed this'), findsOneWidget);
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
    expect(find.text('0 of 2 practices completed'), findsOneWidget);
    expect(find.text(_prayerAction), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await _scrollTo(tester, const Key('today-action-done'));
    expect(
      tester.getSize(find.byKey(const Key('today-action-done'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pumpAndSettle();
    await _jumpToTop(tester);

    expect(find.byKey(const Key('today-covenant-slabs')), findsOneWidget);
    expect(
      tester
          .widget<CovenantSlabs>(find.byKey(const Key('today-covenant-slabs')))
          .state,
      const DailyPracticeState(
        available: {DailyPractice.pray, DailyPractice.act},
        completed: {DailyPractice.act},
      ),
    );
    expect(find.text('1 of 2 practices completed'), findsOneWidget);

    expect(repository.completedTodayDate, DateTime(2026, 8, 11));
    expect(repository.completedTodayPrayerId, _prayer.id);
    expect(repository.completedTodayValue, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    _expectNoGamification(tester);
  });

  testWidgets('I prayed this records the displayed prayer and date', (
    tester,
  ) async {
    final repository = _repository(includeAction: true);
    final practiceRepository = _TodayPracticeRepository();
    addTearDown(repository.close);
    addTearDown(practiceRepository.close);
    await _pumpToday(
      tester,
      repository: repository,
      practiceRepository: practiceRepository,
    );

    expect(find.text('0 of 2 practices completed'), findsOneWidget);
    await _scrollTo(tester, const Key('today-prayer-complete'));
    await tester.tap(find.byKey(const Key('today-prayer-complete')));
    await tester.pumpAndSettle();
    await _jumpToTop(tester);

    expect(practiceRepository.recordedPrayer, _prayer.reference);
    expect(practiceRepository.recordedRevisionId, isNull);
    expect(practiceRepository.recordedTimezone, 'Africa/Lagos');
    expect(
      tester
          .widget<CovenantSlabs>(find.byKey(const Key('today-covenant-slabs')))
          .state,
      const DailyPracticeState(
        available: {DailyPractice.pray, DailyPractice.act},
        completed: {DailyPractice.pray},
      ),
    );
    expect(find.text('1 of 2 practices completed'), findsOneWidget);
    expect(find.text('Prayed today'), findsOneWidget);
  });

  testWidgets('prayer completion cannot be submitted twice while pending', (
    tester,
  ) async {
    final repository = _repository(includeAction: false);
    final practiceRepository = _TodayPracticeRepository()..holdRecord = true;
    addTearDown(repository.close);
    addTearDown(practiceRepository.close);
    addTearDown(practiceRepository.release);
    await _pumpToday(
      tester,
      repository: repository,
      practiceRepository: practiceRepository,
    );

    await _scrollTo(tester, const Key('today-prayer-complete'));
    await tester.tap(find.byKey(const Key('today-prayer-complete')));
    await tester.pump();
    await practiceRepository.recordStarted.future;

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('today-prayer-complete')),
    );
    expect(button.onPressed, isNull);
    expect(practiceRepository.recordAttempts, 1);

    practiceRepository.release();
    await tester.pumpAndSettle();
    expect(find.text('Prayed today'), findsOneWidget);
  });

  testWidgets('stale displayed day is never recorded as a new-day prayer', (
    tester,
  ) async {
    final repository = _repository(includeAction: false);
    final practiceRepository = _TodayPracticeRepository();
    addTearDown(repository.close);
    addTearDown(practiceRepository.close);
    await _pumpToday(
      tester,
      repository: repository,
      practiceRepository: practiceRepository,
      now: () => DateTime(2026, 8, 12, 0, 1),
      dateStream: Stream.value((year: 2026, month: 8, day: 11)),
    );

    await _scrollTo(tester, const Key('today-prayer-complete'));
    await tester.tap(find.byKey(const Key('today-prayer-complete')));
    await tester.pumpAndSettle();

    expect(practiceRepository.recordAttempts, 0);
    expect(
      find.text('A new day has begun. Open today\'s prayer again.'),
      findsOneWidget,
    );
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
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('choose-different-prayer')))
          .onPressed,
      isNull,
    );

    repository.release();
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('choose-different-prayer')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('replacement stays incomplete when a prior write finishes', (
    tester,
  ) async {
    final prayerA = _today(includeAction: true);
    final prayerB = TodayPrayer(
      prayer: _nextDayPrayerWithAction,
      localDate: DateTime(2026, 8, 11),
      includeAction: true,
      actionCompleted: false,
    );
    final repository = _ReplacementDuringCompletionRepository(prayerA);
    addTearDown(repository.release);
    addTearDown(repository.close);
    await _pumpToday(tester, repository: repository);
    await _scrollTo(tester, const Key('today-action-done'));

    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pump();
    await repository.started.future;
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('choose-different-prayer')))
          .onPressed,
      isNull,
    );

    repository.replaceWith(prayerB);
    await tester.pump();
    expect(find.text(prayerB.prayer.title), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    repository.release();
    await tester.pumpAndSettle();

    expect(find.text(prayerB.prayer.title), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(repository.current.prayer.id, prayerB.prayer.id);
    expect(repository.current.actionCompleted, isFalse);
  });

  testWidgets('completion targets the date displayed when it was tapped', (
    tester,
  ) async {
    final dateChanges = StreamController<PrayerLocalDate>(sync: true);
    addTearDown(dateChanges.close);
    final repository = _DatedMutationRepository({
      DateTime(2026, 8, 11): TodayPrayer(
        prayer: _prayer,
        localDate: DateTime(2026, 8, 11),
        includeAction: true,
        actionCompleted: false,
      ),
      DateTime(2026, 8, 12): TodayPrayer(
        prayer: _nextDayPrayerWithAction,
        localDate: DateTime(2026, 8, 12),
        includeAction: true,
        actionCompleted: false,
      ),
    });
    addTearDown(repository.close);
    await _pumpToday(
      tester,
      repository: repository,
      dateStream: () async* {
        yield (year: 2026, month: 8, day: 11);
        yield* dateChanges.stream;
      }(),
    );
    await _scrollTo(tester, const Key('today-action-done'));
    expect(find.text(_prayer.title), findsOneWidget);

    dateChanges.add((year: 2026, month: 8, day: 12));
    await tester.tap(find.byKey(const Key('today-action-done')));
    await tester.pumpAndSettle();

    expect(repository.completedDate, DateTime(2026, 8, 11));
    expect(repository.completedPrayerId, _prayer.id);
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

  testWidgets('bounded fallback detects a local wall-clock date change', (
    tester,
  ) async {
    var currentTime = DateTime(2026, 8, 11, 10);
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
    expect(find.text(_prayer.title), findsOneWidget);

    await tester.pump(const Duration(minutes: 15));
    await tester.pumpAndSettle();
    expect(repository.watchedDates, [DateTime(2026, 8, 11)]);

    currentTime = DateTime(2026, 8, 12);
    await tester.pump(const Duration(minutes: 15));
    await tester.pumpAndSettle();

    expect(find.text(_nextDayPrayer.title), findsOneWidget);
    expect(repository.watchedDates, [
      DateTime(2026, 8, 11),
      DateTime(2026, 8, 12),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('app resume immediately resamples the mounted local date', (
    tester,
  ) async {
    var currentTime = DateTime(2026, 8, 11, 10);
    final resumes = StreamController<int>.broadcast(sync: true);
    addTearDown(resumes.close);
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
    await _pumpToday(
      tester,
      repository: repository,
      now: () => currentTime,
      resumeStream: resumes.stream,
    );
    final providerScopeElement = tester.element(find.byType(ProviderScope));
    final todayScreenElement = tester.element(find.byType(TodayScreen));
    expect(find.text(_prayer.title), findsOneWidget);

    currentTime = DateTime(2026, 8, 12);
    resumes.add(1);
    await tester.pumpAndSettle();

    expect(find.text(_nextDayPrayer.title), findsOneWidget);
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
  PrayerPracticeRepository? practiceRepository,
  DateTime Function()? now,
  Stream<PrayerLocalDate>? dateStream,
  Stream<int>? resumeStream,
  TextScaler textScaler = TextScaler.noScaling,
  bool includeShellNavigation = false,
}) async {
  final resolvedPracticeRepository =
      practiceRepository ?? _TodayPracticeRepository();
  if (practiceRepository == null) {
    addTearDown((resolvedPracticeRepository as _TodayPracticeRepository).close);
  }
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(
        path: '/today',
        builder: (context, state) => Scaffold(
          body: const TodayScreen(),
          bottomNavigationBar: includeShellNavigation
              ? NavigationBar(
                  key: const Key('test-shell-navigation'),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today_outlined),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      label: 'Prayers',
                    ),
                  ],
                )
              : null,
        ),
      ),
      GoRoute(
        path: '/prayers',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Prayer library destination')),
        ),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Record destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWith((ref) async => repository),
        prayerPracticeRepositoryProvider.overrideWith(
          (ref) async => resolvedPracticeRepository,
        ),
        prayerDeviceTimezoneProvider.overrideWithValue(
          () async => 'Africa/Lagos',
        ),
        prayerPracticeClockProvider.overrideWithValue(
          now ?? () => DateTime(2026, 8, 11, 12),
        ),
        dailyMemoryProvider.overrideWith((ref) => Stream.value(null)),
        prayerClockProvider.overrideWithValue(
          now ?? () => DateTime(2026, 8, 11, 12),
        ),
        if (dateStream != null)
          todayPrayerDateProvider.overrideWith((ref) => dateStream),
        if (resumeStream != null)
          prayerAppResumeProvider.overrideWith((ref) => resumeStream),
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

Future<void> _jumpToTop(WidgetTester tester) async {
  tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
  await tester.pumpAndSettle();
}

class _TodayPracticeRepository implements PrayerPracticeRepository {
  final _sessionChanges = StreamController<bool>.broadcast(sync: true);
  final recordStarted = Completer<void>();
  final _recordRelease = Completer<void>();
  var _hasSession = false;
  var holdRecord = false;
  var recordAttempts = 0;
  PrayerReference? recordedPrayer;
  String? recordedRevisionId;
  String? recordedTimezone;

  Future<void> close() => _sessionChanges.close();

  void release() {
    if (!_recordRelease.isCompleted) _recordRelease.complete();
  }

  @override
  Stream<bool> watchSessionForDate(
    PrayerReference prayer,
    DateTime localDate, {
    String? revisionId,
  }) async* {
    yield _hasSession;
    yield* _sessionChanges.stream;
  }

  @override
  Future<PrayerSession> recordSession({
    required PrayerReference prayer,
    required String timezone,
    String? revisionId,
    String? reminderId,
    String? occurrenceKey,
    String? idempotencyKey,
  }) async {
    recordAttempts++;
    if (!recordStarted.isCompleted) recordStarted.complete();
    if (holdRecord) await _recordRelease.future;
    recordedPrayer = prayer;
    recordedRevisionId = revisionId;
    recordedTimezone = timezone;
    _hasSession = true;
    _sessionChanges.add(true);
    return PrayerSession(
      id: 'session-today',
      ownerId: 'owner-1',
      prayer: prayer,
      prayerRevisionId: revisionId,
      source: PrayerSessionSource.manual,
      occurredAt: DateTime(2026, 8, 11, 12),
      localDate: DateTime(2026, 8, 11),
      timezone: timezone,
      deviceId: 'device-1',
    );
  }

  @override
  Stream<PrayerReminder?> watchReminder(String personalPrayerId) =>
      const Stream.empty();
  @override
  Stream<PrayerReminderDevice?> watchDevice(String reminderId) =>
      const Stream.empty();
  @override
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc) =>
      const Stream.empty();
  @override
  Stream<int> watchSessionCount(String revisionId) => Stream.value(0);
  @override
  Future<int> getSessionCount(String revisionId) async => 0;
  @override
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  }) => throw UnimplementedError();
  @override
  Future<void> archiveReminder(String reminderId) async {}
  @override
  Future<void> setDeviceEnabled(
    String reminderId, {
    required bool enabled,
  }) async {}
  @override
  Future<void> saveNarrationPreference({
    required String reminderId,
    required bool consentAccepted,
    required bool autoplayWhenOpened,
    String? revisionId,
    List<int>? bytes,
    String? contentType,
  }) async {}
  @override
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  }) async {}
  @override
  Future<void> snooze(String reminderId, DateTime untilUtc) async {}
  @override
  Future<void> dismiss(String reminderId, String occurrenceKey) async {}
  @override
  Future<void> retractSession(String sessionId) async {}
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
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    await super.completeTodayAction(
      localDate,
      expectedPrayer: expectedPrayer,
      value: value,
    );
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
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    throw StateError('private prayer text must never be logged');
  }
}

class _ReplacementDuringCompletionRepository extends InMemoryPrayerRepository {
  _ReplacementDuringCompletionRepository(this.current)
    : super(prayers: const [_prayer, _nextDayPrayerWithAction]);

  TodayPrayer current;
  final started = Completer<void>();
  final _release = Completer<void>();
  final _todayChanges = StreamController<TodayPrayer>.broadcast(sync: true);

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) async* {
    yield current;
    yield* _todayChanges.stream;
  }

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    if (!started.isCompleted) started.complete();
    await _release.future;
    if (current.localDate == localDate &&
        current.prayer.reference == expectedPrayer) {
      current = TodayPrayer(
        prayer: current.prayer,
        localDate: current.localDate,
        includeAction: current.includeAction,
        actionCompleted: value,
      );
      _todayChanges.add(current);
    }
  }

  void replaceWith(TodayPrayer replacement) {
    current = replacement;
    _todayChanges.add(replacement);
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<void> close() async {
    await _todayChanges.close();
    await super.close();
  }
}

class _DatedPrayerRepository extends InMemoryPrayerRepository {
  _DatedPrayerRepository(this.selections)
    : super(
        prayers: selections.values
            .map((today) => today.prayer)
            .whereType<LibraryPrayer>()
            .toList(),
      );

  final Map<DateTime, TodayPrayer> selections;
  final List<DateTime> watchedDates = [];

  @override
  Stream<TodayPrayer?> watchToday(DateTime localDate) async* {
    watchedDates.add(localDate);
    yield selections[localDate];
  }
}

class _DatedMutationRepository extends _DatedPrayerRepository {
  _DatedMutationRepository(super.selections);

  DateTime? completedDate;
  String? completedPrayerId;

  @override
  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  }) async {
    completedDate = localDate;
    completedPrayerId = expectedPrayer.id;
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

const _nextDayPrayerWithAction = LibraryPrayer(
  id: 'gratitude-action',
  title: 'For a new day with action',
  body: 'Father, thank you for this new day. Keep me near you. Amen.',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.gratitude,
  helpfulCount: 4,
  viewerMarkedHelpful: false,
  action: 'Thank someone today.',
);
