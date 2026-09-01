import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  FirstPrayerProgressRepository? progressRepository,
  GoalOnboardingProgress? goalProgress,
  _MemorySacredHourRepository? sacredHours,
  _Scheduler? scheduler,
}) async {
  final sacredHourRepository = sacredHours ?? _MemorySacredHourRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
      child: MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingGate(
          onBeginWithGoal: onBeginWithGoal ?? () {},
          onResumeFirstPrayer: onResumeFirstPrayer ?? () {},
          onSkip: () {},
          child: const Scaffold(body: Center(child: Text('Routed app'))),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
