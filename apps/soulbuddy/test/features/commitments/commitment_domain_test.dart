import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';

void main() {
  test('uses stable values and Unicode-safe text limits', () {
    expect(CommitmentJourneySlot.primary.wireValue, 'primary');
    expect(CommitmentGuideId.surrender.wireValue, 'surrender');
    expect(CommitmentPracticeCategory.joyPleasure.wireValue, 'joy_pleasure');
    expect(CommitmentTextLimits.name, 120);
    expect(validateCommitmentText('name', '🙂' * 120).runes, hasLength(120));
    expect(
      () => validateCommitmentText('name', '🙂' * 121),
      throwsArgumentError,
    );
  });

  test('accepts one to twelve practices', () {
    expect(() => validatePracticeCount(0), throwsArgumentError);
    expect(() => validatePracticeCount(12), returnsNormally);
    expect(() => validatePracticeCount(13), throwsArgumentError);
  });
}
