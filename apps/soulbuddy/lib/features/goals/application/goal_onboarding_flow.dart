import '../domain/goal.dart';
import '../domain/goal_onboarding_progress.dart';

abstract final class GoalOnboardingFlow {
  static GoalOnboardingProgress chooseStarter(GoalStarterKey starterKey) {
    return GoalOnboardingProgress(
      stage: starterKey == GoalStarterKey.stopControl
          ? GoalOnboardingStage.stopBehavior
          : GoalOnboardingStage.situation,
      starterKey: starterKey,
      title: _suggestedTitle(starterKey),
    );
  }

  static GoalOnboardingProgress normalizeForResume(
    GoalOnboardingProgress current,
  ) {
    if (current.starterKey != GoalStarterKey.stopControl) return current;
    if (current.stopBehaviorKey == null) {
      return _isPlanningStage(current.stage)
          ? _copy(current, stage: GoalOnboardingStage.stopBehavior)
          : current;
    }
    if (current.stopBehaviorKey != GoalStopBehaviorKey.alcohol ||
        !_isPlanningStage(current.stage)) {
      return current;
    }
    if (current.alcoholSafetyChoice == null) {
      return _copy(
        current,
        stage: GoalOnboardingStage.alcoholSafety,
        alcoholCareAcknowledged: null,
      );
    }
    if (current.alcoholSafetyChoice == GoalAlcoholSafetyChoice.medicalGuidance &&
        current.alcoholCareAcknowledged != true) {
      return _copy(
        current,
        stage: GoalOnboardingStage.alcoholCare,
        alcoholCareAcknowledged: false,
      );
    }
    return current;
  }

  static GoalOnboardingProgress chooseStopBehavior(
    GoalOnboardingProgress current,
    GoalStopBehaviorKey behavior,
  ) {
    if (current.starterKey != GoalStarterKey.stopControl ||
        current.stage != GoalOnboardingStage.stopBehavior) {
      throw StateError('Behavior choice is not available at this step.');
    }
    return _copy(
      current,
      stage: behavior == GoalStopBehaviorKey.alcohol
          ? GoalOnboardingStage.alcoholSafety
          : GoalOnboardingStage.situation,
      stopBehaviorKey: behavior,
      alcoholSafetyChoice: null,
      alcoholCareAcknowledged: null,
      title: current.title,
    );
  }

  static GoalOnboardingProgress chooseAlcoholSafety(
    GoalOnboardingProgress current,
    GoalAlcoholSafetyChoice choice,
  ) {
    if (current.stopBehaviorKey != GoalStopBehaviorKey.alcohol ||
        current.stage != GoalOnboardingStage.alcoholSafety) {
      throw StateError('Alcohol safety choice is not available at this step.');
    }
    return _copy(
      current,
      stage: choice == GoalAlcoholSafetyChoice.medicalGuidance
          ? GoalOnboardingStage.alcoholCare
          : GoalOnboardingStage.situation,
      alcoholSafetyChoice: choice,
      alcoholCareAcknowledged: choice ==
              GoalAlcoholSafetyChoice.noKnownWithdrawalRisk
          ? null
          : false,
    );
  }

  static GoalOnboardingProgress confirmAlcoholCare(
    GoalOnboardingProgress current,
  ) {
    if (current.stage != GoalOnboardingStage.alcoholCare ||
        !current.needsAlcoholMedicalGuidance) {
      throw StateError('Medical-guidance review is not available at this step.');
    }
    return _copy(
      current,
      stage: GoalOnboardingStage.situation,
      alcoholCareAcknowledged: true,
    );
  }

  static GoalOnboardingProgress setTitle(
    GoalOnboardingProgress current,
    String title,
  ) {
    _requirePlanningSafety(current);
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    return _copy(current, title: normalized);
  }

  static GoalOnboardingProgress setSituation(
    GoalOnboardingProgress current, {
    String? situation,
    required bool byVoice,
  }) {
    _requirePlanningSafety(current);
    return _copy(
      current,
      stage: GoalOnboardingStage.agency,
      currentSituation: _optionalText(situation),
      situationByVoice: byVoice,
    );
  }

