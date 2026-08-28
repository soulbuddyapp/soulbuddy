import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../application/goal_today_composer.dart';
import '../application/goal_today_resource_adapter.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../domain/goal_link.dart';
import 'goal_providers.dart';

class GoalTodaySnapshot {
  const GoalTodaySnapshot({
    required this.localDate,
    required this.activeGoalCount,
    required this.sections,
    required this.resources,
  });

  final DateTime localDate;
  final int activeGoalCount;
  final List<GoalTodaySection> sections;
  final GoalTodayResourceProjection resources;
}

final activeGoalTodayLinksProvider = StreamProvider.autoDispose<List<GoalLink>>(
  (ref) async* {
    final database = await ref.watch(appDatabaseProvider.future);
    final identity = await ref.watch(localIdentityProvider.future);
    yield* database.powersync
        .watch(
          '''
        SELECT link.*
        FROM goal_links AS link
        JOIN goals AS goal
          ON goal.id = link.goal_id
         AND goal.owner_id = link.owner_id
        WHERE link.owner_id = ?
          AND link.archived_at IS NULL
          AND goal.status = 'active'
          AND goal.archived_at IS NULL
        ORDER BY goal.position ASC, link.created_at ASC, link.id ASC
        ''',
          parameters: [identity.ownerId],
        )
        .map((rows) => List.unmodifiable(rows.map(GoalLink.fromRow)));
  },
);

final goalTodaySnapshotProvider =
    Provider.autoDispose<AsyncValue<GoalTodaySnapshot>>((ref) {
      late final DateTime localDate;
      switch (ref.watch(todayPrayerDateProvider)) {
        case AsyncData(:final value):
          localDate = DateTime(value.year, value.month, value.day);
        case AsyncError(:final error, :final stackTrace):
          return AsyncError(error, stackTrace);
        case AsyncLoading():
          return const AsyncLoading();
      }

      late final List<Goal> goals;
      switch (ref.watch(activeGoalsProvider)) {
        case AsyncData(:final value):
          goals = value;
        case AsyncError(:final error, :final stackTrace):
          return AsyncError(error, stackTrace);
        case AsyncLoading():
          return const AsyncLoading();
      }

      late final List<GoalLink> links;
      switch (ref.watch(activeGoalTodayLinksProvider)) {
        case AsyncData(:final value):
          links = value;
        case AsyncError(:final error, :final stackTrace):
          return AsyncError(error, stackTrace);
        case AsyncLoading():
          return const AsyncLoading();
      }

      late final List<GoalActionOccurrence> actions;
      switch (ref.watch(dueGoalActionsProvider(localDate))) {
        case AsyncData(:final value):
          actions = value;
        case AsyncError(:final error, :final stackTrace):
          return AsyncError(error, stackTrace);
        case AsyncLoading():
          return const AsyncLoading();
      }

      final reminders = switch (ref.watch(duePrayerOccurrencesProvider)) {
        AsyncData(:final value) => value,
        _ => const <DuePrayerOccurrence>[],
      };
      final legacyToday = switch (ref.watch(todayPrayerProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };

      final resources = const GoalTodayResourceAdapter().project(
        activeGoalLinks: links,
        duePrayerOccurrences: reminders,
        legacyToday: legacyToday,
      );
      final sections = const GoalTodayComposer().compose(
        goals: goals,
        dueActions: actions,
        resources: resources.candidates,
      );
      return AsyncData(
        GoalTodaySnapshot(
          localDate: localDate,
          activeGoalCount: goals.length,
          sections: sections,
          resources: resources,
        ),
      );
    });
