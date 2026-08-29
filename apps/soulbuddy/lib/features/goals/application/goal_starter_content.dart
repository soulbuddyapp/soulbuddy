import '../../prayers/domain/library_prayer.dart';
import '../domain/goal.dart';
import '../domain/goal_onboarding_progress.dart';

class GoalStarterOption {
  const GoalStarterOption({required this.key, required this.label});

  final GoalStarterKey key;
  final String label;
}

class GoalStopBehaviorOption {
  const GoalStopBehaviorOption({
    required this.key,
    required this.label,
    required this.titleQuestion,
    required this.titleHint,
    required this.todayActionHint,
    required this.guardContextTag,
    required this.contentVersion,
    required this.reviewedOn,
    this.supportNote,
    this.sourceUrl,
  });

  final GoalStopBehaviorKey key;
  final String label;
  final String titleQuestion;
  final String titleHint;
  final String todayActionHint;
  final String? guardContextTag;
  final int contentVersion;
  final String reviewedOn;
  final String? supportNote;
  final String? sourceUrl;
}

const goalStarterOptions = <GoalStarterOption>[
  GoalStarterOption(
    key: GoalStarterKey.closerToGod,
    label: 'Grow closer to God',
  ),
  GoalStarterOption(
    key: GoalStarterKey.stopControl,
    label: 'Stop something fighting to control me',
  ),
  GoalStarterOption(key: GoalStarterKey.direction, label: 'Find direction'),
  GoalStarterOption(
    key: GoalStarterKey.difficultTime,
    label: 'Get through a difficult time',
  ),
  GoalStarterOption(key: GoalStarterKey.other, label: 'Something else'),
];

const goalStopBehaviorOptions = <GoalStopBehaviorOption>[
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.pornography,
    label: 'Pornography',
    titleQuestion: 'What do you want to stop?',
    titleHint: 'For example: Stop watching pornography',
    todayActionHint: 'One concrete step that removes easy access today',
    guardContextTag: 'sexual_compulsion',
    contentVersion: 1,
    reviewedOn: '2026-08-29',
  ),
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.gambling,
    label: 'Gambling',
    titleQuestion: 'What do you want to stop?',
    titleHint: 'For example: Stop gambling',
    todayActionHint:
        'Use self-exclusion or a binding money/time limit where available',
    guardContextTag: 'gambling',
    contentVersion: 1,
    reviewedOn: '2026-08-29',
    supportNote:
        'Where available, prefer effective self-exclusion and binding money/time limits over optional reminders alone.',
    sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/gambling',
  ),
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.nicotineTobacco,
    label: 'Nicotine or tobacco',
    titleQuestion: 'What do you want to stop?',
    titleHint: 'For example: Stop smoking cigarettes',
    todayActionHint:
        'Name one trigger and the replacement you will use instead',
    guardContextTag: 'nicotine',
    contentVersion: 1,
    reviewedOn: '2026-08-29',
    supportNote:
        'SoulBuddy can support triggers, routines, prayer and accountability. WHO recommends evidence-based behavioural support and cessation medicines; digital tools should complement, not replace, effective treatment.',
    sourceUrl: 'https://www.who.int/publications/i/item/9789240096431',
  ),
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.alcohol,
    label: 'Alcohol',
    titleQuestion: 'What change do you want help making with alcohol?',
    titleHint: 'Name the change you want to make with alcohol',
    todayActionHint: 'Choose one safe step that fits the guidance you reviewed',
    guardContextTag: 'alcohol',
    contentVersion: 1,
    reviewedOn: '2026-08-29',
    supportNote:
        'SoulBuddy does not assess withdrawal risk. The alcohol safety step comes before planning.',
    sourceUrl:
        'https://www.niaaa.nih.gov/health-professionals-communities/core-resource-on-alcohol/alcohol-use-disorder-risk-diagnosis-recovery',
  ),
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.digitalDistraction,
    label: 'Digital distraction',
    titleQuestion: 'What do you want to stop?',
    titleHint: 'For example: Stop losing hours to social media',
    todayActionHint:
        'Turn off one trigger or move one distracting app out of easy reach',
    guardContextTag: 'digital_distraction',
    contentVersion: 1,
    reviewedOn: '2026-08-29',
    supportNote:
        'This is behavior support for a change you chose. SoulBuddy does not label ordinary digital use as an addiction.',
  ),
  GoalStopBehaviorOption(
    key: GoalStopBehaviorKey.other,
    label: 'Something else',
    titleQuestion: 'What do you want to stop?',
    titleHint: 'Name it simply',
    todayActionHint: 'One small faithful step',
    guardContextTag: null,
    contentVersion: 1,
    reviewedOn: '2026-08-29',
  ),
];

GoalStopBehaviorOption? stopBehaviorOption(GoalStopBehaviorKey? key) {
  if (key == null) return null;
  for (final option in goalStopBehaviorOptions) {
    if (option.key == key) return option;
  }
  return null;
}

PrayerPurpose prayerPurposeForGoalStarter(GoalStarterKey starterKey) =>
    switch (starterKey) {
      GoalStarterKey.direction => PrayerPurpose.guidance,
      GoalStarterKey.difficultTime => PrayerPurpose.difficultTime,
      GoalStarterKey.closerToGod ||
      GoalStarterKey.stopControl ||
      GoalStarterKey.other => PrayerPurpose.daily,
    };
