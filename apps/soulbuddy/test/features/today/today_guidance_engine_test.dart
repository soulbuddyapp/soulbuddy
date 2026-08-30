import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/today/application/today_guidance_engine.dart';
import 'package:soulbuddy/features/today/domain/daily_practice_state.dart';
import 'package:soulbuddy/features/today/domain/today_guidance.dart';

void main() {
  const engine = TodayGuidanceEngine();

  test('prioritizes an outstanding routine', () {
    final card = engine.select(
      const TodayGuidanceSnapshot(
        duePractices: {DailyPractice.pray},
        usedGoals: true,
        usedPrayer: true,
        usedMemory: true,
        usedPersons: true,
      ),
    );
    expect(card.key, TodayGuidanceKey.duePrayer);
  });

  test('recommends a Circle only for verified repeated misses', () {
    final card = engine.select(
      const TodayGuidanceSnapshot(
        missedScheduledRoutineCount: 2,
        joinedCircle: false,
        usedGoals: true,
        usedPrayer: true,
        usedMemory: true,
        usedPersons: true,
      ),
    );
    expect(card.key, TodayGuidanceKey.circleAccountability);
    expect(
      card.body,
      'You missed two planned routines this week. A Circle can help you stay accountable.',
    );
  });

  test('never infers misses when history or Circle state is unknown', () {
    final card = engine.select(
      const TodayGuidanceSnapshot(
        missedScheduledRoutineCount: 3,
        joinedCircle: null,
      ),
    );
    expect(card.key, TodayGuidanceKey.beginPrayer);
  });

  test('uses several above three without turning misses into a score', () {
    final card = engine.select(
      const TodayGuidanceSnapshot(
        missedScheduledRoutineCount: 6,
        joinedCircle: false,
        usedGoals: true,
        usedPrayer: true,
        usedMemory: true,
        usedPersons: true,
      ),
    );
    expect(card.body, contains('missed several planned routines'));
    expect(card.body, isNot(contains('6')));
  });

  test('walks unexplored core features in stable order', () {
    expect(
      engine.select(const TodayGuidanceSnapshot()).key,
      TodayGuidanceKey.beginPrayer,
    );
    expect(
      engine.select(const TodayGuidanceSnapshot(usedPrayer: true)).key,
      TodayGuidanceKey.keepMemory,
    );
    expect(
      engine
          .select(
            const TodayGuidanceSnapshot(usedPrayer: true, usedMemory: true),
          )
          .key,
      TodayGuidanceKey.rememberPerson,
    );
  });

  test('encourages only after at least one due routine is complete', () {
    final card = engine.select(
      const TodayGuidanceSnapshot(
        duePractices: {DailyPractice.remember},
        completedPractices: {DailyPractice.remember},
        usedGoals: true,
        usedPrayer: true,
        usedMemory: true,
        usedPersons: true,
      ),
    );
    expect(card.key, TodayGuidanceKey.remainClose);
  });
}
