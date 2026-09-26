import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_occurrence_calculator.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';

void main() {
  final calculator = CommitmentOccurrenceCalculator();
  test(
    'daily schedule follows device timezone without changing saved plan',
    () {
      final plan = testCommitmentPlan();
      expect(
        calculator.next(plan, after: DateTime.utc(2026, 9, 24, 6)),
        DateTime.utc(2026, 9, 24, 7),
      );
      expect(
        calculator.next(
          plan,
          after: DateTime.utc(2026, 9, 24, 6),
          timezoneName: 'Asia/Tokyo',
        ),
        DateTime.utc(2026, 9, 24, 23),
      );
      expect(plan.timezone, 'Africa/Lagos');
    },
  );
  test('selected days skips unselected days and handles DST wall time', () {
    final plan = testCommitmentPlan(
      frequency: CommitmentMeditationFrequency.selectedDays,
      mask: 1,
      zone: 'America/New_York',
    );
    expect(
      calculator.next(plan, after: DateTime.utc(2026, 3, 7)),
      DateTime.utc(2026, 3, 9, 12),
    );
  });
  test('a disabled plan has no next occurrence', () {
    expect(
      calculator.next(
        testCommitmentPlan(enabled: false),
        after: DateTime.utc(2026),
      ),
      isNull,
    );
  });
}

CommitmentMeditationPlan testCommitmentPlan({
  CommitmentMeditationFrequency frequency = CommitmentMeditationFrequency.daily,
  int? mask,
  String zone = 'Africa/Lagos',
  bool enabled = true,
}) => CommitmentMeditationPlan(
  id: 'plan',
  ownerId: 'owner',
  commitmentId: 'commitment',
  frequency: frequency,
  weekdaysMask: mask,
  localTime: '08:00',
  timezone: zone,
  durationMinutes: 10,
  enabled: enabled,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
