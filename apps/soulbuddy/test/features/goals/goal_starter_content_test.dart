import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_starter_content.dart';
import 'package:soulbuddy/features/goals/domain/goal_onboarding_progress.dart';

void main() {
  test('behavior starters are reviewed explicit choices, not diagnoses', () {
    expect(
      goalStopBehaviorOptions.map((option) => option.key).toSet(),
      GoalStopBehaviorKey.values.toSet(),
    );
    for (final option in goalStopBehaviorOptions) {
      expect(option.label.trim(), isNotEmpty);
      expect(option.titleQuestion.trim(), isNotEmpty);
      expect(option.titleHint.trim(), isNotEmpty);
      expect(option.todayActionHint.trim(), isNotEmpty);
      expect(option.contentVersion, greaterThan(0));
      expect(option.reviewedOn, '2026-08-29');
      expect(option.label.toLowerCase(), isNot(contains('disorder')));
      expect(option.label.toLowerCase(), isNot(contains('addict')));
    }
  });

  test('clinical-support starters keep their reviewed source boundaries', () {
    final tobacco = stopBehaviorOption(GoalStopBehaviorKey.nicotineTobacco)!;
    final alcohol = stopBehaviorOption(GoalStopBehaviorKey.alcohol)!;
    final gambling = stopBehaviorOption(GoalStopBehaviorKey.gambling)!;

    expect(tobacco.sourceUrl, contains('who.int'));
    expect(tobacco.supportNote, contains('complement'));
    expect(alcohol.sourceUrl, contains('niaaa.nih.gov'));
    expect(alcohol.supportNote, contains('does not assess withdrawal risk'));
    expect(gambling.sourceUrl, contains('who.int'));
    expect(gambling.supportNote, contains('self-exclusion'));
  });
}
