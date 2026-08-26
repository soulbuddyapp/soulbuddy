import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/audio/application/audio_capture_controller.dart';
import '../../record/audio/application/record_plugin_driver.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../data/powersync_voice_tablet_repository.dart';
import '../data/voice_tablet_repository.dart';
import '../domain/voice_tablet.dart';

final voiceTabletRepositoryProvider = FutureProvider<VoiceTabletRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncVoiceTabletRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final voiceTabletForSourceProvider = StreamProvider.autoDispose
    .family<VoiceTablet?, VoiceTabletSource>((ref, source) async* {
      final repository = await ref.watch(voiceTabletRepositoryProvider.future);
      yield* repository.watchForSource(source);
    });

final voiceTabletAudioCaptureControllerProvider = FutureProvider.autoDispose
    .family<AudioCaptureController, VoiceTabletAudioKind>((ref, kind) async {
      final assetStore = await ref.watch(audioAssetStoreProvider.future);
      final controller = AudioCaptureController(
        recorder: createRecordPluginAudioRecorder(assetStore),
        allocateTemporary: () => assetStore.allocateTemporary(
          takeId: const Uuid().v7(),
          extension: kIsWeb ? 'webm' : 'm4a',
        ),
        maximumDuration: kind == VoiceTabletAudioKind.refrain
            ? maximumPrayerRefrainDuration
            : maximumMemoryAudioDuration,
      );
      ref.onDispose(() => unawaited(controller.close()));
      return controller;
    });
