import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';
import 'package:soulbuddy/features/goals/providers/goal_providers.dart';
import 'package:soulbuddy/features/onboarding/data/onboarding_repository.dart';
import 'package:soulbuddy/features/onboarding/data/first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';
import 'package:soulbuddy/features/onboarding/presentation/onboarding_gate.dart';
import 'package:soulbuddy/features/onboarding/providers/first_prayer_providers.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_scheduler.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/sacred_hours/data/sacred_hour_repository.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/providers/sacred_hour_providers.dart';

void main() {
  testWidgets('system back dismisses popup then reader then orientation', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository, outsideNavigator: true);
    await tester.tap(find.byKey(const Key('onboarding-orientation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation-course-00-welcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation-speed')));
    await tester.pumpAndSettle();
    expect(find.text('0.75×'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('0.75×'), findsNothing);
    expect(find.byKey(const Key('orientation-play')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settleAudioClose(tester);
    expect(find.byKey(const Key('orientation-play')), findsNothing);
    expect(find.text('Orientation'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Come as you are'), findsOneWidget);
    expect(repository.completed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reader skip outside the router finishes onboarding and opens Today',
    (tester) async {
      final repository = _MemoryOnboardingRepository();
      var skippedToToday = false;
      await _pumpGate(
        tester,
        repository,
        outsideNavigator: true,
        onSkip: () => skippedToToday = true,
      );
      await tester.tap(find.byKey(const Key('onboarding-orientation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('orientation-course-00-welcome')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip for now'));
      await _settleAudioClose(tester);
      expect(repository.completed, isTrue);
      expect(skippedToToday, isTrue);
      expect(find.text('Routed app'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reader speed menu works outside the router navigator', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository, outsideNavigator: true);
    await tester.tap(find.byKey(const Key('onboarding-orientation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation-course-00-welcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation-speed')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0.75×'), findsOneWidget);
    await tester.tap(find.text('0.75×'));
    await tester.pumpAndSettle();
    expect(repository.completed, isFalse);
    await tester.tap(find.byTooltip('Back to orientation'));
    await _settleAudioClose(tester);
    expect(find.text('Orientation'), findsOneWidget);
  });

  testWidgets('orientation is optional and its skip still opens Today', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository);
    await tester.tap(find.byKey(const Key('onboarding-orientation')));
    await tester.pumpAndSettle();
    expect(find.text('Orientation'), findsOneWidget);
    expect(repository.completed, isFalse);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(repository.completed, isTrue);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('first use shows welcome instead of the routed app', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await _pumpGate(tester, repository);

    expect(find.text('Come as you are'), findsOneWidget);
    expect(find.text('Routed app'), findsNothing);
  });

  testWidgets('completed welcome shows the routed app', (tester) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    await _pumpGate(tester, repository);

    expect(find.text('Routed app'), findsOneWidget);
    expect(find.text('Come as you are'), findsNothing);
  });

  testWidgets('completed welcome resumes a saved legacy first prayer', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    var resumedPrayer = false;
    var resumedGoal = false;
    await _pumpGate(
      tester,
      repository,
      progressRepository: _MemoryProgressRepository(
        const FirstPrayerProgress(stage: FirstPrayerStage.frequency),
      ),
      goalProgress: const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.direction,
      ),
      onResumeFirstPrayer: () => resumedPrayer = true,
      onBeginWithGoal: () => resumedGoal = true,
    );

    expect(resumedPrayer, isTrue);
    expect(resumedGoal, isFalse);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('completed welcome resumes a saved first Goal', (tester) async {
    final repository = _MemoryOnboardingRepository(completed: true);
    var resumedGoal = false;
    await _pumpGate(
      tester,
      repository,
      goalProgress: const GoalOnboardingProgress(
        stage: GoalOnboardingStage.agency,
        starterKey: GoalStarterKey.direction,
        title: 'Find direction',
      ),
      onBeginWithGoal: () => resumedGoal = true,
    );

    expect(resumedGoal, isTrue);
    expect(find.text('Routed app'), findsOneWidget);
  });

  testWidgets('final welcome action persists and opens Goal choices', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    final sacredHours = _MemorySacredHourRepository();
    final scheduler = _Scheduler();
    var openedGoalChoices = false;
    await _pumpGate(
      tester,
      repository,
      sacredHours: sacredHours,
      scheduler: scheduler,
      onBeginWithGoal: () => openedGoalChoices = true,
    );

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep these hours'));
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(sacredHours.ensureDefaultsCalls, 1);
    expect(sacredHours.saved, hasLength(2));
    expect(scheduler.permissionRequests, 1);
    expect(openedGoalChoices, isTrue);
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
  VoidCallback? onBeginWithGoal,
  VoidCallback? onResumeFirstPrayer,
  VoidCallback? onSkip,
  FirstPrayerProgressRepository? progressRepository,
  GoalOnboardingProgress? goalProgress,
  _MemorySacredHourRepository? sacredHours,
  _Scheduler? scheduler,
  bool outsideNavigator = false,
}) async {
  final sacredHourRepository = sacredHours ?? _MemorySacredHourRepository();
  final orientationValues = <String, String>{};
  Widget gate(Widget child) => OnboardingGate(
    onBeginWithGoal: onBeginWithGoal ?? () {},
    onResumeFirstPrayer: onResumeFirstPrayer ?? () {},
    onSkip: onSkip ?? () {},
    child: child,
  );
  final router = outsideNavigator
      ? GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Routed app')),
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orientationCatalogProvider.overrideWith(
          (ref) async => const [
            OrientationCourse(
              id: '00-welcome',
              title: 'Welcome',
              tenet: 'Begin here',
              audioAsset: 'welcome.mp3',
              transcriptAsset: 'welcome.json',
              duration: Duration(seconds: 30),
            ),
          ],
        ),
        orientationTranscriptProvider.overrideWith(
          (ref, path) async => const OrientationTranscript(
            text: 'Welcome to SoulBuddy.',
            words: [
              TranscriptCue(startMs: 0, endMs: 1000, charStart: 0, charEnd: 7),
            ],
            sentences: [
              TranscriptCue(startMs: 0, endMs: 3000, charStart: 0, charEnd: 21),
            ],
            duration: Duration(seconds: 30),
          ),
        ),
        orientationProgressRepositoryProvider.overrideWithValue(
          OrientationProgressRepository(
            read: (key) async => orientationValues[key],
            write: (key, value) async {
              orientationValues[key] = value;
            },
          ),
        ),
        orientationPlayerFactoryProvider.overrideWithValue(
          _OrientationPlayer.new,
        ),
        onboardingRepositoryProvider.overrideWithValue(repository),
        firstPrayerProgressRepositoryProvider.overrideWith(
          (ref) async => progressRepository ?? _MemoryProgressRepository(null),
        ),
        goalOnboardingProgressProvider.overrideWith(
          (ref) async => goalProgress,
        ),
        prayerDeviceTimezoneProvider.overrideWithValue(
          () async => 'Africa/Lagos',
        ),
        sacredHourRepositoryProvider.overrideWith(
          (ref) async => sacredHourRepository,
        ),
        prayerReminderSchedulerProvider.overrideWithValue(
          scheduler ?? _Scheduler(),
        ),
      ],
      child: outsideNavigator
          ? MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light(),
              builder: (_, child) => gate(child ?? const SizedBox()),
            )
          : MaterialApp(
              theme: AppTheme.light(),
              home: OnboardingGate(
                onBeginWithGoal: onBeginWithGoal ?? () {},
                onResumeFirstPrayer: onResumeFirstPrayer ?? () {},
                onSkip: onSkip ?? () {},
                child: const Scaffold(body: Center(child: Text('Routed app'))),
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleAudioClose(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Stream cancellation uses the real event loop even in a widget test.
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

class _OrientationPlayer implements OrientationPlayer {
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> prepare(String asset) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> close() async {}
}

class _MemorySacredHourRepository implements SacredHourRepository {
  final saved = <SacredHourDraft>[];
  var ensureDefaultsCalls = 0;

  @override
  Future<List<SacredHour>> ensureDefaults({required String timezone}) async {
    ensureDefaultsCalls += 1;
    return [
      SacredHour.defaultMorning(ownerId: 'owner', timezone: timezone),
      SacredHour.defaultEvening(ownerId: 'owner', timezone: timezone),
    ];
  }

  @override
  Future<SacredHour> save(SacredHourDraft draft, {String? id}) async {
    saved.add(draft);
    return SacredHour(
      id: id!,
      ownerId: 'owner',
      purpose: draft.purpose,
      name: draft.name,
      localTime: draft.localTime,
      timezone: draft.timezone,
      durationMinutes: draft.durationMinutes,
      prayerMinutes: draft.prayerMinutes,
      enabled: draft.enabled,
      sound: draft.sound,
      prayer: draft.prayer,
      personId: draft.personId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> markOccurrence(
    String id,
    DateTime dueAt,
    SacredHourOccurrenceStatus status, {
    String? prayerSessionId,
  }) async {}
  @override
  Future<void> setEnabled(String id, bool enabled) async {}
  @override
  Future<void> updateDeviceDelivery(
    String id,
    SacredHourDeviceDraft draft,
  ) async {}
  @override
  Stream<List<SacredHour>> watchActive() => const Stream.empty();
  @override
  Stream<List<SacredHour>> watchAll() => const Stream.empty();
  @override
  Stream<SacredHour?> watch(String id) => const Stream.empty();
  @override
  Stream<SacredHour?> watchCurrentOrNext(DateTime nowUtc) =>
      const Stream.empty();
  @override
  Stream<List<SacredHourDelivery>> watchDeliveries() => const Stream.empty();
}

class _Scheduler implements PrayerReminderScheduler {
  var permissionRequests = 0;
  @override
  bool get supportsSystemNotifications => true;
  @override
  Stream<PrayerReminderResponse> get responses => const Stream.empty();
  @override
  Future<void> cancel(int platformNotificationId) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<NotificationPermissionStatus> permissionStatus() async =>
      NotificationPermissionStatus.denied;
  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return false;
  }

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {}
  @override
  Future<void> showTestReminder() async {}
}

class _MemoryProgressRepository implements FirstPrayerProgressRepository {
  _MemoryProgressRepository(this.progress);

  FirstPrayerProgress? progress;

  @override
  Future<void> clear() async => progress = null;

  @override
  Future<FirstPrayerProgress?> load() async => progress;

  @override
  Future<void> save(FirstPrayerProgress value) async => progress = value;
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
