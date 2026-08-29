import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../goals/domain/goal_action.dart';
import '../../goals/domain/goal_link.dart';
import '../../goals/providers/goal_providers.dart';
import '../application/return_plan.dart';
import '../domain/guard_definition.dart';
import 'guard_providers.dart';

final goalReturnActionsProvider = StreamProvider.autoDispose
    .family<List<GoalAction>, String>((ref, goalId) async* {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      yield* database.powersync
          .watch(
            '''
            SELECT * FROM goal_actions
            WHERE goal_id = ?
              AND owner_id = ?
              AND enabled = 1
              AND archived_at IS NULL
            ORDER BY created_at ASC, id ASC
            ''',
            parameters: [goalId, identity.ownerId],
          )
          .map((rows) => List.unmodifiable(rows.map(GoalAction.fromRow)));
    });

final goalReturnLinksProvider = StreamProvider.autoDispose
    .family<List<GoalLink>, String>((ref, goalId) async* {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      yield* database.powersync
          .watch(
            '''
            SELECT * FROM goal_links
            WHERE goal_id = ?
              AND owner_id = ?
              AND archived_at IS NULL
            ORDER BY created_at ASC, id ASC
            ''',
            parameters: [goalId, identity.ownerId],
          )
          .map((rows) => List.unmodifiable(rows.map(GoalLink.fromRow)));
    });

final goalReturnPlanProvider = Provider.autoDispose
    .family<AsyncValue<ReturnPlan>, String>((ref, goalId) {
      final goal = ref.watch(goalProvider(goalId));
      if (goal case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (goal case AsyncLoading()) return const AsyncLoading();

      final resolvedGoal = goal.requireValue;
      if (resolvedGoal == null) {
        return AsyncError(
          StateError('Goal is not available'),
          StackTrace.current,
        );
      }

      final actions = ref.watch(goalReturnActionsProvider(goalId));
      final links = ref.watch(goalReturnLinksProvider(goalId));
      final guards = ref.watch(goalGuardSelectionsProvider(goalId));
      final unavailable = <ReturnPlanPart>{};

      final resolvedActions = switch (actions) {
        AsyncData(:final value) => value,
        AsyncError() => () {
          unavailable.add(ReturnPlanPart.actions);
          return const <GoalAction>[];
        }(),
        AsyncLoading() => const <GoalAction>[],
      };
      final resolvedLinks = switch (links) {
        AsyncData(:final value) => value,
        AsyncError() => () {
          unavailable.add(ReturnPlanPart.spiritualResources);
          return const <GoalLink>[];
        }(),
        AsyncLoading() => const <GoalLink>[],
      };
      final resolvedGuards = switch (guards) {
        AsyncData(:final value) => value,
        AsyncError() => () {
          unavailable.add(ReturnPlanPart.guards);
          return const <GoalGuardSelection>[];
        }(),
        AsyncLoading() => const <GoalGuardSelection>[],
      };

      return AsyncData(
        ReturnPlanBuilder.build(
          goal: resolvedGoal,
          actions: resolvedActions,
          links: resolvedLinks,
          guardSelections: resolvedGuards,
          unavailableParts: unavailable,
        ),
      );
    });
