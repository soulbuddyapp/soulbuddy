import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database_provider.dart';
import 'app_feedback_preferences.dart';
import 'app_feedback_service.dart';
import 'platform_feedback_driver.dart';
import 'platform_feedback_driver_factory.dart';

final platformFeedbackDriverProvider = Provider<PlatformFeedbackDriver>(
  (ref) => createPlatformFeedbackDriver(),
);

final appFeedbackServiceProvider = Provider<AppFeedbackService>(
  (ref) =>
      AppFeedbackService(driver: ref.watch(platformFeedbackDriverProvider)),
);

final appFeedbackPreferencesRepositoryProvider =
    FutureProvider<AppFeedbackPreferencesRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      return PowerSyncAppFeedbackPreferencesRepository(database.powersync);
    });

final appFeedbackPreferencesProvider = StreamProvider<AppFeedbackPreferences>((
  ref,
) async* {
  final repository = await ref.watch(
    appFeedbackPreferencesRepositoryProvider.future,
  );
  yield* repository.watch();
});
