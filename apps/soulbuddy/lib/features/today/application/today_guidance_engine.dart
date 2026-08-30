import '../domain/daily_practice_state.dart';
import '../domain/today_guidance.dart';

class TodayGuidanceEngine {
  const TodayGuidanceEngine();

  TodayGuidanceCardValue select(TodayGuidanceSnapshot snapshot) {
    if (snapshot.prayerAttention case final attention?) {
      return _prayerAttention(attention);
    }
    for (final practice in DailyPractice.values) {
      if (snapshot.outstanding.contains(practice)) return _due(practice);
    }

    final missed = snapshot.missedScheduledRoutineCount;
    if (missed != null && missed >= 2 && snapshot.joinedCircle == false) {
      final count = missed > 3 ? 'several' : _countWord(missed);
      return TodayGuidanceCardValue(
        key: TodayGuidanceKey.circleAccountability,
        title: 'A Circle could help',
        body:
            'You missed $count planned routines this week. A Circle can help you stay accountable.',
        actionLabel: 'Explore Circles',
        route: '/circles',
      );
    }

    if (!snapshot.usedPrayer) {
      return const TodayGuidanceCardValue(
        key: TodayGuidanceKey.beginPrayer,
        title: 'Begin with prayer',
        body: 'Choose a prayer to keep close today.',
        actionLabel: 'Choose a prayer',
        route: '/prayers',
      );
    }
    if (!snapshot.usedMemory) {
      return const TodayGuidanceCardValue(
        key: TodayGuidanceKey.keepMemory,
        title: 'Keep what happened',
        body: 'Record what you do not want to forget.',
        actionLabel: 'Remember something',
        route: '/remember/capture',
      );
    }
    if (!snapshot.usedPersons) {
      return const TodayGuidanceCardValue(
        key: TodayGuidanceKey.rememberPerson,
        title: 'Remember someone in prayer',
        body: 'Add a person you want to pray for faithfully.',
        actionLabel: 'Add a person',
        route: '/persons/new',
      );
    }
    if (!snapshot.usedGoals) {
      return const TodayGuidanceCardValue(
        key: TodayGuidanceKey.startGoal,
        title: 'Name what you are seeking',
        body: 'Start a Goal and keep its next action on Today.',
        actionLabel: 'Start a Goal',
        route: '/welcome/goal',
      );
    }

    if (snapshot.duePractices.isNotEmpty && snapshot.outstanding.isEmpty) {
      return const TodayGuidanceCardValue(
        key: TodayGuidanceKey.remainClose,
        title: 'Remain close',
        body:
            'You kept today’s routines. Give glory to God and remain close to Him.',
        actionLabel: 'Open Remember',
        route: '/remember',
      );
    }

    return const TodayGuidanceCardValue(
      key: TodayGuidanceKey.quietReturn,
      title: 'Return quietly',
      body: 'Pray, remember, or take the next faithful action.',
      actionLabel: 'Open Goals',
      route: '/goals',
    );
  }

  TodayGuidanceCardValue _prayerAttention(TodayPrayerAttention attention) =>
      switch (attention) {
        TodayPrayerAttention.altar => const TodayGuidanceCardValue(
          key: TodayGuidanceKey.dueAltar,
          title: 'Return to your Altar',
          body: 'A prayer ritual is ready now.',
          actionLabel: 'Open Altar',
          route: '/today?focus=altar',
        ),
        TodayPrayerAttention.person => const TodayGuidanceCardValue(
          key: TodayGuidanceKey.duePerson,
          title: 'Remember someone in prayer',
          body: 'Someone you planned to pray for is due today.',
          actionLabel: 'Open Persons',
          route: '/persons',
        ),
      };

  TodayGuidanceCardValue _due(DailyPractice practice) => switch (practice) {
    DailyPractice.pray => const TodayGuidanceCardValue(
      key: TodayGuidanceKey.duePrayer,
      title: 'Return to prayer',
      body: 'A prayer is ready for today.',
      actionLabel: 'Open prayers',
      route: '/prayers',
    ),
    DailyPractice.act => const TodayGuidanceCardValue(
      key: TodayGuidanceKey.dueAction,
      title: 'Keep the next action',
      body: 'A practical step is ready for today.',
      actionLabel: 'Open Goals',
      route: '/goals',
    ),
    DailyPractice.remember => const TodayGuidanceCardValue(
      key: TodayGuidanceKey.dueRemembrance,
      title: 'Remember what God has done',
      body: 'A memory is ready for quiet recall.',
      actionLabel: 'Open Remember',
      route: '/remember',
    ),
  };
}

String _countWord(int count) => switch (count) {
  2 => 'two',
  3 => 'three',
  _ => count.toString(),
};
