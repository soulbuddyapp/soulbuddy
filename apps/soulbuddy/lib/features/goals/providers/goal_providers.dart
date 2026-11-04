import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../data/goal_onboarding_progress_repository.dart';
import '../data/goal_orderer.dart';
import '../data/goal_prayer_migration.dart';
import '../data/goal_repository.dart';
import '../data/powersync_goal_onboarding_progress_repository.dart';
import '../data/powersync_goal_orderer.dart';
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

final goalOrdererProvider = FutureProvider<GoalOrderer>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncGoalOrderer(
    database: database.powersync,
    ownerId: identity.ownerId,
  );
});

final goalPrayerMigrationProvider = FutureProvider<GoalPrayerMigration>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncGoalPrayerMigration(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final prayerLinkedToGoalProvider = StreamProvider.autoDispose
    .family<bool, PrayerReference>((ref, prayer) async* {
      final migration = await ref.watch(goalPrayerMigrationProvider.future);
      yield* migration.watchLinked(prayer);
    });

final goalOnboardingProgressRepositoryProvider =
    FutureProvider<GoalOnboardingProgressRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncGoalOnboardingProgressRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
      );
    });

final goalOnboardingProgressProvider =
    FutureProvider.autoDispose<GoalOnboardingProgress?>((ref) async {
      final repository = await ref.watch(
        goalOnboardingProgressRepositoryProvider.future,
      );
      return repository.load();
    });

final activeGoalsProvider = StreamProvider.autoDispose<List<Goal>>((
  ref,
) async* {
  final repository = await ref.watch(goalRepositoryProvider.future);
  yield* repository.watchActive();
});

final visibleGoalsProvider = StreamProvider.autoDispose<List<Goal>>((
  ref,
) async* {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  yield* database.powersync
      .watch(
        '''
        SELECT goal.*, revision.title, revision.current_situation,
               revision.why_it_matters,
               (SELECT action.body FROM goal_actions AS action
                WHERE action.goal_id = goal.id
                  AND action.owner_id = goal.owner_id
                  AND action.archived_at IS NULL
                ORDER BY action.created_at DESC, action.id DESC
                LIMIT 1) AS next_action
        FROM goals AS goal
        JOIN goal_revisions AS revision
          ON revision.id = goal.current_revision_id
         AND revision.goal_id = goal.id
         AND revision.owner_id = goal.owner_id
        WHERE goal.owner_id = ?
          AND goal.archived_at IS NULL
        ORDER BY CASE goal.status
                   WHEN 'active' THEN 0
                   WHEN 'paused' THEN 1
                   WHEN 'completed' THEN 2
                   ELSE 3
                 END ASC,
                 goal.position ASC,
                 goal.updated_at DESC,
                 goal.id ASC
        ''',
        parameters: [identity.ownerId],
      )
      .map((rows) => List.unmodifiable(rows.map(Goal.fromRow)));
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
