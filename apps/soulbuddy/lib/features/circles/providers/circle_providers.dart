import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/circle_repository.dart';
import '../data/powersync_circle_repository.dart';
import '../domain/circle.dart';
import '../domain/circle_message.dart';

final circleRepositoryProvider = FutureProvider<CircleRepository>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncCircleRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final circlesProvider = StreamProvider.autoDispose<List<Circle>>((ref) async* {
  final repository = await ref.watch(circleRepositoryProvider.future);
  yield* repository.watchCircles();
});

final circleProvider = StreamProvider.autoDispose.family<Circle?, String>((
  ref,
  circleId,
) async* {
  final repository = await ref.watch(circleRepositoryProvider.future);
  yield* repository.watchCircle(circleId);
});

final circleMessagesProvider = StreamProvider.autoDispose
    .family<List<CircleMessage>, String>((ref, circleId) async* {
      final repository = await ref.watch(circleRepositoryProvider.future);
      yield* repository.watchMessages(circleId);
    });

void retryCircleProviders(WidgetRef ref, {String? circleId}) {
  if (ref.read(appDatabaseProvider).hasError) {
    ref.invalidate(appDatabaseProvider);
  }
  if (ref.read(localIdentityProvider).hasError) {
    ref.invalidate(localIdentityProvider);
  }
  ref.invalidate(circleRepositoryProvider);
  ref.invalidate(circlesProvider);
  if (circleId != null) {
    ref.invalidate(circleProvider(circleId));
    ref.invalidate(circleMessagesProvider(circleId));
  }
}
