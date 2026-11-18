import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/application/audioplayers_memory_audio_player.dart';
import '../data/person_prayer_audio_repository.dart';

final personPrayerAudioRepositoryProvider =
    FutureProvider<PersonPrayerAudioRepository>((ref) async {
      final storage = ref.watch(secureStorageProvider);
      final store = await ref.watch(audioAssetStoreProvider.future);
      return PersonPrayerAudioRepository(
        read: () => storage.read(key: 'person-prayer-audio.v1'),
        write: (value) =>
            storage.write(key: 'person-prayer-audio.v1', value: value),
        store: store,
        newId: () => const Uuid().v7(),
      );
    });
final personPrayerAudioProvider = FutureProvider.autoDispose
    .family<PersonPrayerAudio?, String>(
      (ref, id) async => (await ref.watch(
        personPrayerAudioRepositoryProvider.future,
      )).load(id),
    );

final personPrayerAudioPlaybackProvider =
    FutureProvider<MemoryAudioPlaybackCoordinator>((ref) async {
      final store = await ref.watch(audioAssetStoreProvider.future);
      final coordinator = MemoryAudioPlaybackCoordinator(
        assetStore: store,
        driver: AudioplayersMemoryAudioPlayerDriver(respectSilence: true),
      );
      ref.onDispose(() => unawaited(coordinator.close()));
      return coordinator;
    });
