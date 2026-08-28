import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/goal_onboarding_progress_repository.dart';
import '../data/goal_repository.dart';
import '../data/powersync_goal_onboarding_progress_repository.dart';
import '../data/powersync_goal_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../domain/goal_onboarding_progress.dart';

final goalRepositoryProvider = FutureProvider<GoalRepository>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncGoalRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final goalOnboardingProgressRepositoryProvider =
    FutureProvider<GoalOnboardingProgressRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      return PowerSyncGoalOnboardingProgressRepository(
        database: database.powersync,
      );
    });

final goalOnboardingProgressProvider =
    FutureProvider.autoDispose<GoalOnboardingProgress?>((ref) async {
      final repository = await ref.watch(
        goalOnboardingProgressRepositoryProvider.future,
      );
      return repository.load();
    });

final activeGoalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) async* {
  final repository = await ref.watch(goalRepositoryProvider.future);
  yield* repository.watchActive();
});

final goalProvider = StreamProvider.autoDispose.family<Goal?, String>((
  ref,
  goalId,
) async* {
  final repository = await ref.watch(goalRepositoryProvider.future);
  yield* repository.watch(goalId);
});

final dueGoalActionsProvider = StreamProvider.autoDispose
    .family<List<GoalActionOccurrence>, DateTime>((ref, localDate) async* {
      final repository = await ref.watch(goalRepositoryProvider.future);
      yield* repository.watchDueActions(localDate);
    });
