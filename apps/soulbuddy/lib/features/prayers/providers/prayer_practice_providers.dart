import '../application/personal_prayer_narration_preparer.dart';
import '../domain/prayer_narration.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../application/prayer_occurrence_calculator.dart';
import '../application/prayer_audio_environment.dart';
import '../application/prayer_audio_environment_factory.dart';
import '../application/prayer_narration_player.dart';
import '../application/prayer_narration_playback_policy.dart';
import '../application/prayer_reminder_coordinator.dart';
import '../application/prayer_reminder_scheduler.dart';
import '../application/prayer_reminder_scheduler_factory.dart';
import '../data/powersync_prayer_practice_repository.dart';
import '../data/laravel_prayer_narration_repository.dart';
import '../data/prayer_narration_repository.dart';
import '../data/prayer_narration_prerequisite_uploader.dart';
import '../data/prayer_practice_repository.dart';
import '../domain/prayer_reminder.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_session.dart';

final prayerPracticeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final prayerNarrationRepositoryProvider = Provider<PrayerNarrationRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  final configured = Uri.tryParse(AppConfig.apiBaseUrl);
  return LaravelPrayerNarrationRepository(
    apiBaseUri: configured != null && configured.hasScheme
        ? configured
        : Uri.parse('http://127.0.0.1'),
    accessToken: ref.watch(appSessionTokenReaderProvider),
    client: client,
  );
});

final prayerAudioEnvironmentProvider = Provider<PrayerAudioEnvironment>(
  (ref) => createPrayerAudioEnvironment(),
);

final prayerNarrationPlaybackPolicyProvider =
    Provider<PrayerNarrationPlaybackPolicy>(
      (ref) => const PrayerNarrationPlaybackPolicy(),
    );

final prayerNarrationPlayerProvider = Provider<PrayerNarrationPlayer>((ref) {
  final player = AudioplayersPrayerNarrationPlayer();
  ref.onDispose(() => unawaited(player.close()));
  return player;
});

/// Shared explicit-consent preparation for reminders and Commitment sessions.
final preparePersonalPrayerNarrationProvider =
    Provider<
      Future<PrayerNarration> Function({
        required String personalPrayerId,
        required String revisionId,
        required bool consent,
      })
    >((ref) {
      return ({
        required personalPrayerId,
        required revisionId,
        required consent,
      }) async {
        final service = PersonalPrayerNarrationPreparer(
          repository: ref.read(prayerNarrationRepositoryProvider),
          uploadPrerequisite:
              ({required personalPrayerId, required revisionId}) async {
                ref.invalidate(installationSessionBootstrapProvider);
                await ref.read(installationSessionBootstrapProvider.future);
                final database = await ref.read(appDatabaseProvider.future);
                final identity = await ref.read(localIdentityProvider.future);
                final owned = await database.powersync.getOptional(
                  'SELECT id FROM personal_prayers WHERE id=? AND owner_id=? AND current_revision_id=? AND archived_at IS NULL',
                  [personalPrayerId, identity.ownerId, revisionId],
                );
                if (owned == null) {
                  throw const PrayerNarrationException('narration_unavailable');
                }
                final configured = Uri.tryParse(AppConfig.apiBaseUrl);
                if (configured == null || !configured.hasScheme) {
                  throw const PrayerNarrationException('narration_unavailable');
                }
                final client = http.Client();
                try {
                  await PrayerNarrationPrerequisiteUploader(
                    database: database.powersync,
                    apiBaseUri: configured,
                    installationId: identity.deviceId,
                    accessToken: ref.read(appSessionTokenReaderProvider),
                    client: client,
                  ).upload(
                    personalPrayerId: personalPrayerId,
                    revisionId: revisionId,
                  );
                } finally {
                  client.close();
                }
              },
        );
        return service.prepare(
          personalPrayerId: personalPrayerId,
          prayerRevisionId: revisionId,
          consent: consent,
        );
      };
    });

final prepareReminderNarrationProvider =
    Provider<
      Future<void> Function({
        required String reminderId,
        required String personalPrayerId,
        required String revisionId,
        required bool autoplay,
      })
    >((ref) {
      return ({
        required reminderId,
        required personalPrayerId,
        required revisionId,
        required autoplay,
      }) async {
        final narration =
            await ref.read(preparePersonalPrayerNarrationProvider)(
              personalPrayerId: personalPrayerId,
              revisionId: revisionId,
              consent: true,
            );
        final repository = await ref.read(
          prayerPracticeRepositoryProvider.future,
        );
        await repository.saveNarrationPreference(
          reminderId: reminderId,
          consentAccepted: true,
          autoplayWhenOpened: autoplay,
          revisionId: narration.revisionId,
          bytes: narration.bytes,
          contentType: narration.contentType,
        );
      };
    });

