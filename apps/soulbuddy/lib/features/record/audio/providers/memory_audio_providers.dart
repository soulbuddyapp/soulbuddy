import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/feedback/app_feedback_providers.dart';
import '../../../../core/identity/local_identity_providers.dart';
import '../../../../core/playback/spiritual_session_providers.dart';
import '../application/audioplayers_memory_audio_player.dart';
import '../application/memory_audio_deletion.dart';
import '../application/memory_audio_player.dart';
import '../application/memory_soundscape_player.dart';
import '../application/audio_capture_controller.dart';
import '../application/microphone_capture_lock.dart';
import '../application/recording_activity.dart';
import '../application/record_plugin_driver.dart';
import '../data/audio_asset_store.dart';
import '../data/audio_asset_store_factory.dart';
import '../data/memory_audio_repository.dart';
import '../data/memory_soundscape_preferences.dart';
import '../data/powersync_memory_audio_repository.dart';
import '../domain/memory_audio.dart';
import '../domain/memory_soundscape.dart';

final audioAssetStoreProvider = FutureProvider<AudioAssetStore>((ref) async {
  return createAudioAssetStore();
});

final memoryAudioRepositoryProvider = FutureProvider<MemoryAudioRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncMemoryAudioRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
  );
});

final memoryAudioForEncounterProvider = StreamProvider.autoDispose
    .family<MemoryAudio?, String>((ref, encounterId) async* {
      final repository = await ref.watch(memoryAudioRepositoryProvider.future);
      yield* repository.watchForEncounter(encounterId);
    });

final memoryAudioPlaybackCoordinatorProvider =
    FutureProvider<MemoryAudioPlaybackCoordinator>((ref) async {
      final assetStore = await ref.watch(audioAssetStoreProvider.future);
      final coordinator = MemoryAudioPlaybackCoordinator(
        assetStore: assetStore,
        driver: AudioplayersMemoryAudioPlayerDriver(
          setFocus: ref.read(systemAudioFocusProvider),
        ),
      );
      ref.onDispose(() => unawaited(coordinator.close()));
      return coordinator;
    });

final memorySoundscapePreferencesProvider =
    Provider<MemorySoundscapePreferences>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return MemorySoundscapePreferences(
        read: (key) => storage.read(key: key),
        write: (key, value) => storage.write(key: key, value: value),
      );
    });

final memorySoundscapeSettingsProvider = FutureProvider.autoDispose
    .family<MemorySoundscapeSettings, String>((ref, assetId) {
      return ref.watch(memorySoundscapePreferencesProvider).load(assetId);
    });

final memorySoundscapePlaybackProvider =
    Provider<MemorySoundscapePlaybackCoordinator>((ref) {
      final coordinator = MemorySoundscapePlaybackCoordinator(
        player: AudioplayersMemorySoundscapePlayer(),
      );
      ref.onDispose(() => unawaited(coordinator.close()));
      return coordinator;
    });

final memoryAudioDeletionProvider = FutureProvider<MemoryAudioDeletion>((
  ref,
) async {
  return MemoryAudioDeletion(
    repository: await ref.watch(memoryAudioRepositoryProvider.future),
    assetStore: await ref.watch(audioAssetStoreProvider.future),
  );
});

final audioCaptureControllerProvider =
    FutureProvider.autoDispose<AudioCaptureController>(
      _createCaptureController,
    );

final microphoneCaptureLockProvider = Provider<MicrophoneCaptureLock>(
  (ref) => MicrophoneCaptureLock(),
);

final recordingActivityProvider = Provider<RecordingActivity>(
  (ref) => RecordingActivity(),
);

final inlineAudioCaptureControllerProvider = FutureProvider.autoDispose
    .family<AudioCaptureController, Object>(
      (ref, key) => _createCaptureController(ref),
    );

Future<AudioCaptureController> _createCaptureController(Ref ref) async {
  final assetStore = await ref.watch(audioAssetStoreProvider.future);
  final recorder = createRecordPluginAudioRecorder(assetStore);
  final session = ref.watch(spiritualSessionControllerProvider);
  final captureOwner = Object();
  final microphoneLock = ref.watch(microphoneCaptureLockProvider);
  ref.read(appFeedbackPreferencesProvider);
  final controller = AudioCaptureController(
    recorder: recorder,
    beforeCapture: () async {
      microphoneLock.acquire(captureOwner);
      await session.acquireCapture(captureOwner);
      await pauseAudioForCapture(ref);
    },
    afterCapture: () async {
      session.releaseCapture(captureOwner);
      microphoneLock.release(captureOwner);
    },
    onSilencePaused: () => notifySilencePause(ref),
    allocateTemporary: () => assetStore.allocateTemporary(
      takeId: const Uuid().v7(),
      extension: kIsWeb ? 'webm' : 'm4a',
    ),
  );
  ref.onDispose(() {
    unawaited(() async {
      try {
        await controller.close();
      } catch (_) {
        try {
          await controller.close();
        } catch (_) {
          // The native recorder may still be active. Its capture lease
          // stays held until shutdown is confirmed, even after disposal.
        }
      } finally {
        controller.dispose();
      }
    }());
  });
  return controller;
}

Future<void> notifySilencePause(Ref ref) async {
  final preferences = ref.read(appFeedbackPreferencesProvider).value;
  if (preferences == null) return;
  await ref
      .read(appFeedbackServiceProvider)
      .emit(AppFeedbackIntent.warning, preferences: preferences);
}

/// Called after microphone permission is granted, before any samples are taken.
/// A failed handoff prevents capture; it must never record audible app playback.
Future<void> pauseAudioForCapture(Ref ref) async {
  await ref.read(spiritualSessionControllerProvider).pauseForCapture();
  await ref.read(memorySoundscapePlaybackProvider).stopAll();
  final playback = ref.read(memoryAudioPlaybackCoordinatorProvider).value;
  if (playback != null) await playback.pause();
}
