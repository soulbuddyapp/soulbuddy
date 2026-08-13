import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayers/domain/today_prayer.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../remember/domain/daily_memory.dart';
import '../../remember/providers/daily_memory_providers.dart';
import '../domain/daily_practice_state.dart';

/// Projects the factual practices attached to the currently displayed day.
final dailyPracticeStateProvider =
    FutureProvider.autoDispose<DailyPracticeState>((ref) async {
      final displayedDate = await ref.watch(todayPrayerDateProvider.future);
      final date = DateTime(
        displayedDate.year,
        displayedDate.month,
        displayedDate.day,
      );
      final observedToday = await ref.watch(todayPrayerProvider.future);
      final observedMemory = await ref.watch(dailyMemoryProvider.future);
      final today = observedToday?.localDate == date ? observedToday : null;
      final memory = observedMemory?.localDate == date ? observedMemory : null;
      var prayed = false;
      if (today != null) {
        prayed = await ref.watch(
          prayerSessionForDateProvider((today.prayer.reference, date)).future,
        );
      }
      return _projectDailyPractices(today, memory, prayed: prayed);
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