  static GoalOnboardingProgress chooseAgency(
    GoalOnboardingProgress current,
    GoalAgencyChoice choice,
  ) {
    _requirePlanningSafety(current);
    return _copy(
      current,
      stage: GoalOnboardingStage.todayAction,
      agencyChoice: choice,
    );
  }

  static GoalOnboardingProgress setTodayAction(
    GoalOnboardingProgress current,
    String? action,
  ) {
    _requirePlanningSafety(current);
    return _copy(
      current,
      stage: current.starterKey == GoalStarterKey.stopControl
          ? GoalOnboardingStage.guard
          : GoalOnboardingStage.accountability,
      todayAction: _optionalText(action),
    );
  }

  static GoalOnboardingProgress setGuardNote(
    GoalOnboardingProgress current,
    String? guardNote,
  ) {
    _requirePlanningSafety(current);
    return _copy(
      current,
      stage: GoalOnboardingStage.accountability,
      guardNote: _optionalText(guardNote),
    );
  }

  static GoalOnboardingProgress chooseAccountability(
    GoalOnboardingProgress current,
    GoalAccountabilityChoice choice,
  ) {
    _requirePlanningSafety(current);
    return _copy(
      current,
      stage: GoalOnboardingStage.prayer,
      accountabilityChoice: choice,
    );
  }

  static GoalOnboardingProgress chooseLibraryPrayer(
    GoalOnboardingProgress current,
    String prayerId,
  ) {
    _requirePlanningSafety(current);
    final id = _requiredText(prayerId, 'prayerId');
    return _copy(
      current,
      prayerSource: GoalOnboardingPrayerSource.libraryPrayer,
      prayerResourceId: id,
      scriptureTranslation: null,
      scriptureBook: null,
      scriptureChapter: null,
      scriptureFirstVerse: null,
      scriptureLastVerse: null,
      ownPrayerText: null,
    );
  }

  static GoalOnboardingProgress choosePersonalPrayer(
    GoalOnboardingProgress current,
    String prayerId,
  ) {
    _requirePlanningSafety(current);
    final id = _requiredText(prayerId, 'prayerId');
    return _copy(
      current,
      prayerSource: GoalOnboardingPrayerSource.personalPrayer,
      prayerResourceId: id,
      scriptureTranslation: null,
      scriptureBook: null,
      scriptureChapter: null,
      scriptureFirstVerse: null,
      scriptureLastVerse: null,
      ownPrayerText: null,
    );
  }

