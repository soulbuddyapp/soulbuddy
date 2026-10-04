import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../application/daily_formation_reminder_coordinator.dart';
import '../data/daily_formation_repository.dart';
import '../data/formation_activity_client.dart';
import '../domain/formation_catalog.dart';
import '../domain/formation_profile.dart';
import '../domain/formation_progress.dart';

final dailyFormationCatalogProvider = FutureProvider<FormationCatalog>((
  ref,
) async {
  final raw = await rootBundle.loadString(
    'assets/content/daily_formation_v1.json',
  );
  return FormationCatalog.fromJson(jsonDecode(raw) as Map);
});

final dailyFormationRepositoryProvider = Provider<DailyFormationRepository>((
  ref,
) {
  final storage = ref.watch(secureStorageProvider);
  return DailyFormationRepository(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
});

final formationActivityClientProvider = Provider<FormationActivityClient>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return FormationActivityClient(
    apiBaseUri: Uri.tryParse(AppConfig.apiBaseUrl) ?? Uri(),
    accessToken: ref.watch(appSessionTokenReaderProvider),
    httpClient: client,
  );
});

final dailyFormationProgressProvider = FutureProvider<FormationProgress>((ref) {
  return ref.watch(dailyFormationRepositoryProvider).load();
});

final dailyFormationProfileProvider = FutureProvider<FormationProfile>((ref) {
  return ref.watch(dailyFormationRepositoryProvider).loadProfile();
});

final dailyFormationReminderCoordinatorProvider =
    FutureProvider<DailyFormationReminderCoordinator>((ref) async {
      final coordinator = DailyFormationReminderCoordinator(
        repository: ref.watch(dailyFormationRepositoryProvider),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
      );
      ref.onDispose(coordinator.dispose);
      await coordinator.start();
      return coordinator;
    });

final dailyFormationReminderEventsProvider =
    StreamProvider<DailyFormationReminderOpened>((ref) async* {
      final coordinator = await ref.watch(
        dailyFormationReminderCoordinatorProvider.future,
      );
      yield* coordinator.events;
    });

Future<void> selectDailyFormationVideo(
  WidgetRef ref, {
  required int day,
  required String videoId,
}) async {
  await ref
      .read(dailyFormationRepositoryProvider)
      .select(day: day, videoId: videoId);
  ref.invalidate(dailyFormationProgressProvider);
}

Future<void> completeDailyFormation(
  WidgetRef ref,
  FormationCompletion completion,
) async {
  await ref.read(dailyFormationRepositoryProvider).complete(completion);
  ref.invalidate(dailyFormationProgressProvider);
}

void recordDailyFormationOpened(WidgetRef ref, String videoId) {
  unawaited(ref.read(formationActivityClientProvider).recordOpened(videoId));
}

void recordDailyFormationCompleted(WidgetRef ref, String videoId) {
  unawaited(ref.read(formationActivityClientProvider).recordCompleted(videoId));
}

Future<void> saveDailyFormationProfile(
  WidgetRef ref,
  FormationProfile profile,
) async {
  await ref.read(dailyFormationRepositoryProvider).saveProfile(profile);
  ref.invalidate(dailyFormationProfileProvider);
}
