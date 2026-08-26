import 'first_prayer_choices.dart';

enum FirstPrayerStage {
  purpose,
  frequency,
  audience,
  language,
  detailChoice,
  detail,
  preparing,
  prayer,
  practice,
  remembranceType,
  remembranceMode,
  remembrance,
}

class FirstPrayerProgress {
  const FirstPrayerProgress({
    this.stage = FirstPrayerStage.purpose,
    this.answers = const FirstPrayerAnswers(),
    this.requestId,
    this.selectedPrayerType,
    this.selectedPrayerId,
    this.selectedPrayerRevisionId,
    this.detailByVoice,
    this.remembranceType,
    this.remembranceByVoice,
    this.remembranceText,
    this.remembranceAudioTemporaryKey,
    this.remembranceAudioMimeType,
    this.remembranceAudioDurationMs,
    this.remembranceAudioWaveform,
  });

  final FirstPrayerStage stage;
  final FirstPrayerAnswers answers;
  final String? requestId;
  final String? selectedPrayerType;
  final String? selectedPrayerId;
  final String? selectedPrayerRevisionId;
  final bool? detailByVoice;
  final String? remembranceType;
  final bool? remembranceByVoice;
  final String? remembranceText;
  final String? remembranceAudioTemporaryKey;
  final String? remembranceAudioMimeType;
  final int? remembranceAudioDurationMs;
  final List<double>? remembranceAudioWaveform;

  FirstPrayerProgress copyWith({
    FirstPrayerStage? stage,
    FirstPrayerAnswers? answers,
    String? requestId,
    String? selectedPrayerType,
    String? selectedPrayerId,
    String? selectedPrayerRevisionId,
    bool? detailByVoice,
    String? remembranceType,
    bool? remembranceByVoice,
    String? remembranceText,
    String? remembranceAudioTemporaryKey,
    String? remembranceAudioMimeType,
    int? remembranceAudioDurationMs,
    List<double>? remembranceAudioWaveform,
  }) {
    return FirstPrayerProgress(
      stage: stage ?? this.stage,
      answers: answers ?? this.answers,
      requestId: requestId ?? this.requestId,
      selectedPrayerType: selectedPrayerType ?? this.selectedPrayerType,
      selectedPrayerId: selectedPrayerId ?? this.selectedPrayerId,
      selectedPrayerRevisionId:
          selectedPrayerRevisionId ?? this.selectedPrayerRevisionId,
      detailByVoice: detailByVoice ?? this.detailByVoice,
      remembranceType: remembranceType ?? this.remembranceType,
      remembranceByVoice: remembranceByVoice ?? this.remembranceByVoice,
      remembranceText: remembranceText ?? this.remembranceText,
      remembranceAudioTemporaryKey:
          remembranceAudioTemporaryKey ?? this.remembranceAudioTemporaryKey,
      remembranceAudioMimeType:
          remembranceAudioMimeType ?? this.remembranceAudioMimeType,
      remembranceAudioDurationMs:
          remembranceAudioDurationMs ?? this.remembranceAudioDurationMs,
      remembranceAudioWaveform:
          remembranceAudioWaveform ?? this.remembranceAudioWaveform,
    );
  }
}