  static GoalOnboardingProgress chooseScripture(
    GoalOnboardingProgress current, {
    required String translation,
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) {
    _requirePlanningSafety(current);
    final normalizedTranslation = _requiredText(translation, 'translation');
    final normalizedBook = _requiredText(book, 'book');
    if (chapter <= 0 || firstVerse <= 0 || lastVerse < firstVerse) {
      throw ArgumentError('Invalid Scripture range');
    }
    if (lastVerse - firstVerse + 1 > 20) {
      throw ArgumentError.value(
        lastVerse,
        'lastVerse',
        'choose no more than 20 consecutive verses',
      );
    }
    return _copy(
      current,
      prayerSource: GoalOnboardingPrayerSource.scripture,
      prayerResourceId: null,
      scriptureTranslation: normalizedTranslation,
      scriptureBook: normalizedBook,
      scriptureChapter: chapter,
      scriptureFirstVerse: firstVerse,
      scriptureLastVerse: lastVerse,
      ownPrayerText: null,
    );
  }

  static GoalOnboardingProgress useOwnWords(
    GoalOnboardingProgress current,
    String prayer,
  ) {
    _requirePlanningSafety(current);
    final words = _requiredText(prayer, 'prayer');
    return _copy(
      current,
      prayerSource: GoalOnboardingPrayerSource.ownWords,
      prayerResourceId: null,
      scriptureTranslation: null,
      scriptureBook: null,
      scriptureChapter: null,
      scriptureFirstVerse: null,
      scriptureLastVerse: null,
      ownPrayerText: words,
    );
  }

  static GoalOnboardingProgress beginSaving(GoalOnboardingProgress current) {
    if (current.starterKey == GoalStarterKey.stopControl &&
        current.stopBehaviorKey == null) {
      throw StateError('Choose what you are trying to stop before saving.');
    }
    _requirePlanningSafety(current);
    if (current.title?.trim().isNotEmpty != true) {
      throw StateError('A Goal title is required before saving.');
    }
    if (current.agencyChoice == null) {
      throw StateError('The Goal needs an agency choice before saving.');
    }
    if (!current.hasCompletePrayerSelection) {
      throw StateError(
        'A prayer or Scripture choice is required before saving.',
      );
    }
    return _copy(current, stage: GoalOnboardingStage.saving);
  }

  static GoalMode inferredMode(GoalOnboardingProgress current) {
    return switch (current.agencyChoice) {
      GoalAgencyChoice.stepsICanTake => GoalMode.actionable,
      GoalAgencyChoice.mostlyPrayAndWait => GoalMode.petition,
      GoalAgencyChoice.notSure => GoalMode.mixed,
      null => throw StateError('Goal agency has not been chosen.'),
    };
  }

  static GoalOnboardingProgress goBack(GoalOnboardingProgress current) {
    final stage = switch (current.stage) {
      GoalOnboardingStage.starter => GoalOnboardingStage.starter,
      GoalOnboardingStage.stopBehavior => GoalOnboardingStage.starter,
      GoalOnboardingStage.alcoholSafety => GoalOnboardingStage.stopBehavior,
      GoalOnboardingStage.alcoholCare => GoalOnboardingStage.alcoholSafety,
      GoalOnboardingStage.situation => _stageBeforeSituation(current),
      GoalOnboardingStage.agency => GoalOnboardingStage.situation,
      GoalOnboardingStage.todayAction => GoalOnboardingStage.agency,
      GoalOnboardingStage.guard => GoalOnboardingStage.todayAction,
      GoalOnboardingStage.accountability =>
        current.starterKey == GoalStarterKey.stopControl
            ? GoalOnboardingStage.guard
            : GoalOnboardingStage.todayAction,
      GoalOnboardingStage.prayer => GoalOnboardingStage.accountability,
      GoalOnboardingStage.saving => GoalOnboardingStage.prayer,
    };
    return _copy(current, stage: stage);
  }
}

bool _isPlanningStage(GoalOnboardingStage stage) => switch (stage) {
  GoalOnboardingStage.situation ||
  GoalOnboardingStage.agency ||
  GoalOnboardingStage.todayAction ||
  GoalOnboardingStage.guard ||
  GoalOnboardingStage.accountability ||
  GoalOnboardingStage.prayer ||
  GoalOnboardingStage.saving => true,
  GoalOnboardingStage.starter ||
  GoalOnboardingStage.stopBehavior ||
  GoalOnboardingStage.alcoholSafety ||
  GoalOnboardingStage.alcoholCare => false,
};

void _requirePlanningSafety(GoalOnboardingProgress current) {
  if (current.starterKey == GoalStarterKey.stopControl &&
      current.stopBehaviorKey == null) {
    throw StateError('Choose what you are trying to stop first.');
  }
  if (!current.alcoholSafetyCleared) {
    throw StateError(
      'Complete the alcohol safety guidance before making the plan.',
    );
  }
}

GoalOnboardingStage _stageBeforeSituation(GoalOnboardingProgress current) {
  if (current.starterKey != GoalStarterKey.stopControl ||
      current.stopBehaviorKey == null) {
    return GoalOnboardingStage.starter;
  }
  if (current.stopBehaviorKey != GoalStopBehaviorKey.alcohol) {
    return GoalOnboardingStage.stopBehavior;
  }
  return current.needsAlcoholMedicalGuidance
      ? GoalOnboardingStage.alcoholCare
      : GoalOnboardingStage.alcoholSafety;
}

String? _suggestedTitle(GoalStarterKey starterKey) => switch (starterKey) {
  GoalStarterKey.closerToGod => 'Grow closer to God',
  GoalStarterKey.direction => 'Find direction',
  GoalStarterKey.difficultTime => 'Get through a difficult time',
  GoalStarterKey.stopControl || GoalStarterKey.other => null,
};

String _requiredText(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

String? _optionalText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

const _unchanged = Object();

GoalOnboardingProgress _copy(
  GoalOnboardingProgress current, {
  GoalOnboardingStage? stage,
  Object? starterKey = _unchanged,
  Object? stopBehaviorKey = _unchanged,
  Object? alcoholSafetyChoice = _unchanged,
  Object? alcoholCareAcknowledged = _unchanged,
  Object? title = _unchanged,
  Object? currentSituation = _unchanged,
  Object? situationByVoice = _unchanged,
  Object? agencyChoice = _unchanged,
  Object? todayAction = _unchanged,
  Object? guardNote = _unchanged,
  Object? accountabilityChoice = _unchanged,
  Object? prayerSource = _unchanged,
  Object? prayerResourceId = _unchanged,
  Object? scriptureTranslation = _unchanged,
  Object? scriptureBook = _unchanged,
  Object? scriptureChapter = _unchanged,
  Object? scriptureFirstVerse = _unchanged,
  Object? scriptureLastVerse = _unchanged,
  Object? ownPrayerText = _unchanged,
  Object? createdGoalId = _unchanged,
}) {
  return GoalOnboardingProgress(
    stage: stage ?? current.stage,
    starterKey: identical(starterKey, _unchanged)
        ? current.starterKey
        : starterKey as GoalStarterKey?,
    stopBehaviorKey: identical(stopBehaviorKey, _unchanged)
        ? current.stopBehaviorKey
        : stopBehaviorKey as GoalStopBehaviorKey?,
    alcoholSafetyChoice: identical(alcoholSafetyChoice, _unchanged)
        ? current.alcoholSafetyChoice
        : alcoholSafetyChoice as GoalAlcoholSafetyChoice?,
    alcoholCareAcknowledged:
        identical(alcoholCareAcknowledged, _unchanged)
        ? current.alcoholCareAcknowledged
        : alcoholCareAcknowledged as bool?,
    title: identical(title, _unchanged) ? current.title : title as String?,
    currentSituation: identical(currentSituation, _unchanged)
        ? current.currentSituation
        : currentSituation as String?,
    situationByVoice: identical(situationByVoice, _unchanged)
        ? current.situationByVoice
        : situationByVoice as bool?,
    agencyChoice: identical(agencyChoice, _unchanged)
        ? current.agencyChoice
        : agencyChoice as GoalAgencyChoice?,
    todayAction: identical(todayAction, _unchanged)
        ? current.todayAction
        : todayAction as String?,
    guardNote: identical(guardNote, _unchanged)
        ? current.guardNote
        : guardNote as String?,
    accountabilityChoice: identical(accountabilityChoice, _unchanged)
        ? current.accountabilityChoice
        : accountabilityChoice as GoalAccountabilityChoice?,
    prayerSource: identical(prayerSource, _unchanged)
        ? current.prayerSource
        : prayerSource as GoalOnboardingPrayerSource?,
    prayerResourceId: identical(prayerResourceId, _unchanged)
        ? current.prayerResourceId
        : prayerResourceId as String?,
    scriptureTranslation: identical(scriptureTranslation, _unchanged)
        ? current.scriptureTranslation
        : scriptureTranslation as String?,
    scriptureBook: identical(scriptureBook, _unchanged)
        ? current.scriptureBook
        : scriptureBook as String?,
    scriptureChapter: identical(scriptureChapter, _unchanged)
        ? current.scriptureChapter
        : scriptureChapter as int?,
    scriptureFirstVerse: identical(scriptureFirstVerse, _unchanged)
        ? current.scriptureFirstVerse
        : scriptureFirstVerse as int?,
    scriptureLastVerse: identical(scriptureLastVerse, _unchanged)
        ? current.scriptureLastVerse
        : scriptureLastVerse as int?,
    ownPrayerText: identical(ownPrayerText, _unchanged)
        ? current.ownPrayerText
        : ownPrayerText as String?,
    createdGoalId: identical(createdGoalId, _unchanged)
        ? current.createdGoalId
        : createdGoalId as String?,
  );
}
