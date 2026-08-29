import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/bundled_guard_catalogue.dart';
import '../data/guard_selection_repository.dart';
import '../data/powersync_guard_selection_repository.dart';
import '../domain/guard_definition.dart';

final guardCatalogueProvider = Provider<List<GuardDefinition>>(
  (ref) => BundledGuardCatalogue.definitions,
);

final guardSelectionRepositoryProvider =
    FutureProvider<GuardSelectionRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncGuardSelectionRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
      );
    });

final goalGuardSelectionsProvider = StreamProvider.autoDispose
    .family<List<GoalGuardSelection>, String>((ref, goalId) async* {
      final repository = await ref.watch(
        guardSelectionRepositoryProvider.future,
      );
      yield* repository.watchForGoal(goalId);
    });
