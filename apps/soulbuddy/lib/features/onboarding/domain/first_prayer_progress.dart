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
  });

  final FirstPrayerStage stage;
  final FirstPrayerAnswers answers;
  final String? requestId;
  final String? selectedPrayerType;
  final String? selectedPrayerId;

  FirstPrayerProgress copyWith({
    FirstPrayerStage? stage,
    FirstPrayerAnswers? answers,
    String? requestId,
    String? selectedPrayerType,
    String? selectedPrayerId,
  }) {
    return FirstPrayerProgress(
      stage: stage ?? this.stage,
      answers: answers ?? this.answers,
      requestId: requestId ?? this.requestId,
      selectedPrayerType: selectedPrayerType ?? this.selectedPrayerType,
      selectedPrayerId: selectedPrayerId ?? this.selectedPrayerId,
    );
  }
}
