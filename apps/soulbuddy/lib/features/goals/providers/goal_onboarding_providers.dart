import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../application/goal_onboarding_flow.dart';
import '../application/goal_starter_content.dart';
import '../data/goal_onboarding_finalizer.dart';
import '../data/powersync_goal_onboarding_finalizer.dart';
import '../domain/goal.dart';
import '../domain/goal_onboarding_progress.dart';
import 'goal_providers.dart';

final goalOnboardingFinalizerProvider =
    FutureProvider<GoalOnboardingFinalizer>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncGoalOnboardingFinalizer(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
      );
    });

final firstGoalPrayerOptionsProvider = FutureProvider.autoDispose
    .family<List<LibraryPrayer>, GoalStarterKey>((ref, starterKey) async {
      final repository = await ref.watch(prayerRepositoryProvider.future);
      var prayers = await repository
          .watchLibrary(purpose: prayerPurposeForGoalStarter(starterKey))
          .first;
      if (prayers.isEmpty) {
        prayers = await repository.watchLibrary().first;
      }
      return List.unmodifiable(prayers.take(3));
    });

final goalOnboardingControllerProvider = AsyncNotifierProvider.autoDispose<
  GoalOnboardingController,
  GoalOnboardingProgress
>(GoalOnboardingController.new);

class GoalOnboardingController extends AsyncNotifier<GoalOnboardingProgress> {
  @override
  Future<GoalOnboardingProgress> build() async {
    final repository = await ref.watch(
      goalOnboardingProgressRepositoryProvider.future,
    );
    final saved = await repository.load();
    if (saved != null) return saved;

    const initial = GoalOnboardingProgress();
    await repository.save(initial);
    return initial;
  }

  GoalOnboardingProgress get _value => state.requireValue;

  GoalMode get inferredMode => GoalOnboardingFlow.inferredMode(_value);

  Future<void> chooseStarter(GoalStarterKey starterKey) =>
      _persist(GoalOnboardingFlow.chooseStarter(starterKey));

  Future<void> setTitle(String title) =>
      _persist(GoalOnboardingFlow.setTitle(_value, title));

  Future<void> setSituation({String? situation, required bool byVoice}) =>
      _persist(
        GoalOnboardingFlow.setSituation(
          _value,
          situation: situation,
          byVoice: byVoice,
        ),
      );

  Future<void> chooseAgency(GoalAgencyChoice choice) =>
      _persist(GoalOnboardingFlow.chooseAgency(_value, choice));

  Future<void> setTodayAction(String? action) async {
    var next = GoalOnboardingFlow.setTodayAction(_value, action);
    if (next.stage == GoalOnboardingStage.accountability) {
      next = GoalOnboardingFlow.chooseAccountability(
        next,
        GoalAccountabilityChoice.notNow,
      );
    }
    await _persist(next);
  }

  Future<void> setGuardNote(String? guardNote) async {
    var next = GoalOnboardingFlow.setGuardNote(_value, guardNote);
    next = GoalOnboardingFlow.chooseAccountability(
      next,
      GoalAccountabilityChoice.notNow,
    );
    await _persist(next);
  }

  Future<void> chooseAccountability(GoalAccountabilityChoice choice) =>
      _persist(GoalOnboardingFlow.chooseAccountability(_value, choice));

  Future<void> chooseLibraryPrayer(String prayerId) =>
      _persist(GoalOnboardingFlow.chooseLibraryPrayer(_value, prayerId));

  Future<void> choosePersonalPrayer(String prayerId) =>
      _persist(GoalOnboardingFlow.choosePersonalPrayer(_value, prayerId));

  Future<void> chooseScripture({
    required String translation,
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) => _persist(
    GoalOnboardingFlow.chooseScripture(
      _value,
      translation: translation,
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
    ),
  );

  Future<void> useOwnWords(String prayer) =>
      _persist(GoalOnboardingFlow.useOwnWords(_value, prayer));

  Future<void> beginSaving() =>
      _persist(GoalOnboardingFlow.beginSaving(_value));

  Future<GoalOnboardingFinalizationResult> finalize() async {
    final finalizer = await ref.read(goalOnboardingFinalizerProvider.future);
    final result = await finalizer.finalize(_value);
    ref.invalidate(goalOnboardingProgressProvider);
    ref.invalidate(activeGoalsProvider);
    state = const AsyncData(GoalOnboardingProgress());
    return result;
  }

  Future<void> goBack() async {
    var next = GoalOnboardingFlow.goBack(_value);
    if (next.stage == GoalOnboardingStage.accountability &&
        next.accountabilityChoice == GoalAccountabilityChoice.notNow) {
      next = GoalOnboardingFlow.goBack(next);
    }
    await _persist(next);
  }

  Future<void> restart() => _persist(const GoalOnboardingProgress());

  Future<void> _persist(GoalOnboardingProgress next) async {
    final previous = _value;
    state = AsyncData(next);
    try {
      final repository = await ref.read(
        goalOnboardingProgressRepositoryProvider.future,
      );
      await repository.save(next);
      ref.invalidate(goalOnboardingProgressProvider);
    } on Object catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
