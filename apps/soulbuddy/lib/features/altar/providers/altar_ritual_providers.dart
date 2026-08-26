import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../data/altar_ritual_repository.dart';
import '../data/powersync_altar_ritual_repository.dart';
import '../domain/altar_ritual.dart';

final altarRitualRepositoryProvider = FutureProvider<AltarRitualRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncAltarRitualRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final altarRitualForTargetProvider = StreamProvider.autoDispose
    .family<AltarRitual?, AltarTarget>((ref, target) async* {
      final repository = await ref.watch(altarRitualRepositoryProvider.future);
      yield* repository.watchForTarget(target);
    });

final dueAltarRitualProvider = StreamProvider.autoDispose<DueAltarRitual?>((
  ref,
) async* {
  final displayedDate = await ref.watch(todayPrayerDateProvider.future);
  final repository = await ref.watch(altarRitualRepositoryProvider.future);
  yield* repository.watchNextForDate(
    DateTime(displayedDate.year, displayedDate.month, displayedDate.day),
  );
});
