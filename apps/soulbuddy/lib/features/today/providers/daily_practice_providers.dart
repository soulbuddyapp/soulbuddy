import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayers/domain/today_prayer.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../remember/domain/daily_memory.dart';
import '../../remember/providers/daily_memory_providers.dart';
import '../domain/daily_practice_state.dart';

/// Reactively projects the factual practices attached to the displayed day.
///
/// This is deliberately a synchronous combination of the underlying
/// AsyncValues. That preserves loading and failure states while ensuring every
/// later database emission immediately updates the slab inscriptions.
final dailyPracticeStateProvider =
    Provider.autoDispose<AsyncValue<DailyPracticeState>>((ref) {
      final dateValue = ref.watch(todayPrayerDateProvider);
      if (dateValue case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!dateValue.hasValue) return const AsyncLoading();

      final displayedDate = dateValue.requireValue;
      final date = DateTime(
        displayedDate.year,
        displayedDate.month,
        displayedDate.day,
      );

      final todayValue = ref.watch(todayPrayerProvider);
      if (todayValue case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!todayValue.hasValue) return const AsyncLoading();

      final memoryValue = ref.watch(dailyMemoryProvider);
      if (memoryValue case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!memoryValue.hasValue) return const AsyncLoading();

      final observedToday = todayValue.value;
      final observedMemory = memoryValue.value;
      final today = observedToday?.localDate == date ? observedToday : null;
      final memory = observedMemory?.localDate == date ? observedMemory : null;

      if (today == null) {
        return AsyncData(_projectDailyPractices(null, memory, prayed: false));
      }

      final sessionValue = ref.watch(
        prayerSessionForDateProvider((
          today.prayer.reference,
          date,
          today.prayerRevisionId,
        )),
      );
      if (sessionValue case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!sessionValue.hasValue) return const AsyncLoading();

      return AsyncData(
        _projectDailyPractices(
          today,
          memory,
          prayed: sessionValue.requireValue,
        ),
      );
    });

DailyPracticeState _projectDailyPractices(
  TodayPrayer? today,
  DailyMemory? memory, {
  required bool prayed,
}) {
  final available = <DailyPractice>{};
  final completed = <DailyPractice>{};

  if (today != null) {
    available.add(DailyPractice.pray);
    if (prayed) completed.add(DailyPractice.pray);

    final action = today.prayer.action?.trim();
    if (today.includeAction && action != null && action.isNotEmpty) {
      available.add(DailyPractice.act);
      if (today.actionCompleted) completed.add(DailyPractice.act);
    }
  }

  if (memory != null) {
    available.add(DailyPractice.remember);
    if (memory.status == DailyMemoryStatus.remembered) {
      completed.add(DailyPractice.remember);
    }
  }

  return DailyPracticeState(available: available, completed: completed);
}
