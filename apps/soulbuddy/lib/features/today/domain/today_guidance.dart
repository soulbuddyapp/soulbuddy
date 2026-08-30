import 'daily_practice_state.dart';

enum TodayGuidanceKey {
  duePrayer,
  dueAltar,
  duePerson,
  dueAction,
  dueRemembrance,
  circleAccountability,
  beginPrayer,
  keepMemory,
  rememberPerson,
  startGoal,
  remainClose,
  quietReturn,
}

enum TodayPrayerAttention { altar, person }

class TodayGuidanceSnapshot {
  const TodayGuidanceSnapshot({
    this.duePractices = const {},
    this.completedPractices = const {},
    this.prayerAttention,
    this.missedScheduledRoutineCount,
    this.joinedCircle,
    this.usedGoals = false,
    this.usedPrayer = false,
    this.usedMemory = false,
    this.usedPersons = false,
    this.usedAltar = false,
  });

  final Set<DailyPractice> duePractices;
  final Set<DailyPractice> completedPractices;
  final TodayPrayerAttention? prayerAttention;
  final int? missedScheduledRoutineCount;
  final bool? joinedCircle;
  final bool usedGoals;
  final bool usedPrayer;
  final bool usedMemory;
  final bool usedPersons;
  final bool usedAltar;

  Set<DailyPractice> get outstanding =>
      duePractices.difference(completedPractices);
}

class TodayGuidanceCardValue {
  const TodayGuidanceCardValue({
    required this.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.route,
  });

  final TodayGuidanceKey key;
  final String title;
  final String body;
  final String actionLabel;
  final String route;
}
