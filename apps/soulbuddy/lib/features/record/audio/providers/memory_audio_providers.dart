import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../../../core/identity/local_identity_providers.dart';
import '../application/audioplayers_memory_audio_player.dart';
import '../application/memory_audio_deletion.dart';
import '../application/memory_audio_player.dart';
import '../application/memory_soundscape_player.dart';
import '../application/audio_capture_controller.dart';
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
        driver: AudioplayersMemoryAudioPlayerDriver(),
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
    FutureProvider.autoDispose<AudioCaptureController>((ref) async {
      final assetStore = await ref.watch(audioAssetStoreProvider.future);
      final recorder = createRecordPluginAudioRecorder(assetStore);
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () => assetStore.allocateTemporary(
          takeId: const Uuid().v7(),
          extension: kIsWeb ? 'webm' : 'm4a',
        ),
      );
      ref.onDispose(() => unawaited(controller.close()));
      return controller;
    });
