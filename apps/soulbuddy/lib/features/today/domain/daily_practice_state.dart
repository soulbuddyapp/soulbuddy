import 'package:flutter/foundation.dart';

enum DailyPractice { pray, act, remember }

/// Factual availability and completion for one displayed local day.
@immutable
class DailyPracticeState {
  const DailyPracticeState({required this.available, required this.completed});

  final Set<DailyPractice> available;
  final Set<DailyPractice> completed;

  int get availableCount => available.length;
  int get completedCount => completed.length;
  bool get isValid => completed.every(available.contains);

  @override
  bool operator ==(Object other) {
    return other is DailyPracticeState &&
        setEquals(other.available, available) &&
        setEquals(other.completed, completed);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(available),
    Object.hashAllUnordered(completed),
  );
}
