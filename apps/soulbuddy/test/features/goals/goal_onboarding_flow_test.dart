import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_onboarding_flow.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';

void main() {
  test('stop starter asks for explicit behavior without inventing a title', () {
    var stop = GoalOnboardingFlow.chooseStarter(GoalStarterKey.stopControl);
    final direction = GoalOnboardingFlow.chooseStarter(
      GoalStarterKey.direction,
    );

    expect(stop.stage, GoalOnboardingStage.stopBehavior);
    expect(stop.title, isNull);
    stop = GoalOnboardingFlow.chooseStopBehavior(
      stop,
      GoalStopBehaviorKey.pornography,
    );
    expect(stop.stage, GoalOnboardingStage.situation);
    expect(stop.stopBehaviorKey, GoalStopBehaviorKey.pornography);
    expect(stop.title, isNull);
    expect(direction.title, 'Find direction');
  });

  test('only the stop-control starter inserts the guard decision', () {
    var stop = GoalOnboardingFlow.chooseStarter(GoalStarterKey.stopControl);
    stop = GoalOnboardingFlow.chooseStopBehavior(
      stop,
      GoalStopBehaviorKey.pornography,
    );
    stop = GoalOnboardingFlow.setTitle(stop, 'Stop watching pornography');
    stop = GoalOnboardingFlow.setSituation(
      stop,
      situation: 'Late-night phone use makes this easier.',
      byVoice: false,
    );
    stop = GoalOnboardingFlow.chooseAgency(
      stop,
      GoalAgencyChoice.stepsICanTake,
    );
    stop = GoalOnboardingFlow.setTodayAction(stop, 'Charge phone outside');

    var direction = GoalOnboardingFlow.chooseStarter(GoalStarterKey.direction);
    direction = GoalOnboardingFlow.setSituation(
      direction,
      situation: 'I am choosing between two roles.',
      byVoice: true,
    );
    direction = GoalOnboardingFlow.chooseAgency(
      direction,
      GoalAgencyChoice.notSure,
    );
    direction = GoalOnboardingFlow.setTodayAction(direction, 'Call Emmanuel');

    expect(stop.stage, GoalOnboardingStage.guard);
    expect(direction.stage, GoalOnboardingStage.accountability);
    expect(
      GoalOnboardingFlow.goBack(stop).stage,
      GoalOnboardingStage.todayAction,
    );
    expect(
      GoalOnboardingFlow.goBack(direction).stage,
      GoalOnboardingStage.todayAction,
    );
  });

  test(
    'alcohol medical-guidance route cannot be bypassed by planning calls',
    () {
      var progress = GoalOnboardingFlow.chooseStarter(
        GoalStarterKey.stopControl,
      );
      progress = GoalOnboardingFlow.chooseStopBehavior(
        progress,
        GoalStopBehaviorKey.alcohol,
      );
      expect(progress.stage, GoalOnboardingStage.alcoholSafety);
      expect(
        () => GoalOnboardingFlow.setTitle(progress, 'Stop drinking'),
        throwsStateError,
      );

      progress = GoalOnboardingFlow.chooseAlcoholSafety(
        progress,
        GoalAlcoholSafetyChoice.medicalGuidance,
      );
      expect(progress.stage, GoalOnboardingStage.alcoholCare);
      expect(progress.needsAlcoholMedicalGuidance, isTrue);
      expect(progress.alcoholSafetyCleared, isFalse);
      expect(
        () => GoalOnboardingFlow.setTitle(progress, 'Stop drinking'),
        throwsStateError,
      );
      expect(() => GoalOnboardingFlow.beginSaving(progress), throwsStateError);

      progress = GoalOnboardingFlow.confirmAlcoholCare(progress);
      expect(progress.stage, GoalOnboardingStage.situation);
      expect(progress.alcoholCareAcknowledged, isTrue);
      expect(progress.alcoholSafetyCleared, isTrue);
      expect(
        GoalOnboardingFlow.goBack(progress).stage,
        GoalOnboardingStage.alcoholCare,
      );
    },
  );

  test(
    'alcohol no-known-risk choice still requires the safety step itself',
    () {
      var progress = GoalOnboardingFlow.chooseStarter(
        GoalStarterKey.stopControl,
      );
      progress = GoalOnboardingFlow.chooseStopBehavior(
        progress,
        GoalStopBehaviorKey.alcohol,
      );
      expect(progress.alcoholSafetyCleared, isFalse);

      progress = GoalOnboardingFlow.chooseAlcoholSafety(
        progress,
        GoalAlcoholSafetyChoice.noKnownWithdrawalRisk,
      );

      expect(progress.stage, GoalOnboardingStage.situation);
      expect(progress.alcoholSafetyCleared, isTrue);
      expect(progress.alcoholCareAcknowledged, isNull);
    },
  );

  test('changing prayer source clears incompatible stale selection state', () {
    var progress = GoalOnboardingFlow.chooseStarter(GoalStarterKey.direction);
    progress = GoalOnboardingFlow.chooseLibraryPrayer(progress, 'prayer-1');
    expect(progress.prayerResourceId, 'prayer-1');

    progress = GoalOnboardingFlow.chooseScripture(
      progress,
      translation: 'RSVCE',
      book: 'James',
      chapter: 1,
      firstVerse: 5,
      lastVerse: 5,
    );
    expect(progress.prayerResourceId, isNull);
    expect(progress.scriptureBook, 'James');
    expect(progress.hasCompletePrayerSelection, isTrue);

    progress = GoalOnboardingFlow.useOwnWords(
      progress,
      'Father, give me wisdom for the next faithful step.',
    );
    expect(progress.scriptureBook, isNull);
    expect(progress.scriptureChapter, isNull);
    expect(progress.ownPrayerText, contains('wisdom'));
    expect(progress.hasCompletePrayerSelection, isTrue);
  });

  test('saving requires behavior, title, agency and prayer resource', () {
    var progress = GoalOnboardingFlow.chooseStarter(GoalStarterKey.stopControl);
    expect(() => GoalOnboardingFlow.beginSaving(progress), throwsStateError);

    progress = GoalOnboardingFlow.chooseStopBehavior(
      progress,
      GoalStopBehaviorKey.pornography,
    );
    progress = GoalOnboardingFlow.setTitle(
      progress,
      'Stop watching pornography',
    );
    progress = GoalOnboardingFlow.setSituation(
      progress,
      situation: null,
      byVoice: false,
    );
    progress = GoalOnboardingFlow.chooseAgency(
      progress,
      GoalAgencyChoice.stepsICanTake,
    );
    progress = GoalOnboardingFlow.setTodayAction(progress, null);
    progress = GoalOnboardingFlow.setGuardNote(progress, null);
    progress = GoalOnboardingFlow.chooseAccountability(
      progress,
      GoalAccountabilityChoice.notNow,
    );
    progress = GoalOnboardingFlow.useOwnWords(
      progress,
      'Jesus, keep me close to you and help me act faithfully.',
    );

    expect(GoalOnboardingFlow.inferredMode(progress), GoalMode.actionable);
    expect(
      GoalOnboardingFlow.beginSaving(progress).stage,
      GoalOnboardingStage.saving,
    );
  });

  test('scripture choice rejects oversized ranges', () {
    final progress = GoalOnboardingFlow.chooseStarter(
      GoalStarterKey.closerToGod,
    );

    expect(
      () => GoalOnboardingFlow.chooseScripture(
        progress,
        translation: 'RSVCE',
        book: 'John',
        chapter: 1,
        firstVerse: 1,
        lastVerse: 25,
      ),
      throwsArgumentError,
    );
  });
}
