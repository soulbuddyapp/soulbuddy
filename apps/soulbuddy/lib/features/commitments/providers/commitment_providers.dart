import '../data/commitment_reminder_device_repository.dart';
import '../data/powersync_commitment_reminder_device_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../domain/commitment.dart';
import '../data/commitment_repository.dart';
import '../data/powersync_commitment_repository.dart';
import '../data/commitment_journey_progress_repository.dart';
import '../data/powersync_commitment_journey_progress_repository.dart';
import '../data/commitment_journey_practice_draft_repository.dart';
import '../data/powersync_commitment_journey_practice_draft_repository.dart';
import '../data/commitment_finalizer.dart';
import '../data/powersync_commitment_finalizer.dart';
import '../data/commitment_finalization_recovery_repository.dart';
import '../data/powersync_commitment_finalization_recovery_repository.dart';

final commitmentRepositoryProvider = FutureProvider<CommitmentRepository>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncCommitmentRepository(
    database: db.powersync,
    ownerId: identity.ownerId,
  );
});
final commitmentJourneyProgressRepositoryProvider =
    FutureProvider<CommitmentJourneyProgressRepository>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncCommitmentJourneyProgressRepository(
        database: db.powersync,
        ownerId: identity.ownerId,
      );
    });
final commitmentPracticeDraftRepositoryProvider =
    FutureProvider<CommitmentJourneyPracticeDraftRepository>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncCommitmentJourneyPracticeDraftRepository(
        database: db.powersync,
        ownerId: identity.ownerId,
      );
    });
final commitmentFinalizerProvider = FutureProvider<CommitmentFinalizer>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncCommitmentFinalizer(
    database: db.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});
final commitmentRecoveryRepositoryProvider =
    FutureProvider<CommitmentFinalizationRecoveryRepository>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncCommitmentFinalizationRecoveryRepository(
        database: db.powersync,
        ownerId: identity.ownerId,
      );
    });
final primaryCommitmentProvider = StreamProvider<Commitment?>((ref) async* {
  yield* (await ref.watch(commitmentRepositoryProvider.future)).watchPrimary();
});
final commitmentDetailsProvider = StreamProvider.autoDispose
    .family<CommitmentDetails?, String>((ref, id) async* {
      yield* (await ref.watch(
        commitmentRepositoryProvider.future,
      )).watchDetails(id);
    });
final commitmentSessionsProvider = StreamProvider.autoDispose
    .family<List<CommitmentMeditationSession>, String>((ref, id) async* {
      yield* (await ref.watch(
        commitmentRepositoryProvider.future,
      )).watchSessions(id);
    });
final commitmentJourneyProgressProvider =
    FutureProvider.autoDispose<CommitmentProgressLoadResult>((ref) async {
      return (await ref.watch(
        commitmentJourneyProgressRepositoryProvider.future,
      )).load();
    });

enum CommitmentEntry { begin, continueJourney, viewCommitment }

final commitmentEntryProvider = FutureProvider.autoDispose<CommitmentEntry>((
  ref,
) async {
  if (await ref.watch(primaryCommitmentProvider.future) != null) {
    return CommitmentEntry.viewCommitment;
  }
  return (await ref.watch(commitmentJourneyProgressProvider.future)).progress !=
          null
      ? CommitmentEntry.continueJourney
      : CommitmentEntry.begin;
});

final commitmentReminderDeviceRepositoryProvider =
    FutureProvider<CommitmentReminderDeviceRepository>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncCommitmentReminderDeviceRepository(
        database: db.powersync,
        ownerId: identity.ownerId,
      );
    });
