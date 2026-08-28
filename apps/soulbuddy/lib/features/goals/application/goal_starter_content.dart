import '../domain/goal.dart';

class GoalStarterOption {
  const GoalStarterOption({
    required this.key,
    required this.label,
    this.suggestedTitle,
  });

  final GoalStarterKey key;
  final String label;
  final String? suggestedTitle;
}

const goalStarterOptions = <GoalStarterOption>[
  GoalStarterOption(
    key: GoalStarterKey.closerToGod,
    label: 'Grow closer to God',
    suggestedTitle: 'Grow closer to God',
  ),
  GoalStarterOption(
    key: GoalStarterKey.stopControl,
    label: 'Stop something fighting to control me',
    suggestedTitle: 'Stop something fighting to control me',
  ),
  GoalStarterOption(
    key: GoalStarterKey.direction,
    label: 'Find direction',
    suggestedTitle: 'Find direction',
  ),
  GoalStarterOption(
    key: GoalStarterKey.difficultTime,
    label: 'Get through a difficult time',
    suggestedTitle: 'Get through a difficult time',
  ),
  GoalStarterOption(key: GoalStarterKey.other, label: 'Something else'),
];

GoalStarterOption goalStarterOption(GoalStarterKey key) =>
    goalStarterOptions.firstWhere((option) => option.key == key);
