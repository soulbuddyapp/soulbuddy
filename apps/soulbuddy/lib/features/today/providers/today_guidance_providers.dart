import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../application/today_guidance_engine.dart';
import '../data/powersync_today_guidance_repository.dart';
import '../data/today_guidance_repository.dart';
import '../domain/today_guidance.dart';
import '../domain/daily_practice_state.dart';
import 'daily_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../goals/application/goal_today_composer.dart';
import '../../goals/providers/goal_today_providers.dart';
import '../../persons/providers/person_providers.dart';
import '../../altar/providers/altar_ritual_providers.dart';
import '../../altar/domain/altar_ritual.dart';

final todayGuidanceRepositoryProvider = FutureProvider<TodayGuidanceRepository>(
  (ref) async {
    final database = await ref.watch(appDatabaseProvider.future);
    final identity = await ref.watch(localIdentityProvider.future);
    return PowerSyncTodayGuidanceRepository(
      database: database.powersync,
      ownerId: identity.ownerId,
    );
  },
);

final todayGuidanceFactsProvider = StreamProvider<TodayGuidanceSnapshot>((
  ref,
) async* {
  final dateValue = await ref.watch(todayPrayerDateProvider.future);
  final repository = await ref.watch(todayGuidanceRepositoryProvider.future);
  yield* repository.watch(
    DateTime(dateValue.year, dateValue.month, dateValue.day),
  );
});

final todayGuidanceProvider = Provider<AsyncValue<TodayGuidanceCardValue>>((
  ref,
) {
  final facts = ref.watch(todayGuidanceFactsProvider);
  final practices = ref.watch(dailyPracticeStateProvider);
  if (facts case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (practices case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!facts.hasValue || !practices.hasValue) return const AsyncLoading();
  final fact = facts.requireValue;
  final state = practices.requireValue;
  final duePractices = {...state.available};
  final goalToday = ref.watch(goalTodaySnapshotProvider);
  if (goalToday case AsyncData(:final value)
      when value.sections.any(
        (section) => section.items.any((item) => item is GoalTodayActionItem),
      )) {
    duePractices.add(DailyPractice.act);
  }
  final localDate = ref.watch(todayPrayerDateProvider).value;
  var hasDuePerson = false;
  if (localDate != null) {
    final people = ref.watch(
      duePersonPrayersProvider(
        DateTime(localDate.year, localDate.month, localDate.day),
      ),
    );
    if (people case AsyncData(:final value) when value.isNotEmpty) {
      hasDuePerson = true;
    }
  }
  final dueAltar = ref.watch(dueAltarRitualProvider);
  final altarStatus = switch (dueAltar) {
    AsyncData(:final value) => value?.localStatus,
    _ => null,
  };
  final prayerAttention = selectTodayPrayerAttention(
    altarStatus: altarStatus,
    hasDuePerson: hasDuePerson,
  );
  return AsyncData(
    const TodayGuidanceEngine().select(
      TodayGuidanceSnapshot(
        duePractices: duePractices,
        completedPractices: state.completed,
        prayerAttention: prayerAttention,
        missedScheduledRoutineCount: fact.missedScheduledRoutineCount,
        joinedCircle: fact.joinedCircle,
        usedGoals: fact.usedGoals,
        usedPrayer: fact.usedPrayer,
        usedMemory: fact.usedMemory,
        usedPersons: fact.usedPersons,
        usedAltar: fact.usedAltar,
      ),
    ),
  );
});

TodayPrayerAttention? selectTodayPrayerAttention({
  required AltarRitualLocalStatus? altarStatus,
  required bool hasDuePerson,
}) {
  if (altarStatus == AltarRitualLocalStatus.due) {
    return TodayPrayerAttention.altar;
  }
  if (hasDuePerson) return TodayPrayerAttention.person;
  return null;
}
