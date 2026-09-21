import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../application/goal_meditation_reminder_coordinator.dart';
import '../data/goal_meditation_repository.dart';
import '../domain/goal_meditation_plan.dart';

final goalMeditationRepositoryProvider = Provider<GoalMeditationRepository>((
  ref,
) {
  final storage = ref.watch(secureStorageProvider);
  return GoalMeditationRepository(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
});

final goalMeditationPlanProvider =
    FutureProvider.family<GoalMeditationPlan?, String>((ref, id) {
      return ref.watch(goalMeditationRepositoryProvider).loadPlan(id);
    });

final goalMeditationEntriesProvider =
    FutureProvider.family<List<GoalMeditationEntry>, String>((ref, id) {
      return ref.watch(goalMeditationRepositoryProvider).loadEntries(id);
    });

final goalMeditationReminderCoordinatorProvider =
    FutureProvider<GoalMeditationReminderCoordinator>((ref) async {
      final coordinator = GoalMeditationReminderCoordinator(
        repository: ref.watch(goalMeditationRepositoryProvider),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
      );
      ref.onDispose(coordinator.dispose);
      await coordinator.start();
      return coordinator;
    });

final goalMeditationReminderEventsProvider =
    StreamProvider<GoalMeditationOpened>((ref) async* {
      final coordinator = await ref.watch(
        goalMeditationReminderCoordinatorProvider.future,
      );
      yield* coordinator.events;
    });
