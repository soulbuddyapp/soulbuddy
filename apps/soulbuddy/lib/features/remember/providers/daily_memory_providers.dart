import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../data/daily_memory_repository.dart';
import '../data/powersync_daily_memory_repository.dart';
import '../domain/daily_memory.dart';

final dailyMemoryRepositoryProvider = FutureProvider<DailyMemoryRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncDailyMemoryRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    now: ref.watch(prayerClockProvider),
  );
});

final dailyMemoryProvider = StreamProvider.autoDispose<DailyMemory?>((
  ref,
) async* {
  switch (ref.watch(todayPrayerDateProvider)) {
    case AsyncData(:final value):
      final date = DateTime(value.year, value.month, value.day);
      final repository = await ref.watch(dailyMemoryRepositoryProvider.future);
      await repository.ensureForDate(date);
      yield* repository.watchForDate(date);
    case AsyncError(:final error, :final stackTrace):
      Error.throwWithStackTrace(error, stackTrace);
    case AsyncLoading():
      return;
  }
});

void retryDailyMemoryProvider(WidgetRef ref) {
  final database = ref.read(appDatabaseProvider);
  final identity = ref.read(localIdentityProvider);
  if (database.hasError) ref.invalidate(appDatabaseProvider);
  if (identity.hasError) ref.invalidate(localIdentityProvider);
  ref.invalidate(dailyMemoryRepositoryProvider);
  ref.invalidate(dailyMemoryProvider);
}
