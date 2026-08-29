import 'goal.dart';

enum GoalOnboardingStage {
  starter,
  stopBehavior,
  alcoholSafety,
  alcoholCare,
  situation,
  agency,
  todayAction,
  guard,
  accountability,
  prayer,
  saving,
}

enum GoalAgencyChoice {
  stepsICanTake('steps_i_can_take'),
  mostlyPrayAndWait('mostly_pray_and_wait'),
  notSure('not_sure');

  const GoalAgencyChoice(this.wireValue);

  final String wireValue;

  static GoalAgencyChoice? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum GoalAccountabilityChoice {
  trustedPerson('trusted_person'),
  circle('circle'),
  notNow('not_now');

  const GoalAccountabilityChoice(this.wireValue);

  final String wireValue;

  static GoalAccountabilityChoice? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum GoalOnboardingPrayerSource {
  libraryPrayer('library_prayer'),
  personalPrayer('personal_prayer'),
  scripture('scripture'),
  ownWords('own_words');

  const GoalOnboardingPrayerSource(this.wireValue);

  final String wireValue;

  static GoalOnboardingPrayerSource? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum GoalStopBehaviorKey {
  pornography('pornography'),
  gambling('gambling'),
  nicotineTobacco('nicotine_tobacco'),
  alcohol('alcohol'),
  digitalDistraction('digital_distraction'),
  other('other');

  const GoalStopBehaviorKey(this.wireValue);

  final String wireValue;

  static GoalStopBehaviorKey? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum GoalAlcoholSafetyChoice {
  medicalGuidance('medical_guidance'),
  noKnownWithdrawalRisk('no_known_withdrawal_risk');

  const GoalAlcoholSafetyChoice(this.wireValue);

  final String wireValue;

  static GoalAlcoholSafetyChoice? tryFromWire(String? value) {
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

class GoalOnboardingProgress {
  const GoalOnboardingProgress({
    this.stage = GoalOnboardingStage.starter,
    this.starterKey,
    this.stopBehaviorKey,
    this.alcoholSafetyChoice,
    this.alcoholCareAcknowledged,
    this.title,
    this.currentSituation,
    this.situationByVoice,
    this.agencyChoice,
    this.todayAction,
    this.guardNote,
    this.accountabilityChoice,
    this.prayerSource,
    this.prayerResourceId,
    this.scriptureTranslation,
    this.scriptureBook,
    this.scriptureChapter,
    this.scriptureFirstVerse,
    this.scriptureLastVerse,
    this.ownPrayerText,
    this.createdGoalId,
  });

  final GoalOnboardingStage stage;
  final GoalStarterKey? starterKey;
  final GoalStopBehaviorKey? stopBehaviorKey;
  final GoalAlcoholSafetyChoice? alcoholSafetyChoice;
  final bool? alcoholCareAcknowledged;
  final String? title;
  final String? currentSituation;
  final bool? situationByVoice;
  final GoalAgencyChoice? agencyChoice;
  final String? todayAction;
  final String? guardNote;
  final GoalAccountabilityChoice? accountabilityChoice;
  final GoalOnboardingPrayerSource? prayerSource;
  final String? prayerResourceId;
  final String? scriptureTranslation;
  final String? scriptureBook;
  final int? scriptureChapter;
  final int? scriptureFirstVerse;
  final int? scriptureLastVerse;
  final String? ownPrayerText;
  final String? createdGoalId;

  bool get needsAlcoholMedicalGuidance =>
      stopBehaviorKey == GoalStopBehaviorKey.alcohol &&
      alcoholSafetyChoice == GoalAlcoholSafetyChoice.medicalGuidance;

  bool get alcoholSafetyCleared {
    if (stopBehaviorKey != GoalStopBehaviorKey.alcohol) return true;
    return switch (alcoholSafetyChoice) {
      GoalAlcoholSafetyChoice.noKnownWithdrawalRisk => true,
      GoalAlcoholSafetyChoice.medicalGuidance =>
        alcoholCareAcknowledged == true,
      null => false,
    };
  }

  bool get hasCompletePrayerSelection => switch (prayerSource) {
    GoalOnboardingPrayerSource.libraryPrayer ||
    GoalOnboardingPrayerSource.personalPrayer =>
      prayerResourceId?.trim().isNotEmpty == true,
    GoalOnboardingPrayerSource.scripture =>
      scriptureTranslation?.trim().isNotEmpty == true &&
          scriptureBook?.trim().isNotEmpty == true &&
          scriptureChapter != null &&
          scriptureChapter! > 0 &&
          scriptureFirstVerse != null &&
          scriptureFirstVerse! > 0 &&
          scriptureLastVerse != null &&
          scriptureLastVerse! >= scriptureFirstVerse!,
    GoalOnboardingPrayerSource.ownWords =>
      ownPrayerText?.trim().isNotEmpty == true,
    null => false,
  };
}
