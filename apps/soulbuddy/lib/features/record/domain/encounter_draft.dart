import 'encounter.dart';
import '../audio/domain/memory_audio.dart';

class EncounterDraft {
  const EncounterDraft({
    required this.title,
    required this.body,
    required this.occurredOn,
    required this.isAltar,
    this.memoryType = MemoryType.encounter,
    this.sensitive = false,
    this.recallEnabled = true,
    this.recallPaused = false,
    this.recallIntervalDays = 7,
    this.audio,
    this.personIds = const [],
    this.voiceNoteContext,
    this.reflectionParentId,
  });

  final String title;
  final String body;
  final String occurredOn;
  final bool isAltar;
  final MemoryType memoryType;
  final bool sensitive;
  final bool recallEnabled;
  final bool recallPaused;
  final int recallIntervalDays;
  final MemoryAudioDraft? audio;
  final List<String> personIds;
  final ({String type, String id, String field})? voiceNoteContext;
  final String? reflectionParentId;
}
