import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/goal_onboarding_finalizer.dart';
import '../data/powersync_goal_onboarding_finalizer.dart';

final goalOnboardingFinalizerProvider = FutureProvider<GoalOnboardingFinalizer>(
  (ref) async {
    final database = await ref.watch(appDatabaseProvider.future);
    final identity = await ref.watch(localIdentityProvider.future);
    return PowerSyncGoalOnboardingFinalizer(
      database: database.powersync,
      ownerId: identity.ownerId,
      deviceId: identity.deviceId,
    );
  },
);
