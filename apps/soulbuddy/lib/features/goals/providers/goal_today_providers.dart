import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/prayer_reference.dart';
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

/// Small, read-only display projection for Goal-linked prayer titles.
///
/// This deliberately returns no prayer body and performs one indexed watch for
/// all active Goal links. Canonical library content shadows the bundled copy in
/// the same way as the prayer library repository; if metadata is unavailable,
/// Today falls back to the neutral `Prayer` label rather than hiding the link.
final activeGoalPrayerTitlesProvider =
    StreamProvider.autoDispose<Map<PrayerReference, String>>((ref) async* {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      yield* database.powersync
          .watch(
            '''
            SELECT link.link_type,
                   link.personal_prayer_id,
                   link.library_prayer_id,
                   CASE
                     WHEN link.link_type = 'personal_prayer'
                       THEN personal.title
                     WHEN canonical.id IS NOT NULL
                       THEN canonical.title
                     WHEN bundled.id IS NOT NULL
                       THEN bundled.title
                   END AS title
            FROM goal_links AS link
            JOIN goals AS goal
              ON goal.id = link.goal_id
             AND goal.owner_id = link.owner_id
            LEFT JOIN personal_prayers AS personal
              ON link.link_type = 'personal_prayer'
             AND personal.id = link.personal_prayer_id
             AND personal.owner_id = link.owner_id
             AND personal.archived_at IS NULL
            LEFT JOIN library_prayers AS canonical
              ON link.link_type = 'library_prayer'
             AND canonical.id = link.library_prayer_id
             AND canonical.published_at IS NOT NULL
             AND canonical.archived_at IS NULL
            LEFT JOIN bundled_prayers AS bundled
              ON link.link_type = 'library_prayer'
             AND bundled.id = link.library_prayer_id
             AND bundled.archived_at IS NULL
             AND NOT EXISTS (
               SELECT 1
               FROM library_prayers AS shadow
               WHERE shadow.id = bundled.id
             )
            WHERE link.owner_id = ?
              AND link.archived_at IS NULL
              AND goal.status = 'active'
              AND goal.archived_at IS NULL
              AND link.link_type IN ('personal_prayer', 'library_prayer')
            ORDER BY goal.position ASC, link.created_at ASC, link.id ASC
            ''',
            parameters: [identity.ownerId],
          )
          .map((rows) {
            final titles = <PrayerReference, String>{};
            for (final row in rows) {
              final title = (row['title'] as String?)?.trim();
              if (title == null || title.isEmpty) continue;
              switch (row['link_type']) {
                case 'personal_prayer':
                  final id = row['personal_prayer_id'] as String?;
                  if (id != null) titles[PrayerReference.personal(id)] = title;
                case 'library_prayer':
                  final id = row['library_prayer_id'] as String?;
                  if (id != null) titles[PrayerReference.library(id)] = title;
              }
            }
            return Map.unmodifiable(titles);
          });
    });

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
      final prayerTitles = switch (ref.watch(activeGoalPrayerTitlesProvider)) {
        AsyncData(:final value) => value,
        _ => const <PrayerReference, String>{},
      };

      final resources = const GoalTodayResourceAdapter().project(
        activeGoalLinks: links,
        duePrayerOccurrences: reminders,
        prayerTitles: prayerTitles,
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