final playReminderNarrationProvider =
    Provider<
      Future<void> Function(DuePrayerOccurrence, {required bool explicit})
    >((ref) {
      final attempted = <String>{};
      return (occurrence, {required explicit}) async {
        final device = occurrence.device;
        final cached = device.narrationBytes;
        if (cached == null ||
            cached.isEmpty ||
            device.narrationRevisionId != occurrence.prayerRevisionId ||
            device.narrationContentType != 'audio/mpeg') {
          throw const PrayerNarrationException('narration_not_ready');
        }
        if (!explicit) {
          final environment = ref.read(prayerAudioEnvironmentProvider);
          final decision = ref
              .read(prayerNarrationPlaybackPolicyProvider)
              .decide(
                explicitInAppOpen: true,
                autoplayEnabled: device.autoplayWhenOpened,
                narrationReady: true,
                audioRoute: await environment.currentRoute(),
                interruptionsAllowed: await environment.interruptionsAllowed(),
                alreadyAttempted: !attempted.add(occurrence.occurrenceKey),
              );
          if (decision != PrayerNarrationPlaybackDecision.autoplay) return;
        }
        await ref
            .read(prayerNarrationPlayerProvider)
            .play(Uint8List.fromList(cached));
      };
    });

final prayerDeviceTimezoneProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

final prayerOccurrenceCalculatorProvider = Provider<PrayerOccurrenceCalculator>(
  (ref) => TimezonePrayerOccurrenceCalculator.initialize(),
);

final prayerReminderSchedulerProvider = Provider<PrayerReminderScheduler>(
  (ref) => createPrayerReminderScheduler(),
);

final prayerPracticeRepositoryProvider =
    FutureProvider<PrayerPracticeRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPrayerPracticeRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
      );
    });

final prayerReminderCoordinatorProvider =
    FutureProvider<PrayerReminderCoordinator>((ref) async {
      final coordinator = PrayerReminderCoordinator(
        repository: await ref.watch(prayerPracticeRepositoryProvider.future),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
        calculator: ref.watch(prayerOccurrenceCalculatorProvider),
        clock: ref.watch(prayerPracticeClockProvider),
        timezoneName: ref.watch(prayerDeviceTimezoneProvider),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      await coordinator.start();
      return coordinator;
    });

final prayerReminderDeviceEnablerProvider =
    Provider<Future<bool> Function(String)>((ref) {
      return (reminderId) async {
        final coordinator = await ref.read(
          prayerReminderCoordinatorProvider.future,
        );
        return coordinator.enableOnThisDevice(reminderId);
      };
    });

final prayerNotificationPermissionStatusProvider =
    FutureProvider<NotificationPermissionStatus>((ref) async {
      final scheduler = ref.watch(prayerReminderSchedulerProvider);
      await ref.watch(prayerReminderCoordinatorProvider.future);
      return scheduler.permissionStatus();
    });

final prayerReminderTestProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final scheduler = ref.read(prayerReminderSchedulerProvider);
    await ref.read(prayerReminderCoordinatorProvider.future);
    await scheduler.showTestReminder();
    ref.invalidate(prayerNotificationPermissionStatusProvider);
  };
});

final prayerReminderPauseProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (reminderId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final device = await repository.watchDevice(reminderId).first;
    if (device?.enabledOnDevice == true) {
      await ref
          .read(prayerReminderSchedulerProvider)
          .cancel(device!.platformNotificationId);
    }
    await repository.setDeviceEnabled(reminderId, enabled: false);
  };
});

final prayerReminderRemoveProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (reminderId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final device = await repository.watchDevice(reminderId).first;
    if (device?.enabledOnDevice == true) {
      await ref
          .read(prayerReminderSchedulerProvider)
          .cancel(device!.platformNotificationId);
    }
    await repository.archiveReminder(reminderId);
  };
});

final prayerReminderProvider = StreamProvider.autoDispose
    .family<PrayerReminder?, String>((ref, personalPrayerId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchReminder(personalPrayerId);
    });

final prayerReminderDeviceProvider = StreamProvider.autoDispose
    .family<PrayerReminderDevice?, String>((ref, reminderId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchDevice(reminderId);
    });

final prayerSessionCountProvider = StreamProvider.autoDispose
    .family<int, String>((ref, revisionId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchSessionCount(revisionId);
    });

final prayerSessionForDateProvider = StreamProvider.autoDispose
    .family<bool, (PrayerReference, DateTime, String?)>((ref, request) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchSessionForDate(
        request.$1,
        request.$2,
        revisionId: request.$3,
      );
    });

final duePrayerOccurrencesProvider = StreamProvider<List<DuePrayerOccurrence>>((
  ref,
) async* {
  final coordinator = await ref.watch(prayerReminderCoordinatorProvider.future);
  yield* coordinator.dueOccurrences;
});

final prayerReminderEventsProvider =
    StreamProvider<PrayerReminderCoordinatorEvent>((ref) async* {
      final coordinator = await ref.watch(
        prayerReminderCoordinatorProvider.future,
      );
      yield* coordinator.events;
    });

final prayerReminderActionProvider =
    Provider<
      Future<PrayerSession?> Function(DuePrayerOccurrence, PrayerReminderAction)
    >((ref) {
      return (occurrence, action) async {
        final coordinator = await ref.read(
          prayerReminderCoordinatorProvider.future,
        );
        return coordinator.performAction(occurrence, action);
      };
    });

final prayerSessionRetractorProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (sessionId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    await repository.retractSession(sessionId);
  };
});

void retryPrayerPracticeProviders(Ref ref) {
  if (ref.read(appDatabaseProvider).hasError) {
    ref.invalidate(appDatabaseProvider);
  }
  if (ref.read(localIdentityProvider).hasError) {
    ref.invalidate(localIdentityProvider);
  }
  ref.invalidate(prayerPracticeRepositoryProvider);
  ref.invalidate(prayerReminderCoordinatorProvider);
}
