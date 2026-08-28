import '../domain/goal.dart';

class GoalStarterOption {
  const GoalStarterOption({required this.key, required this.label});

  final GoalStarterKey key;
  final String label;
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
