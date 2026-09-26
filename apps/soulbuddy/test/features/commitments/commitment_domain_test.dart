import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';

void main() {
  test(
    'server UTC timestamps retain their instant without a timezone suffix',
    () {
      final utc = parseCommitmentUtcTimestamp('2026-09-25 23:30:00');
      expect(utc, DateTime.utc(2026, 9, 25, 23, 30));
      expect(utc.isUtc, isTrue);
      expect(parseCommitmentUtcTimestamp('2026-09-26T00:30:00+01:00'), utc);
    },
  );
  test('copyWith can clear optional selections explicitly', () {
    const draft = CommitmentJourneyProgress(
      personalPrayerId: 'p',
      personalPrayerRevisionId: 'r',
      weekdaysMask: 3,
    );
    expect(
      draft
          .copyWith(personalPrayerId: null, personalPrayerRevisionId: null)
          .personalPrayerId,
      isNull,
    );
    expect(draft.copyWith(weekdaysMask: null).weekdaysMask, isNull);
    expect(draft.copyWith().personalPrayerId, 'p');
  });
  test('Unicode bounds and enum errors never expose submitted text', () {
    expect(validateCommitmentText('name', ' 🙂 '), '🙂');
    expect(validateCommitmentText('name', '🙂' * 120).runes.length, 120);
    expect(
      () => validateCommitmentText('name', '🙂' * 121),
      throwsArgumentError,
    );
    expect(
      () => CommitmentGuideId.fromWire('private text'),
      throwsFormatException,
    );
    try {
      CommitmentGuideId.fromWire('private text');
    } catch (e) {
      expect(e.toString(), isNot(contains('private text')));
    }
    expect(CommitmentPracticeCategory.joyPleasure.wireValue, 'joy_pleasure');
    expect(() => validatePracticeCount(0), throwsArgumentError);
    expect(() => validatePracticeCount(12), returnsNormally);
    expect(() => validatePracticeCount(13), throwsArgumentError);
  });
  test('schedule rejects invalid masks and unknown timezone', () {
    expect(
      () => validateCommitmentPlan(
        frequency: CommitmentMeditationFrequency.daily,
        localTime: '07:30',
        timezone: 'Africa/Lagos',
        durationMinutes: 10,
      ),
      returnsNormally,
    );
    expect(
      () => validateCommitmentPlan(
        frequency: CommitmentMeditationFrequency.selectedDays,
        localTime: '07:30',
        timezone: 'Africa/Lagos',
        durationMinutes: 10,
      ),
      throwsArgumentError,
    );
    expect(
      () => validateCommitmentPlan(
        frequency: CommitmentMeditationFrequency.daily,
        localTime: '07:30',
        timezone: 'Fake/Private',
        durationMinutes: 10,
      ),
      throwsArgumentError,
    );
  });
  test('review is tenth local calendar date across month boundary', () {
    expect(commitmentReviewLocalDate('2026-09-25'), '2026-10-04');
  });
}
