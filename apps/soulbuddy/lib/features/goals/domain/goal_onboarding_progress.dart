import 'goal.dart';

enum GoalOnboardingStage {
  starter,
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

class GoalOnboardingProgress {
  const GoalOnboardingProgress({
    this.stage = GoalOnboardingStage.starter,
    this.starterKey,
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
