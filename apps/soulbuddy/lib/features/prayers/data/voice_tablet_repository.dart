import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../domain/voice_tablet.dart';

class VoiceTabletAudioAttachment {
  VoiceTabletAudioAttachment({
    required this.id,
    required this.kind,
    required this.draft,
    required this.committed,
  }) {
    VoiceTabletAudio(
      id: id,
      kind: kind,
      storageKey: committed.storageKey,
      mimeType: draft.mimeType,
      duration: draft.duration,
      byteSize: committed.byteSize,
      waveform: draft.waveform,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final VoiceTabletAudioKind kind;
  final RecordedAudioDraft draft;
  final CommittedAudio committed;
}

class VoiceTabletCreateRequest {
  VoiceTabletCreateRequest({
    required this.source,
    required this.title,
    required this.fullRecording,
    this.refrain,
  }) {
    if (fullRecording.kind != VoiceTabletAudioKind.fullPrayer) {
      throw ArgumentError.value(fullRecording.kind, 'fullRecording');
    }
    if (refrain != null && refrain!.kind != VoiceTabletAudioKind.refrain) {
      throw ArgumentError.value(refrain!.kind, 'refrain');
    }
  }

  final VoiceTabletSource source;
  final String title;
  final VoiceTabletAudioAttachment fullRecording;
  final VoiceTabletAudioAttachment? refrain;
}

class VoiceTabletReplacement {
  const VoiceTabletReplacement({
    required this.tablet,
    required this.replacedStorageKey,
  });

  final VoiceTablet tablet;
  final String replacedStorageKey;
}

abstract interface class VoiceTabletRepository {
  Stream<VoiceTablet?> watch(String id);
  Stream<VoiceTablet?> watchForSource(VoiceTabletSource source);
  Future<VoiceTablet> create(VoiceTabletCreateRequest request);
  Future<VoiceTabletReplacement> replaceAudio(
    String tabletId,
    VoiceTabletAudioAttachment replacement,
  );
  Future<Set<String>> archive(String tabletId);
  Future<Set<String>> ownedStorageKeys();
}
