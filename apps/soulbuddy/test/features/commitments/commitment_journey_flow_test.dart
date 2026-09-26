import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/application/commitment_journey_flow.dart';

void main() {
  test('invalid answers cannot be skipped by restoring a later stage', () {
    final value = CommitmentJourneyProgress(
      stage: CommitmentJourneyStage.summary,
      invitationCompleted: true,
      keyNeedOne: 'Strength',
      keyNeedTwo: '',
      keyNeedThree: 'Patience',
    );
    expect(commitmentResumeStage(value, []), CommitmentJourneyStage.needs);
  });
  test('backward navigation remains at the chosen valid stage', () {
    const value = CommitmentJourneyProgress(
      stage: CommitmentJourneyStage.quietPlace,
    );
    expect(commitmentResumeStage(value, []), CommitmentJourneyStage.quietPlace);
  });
  test('declaration needs an explicit review', () {
    const value = CommitmentJourneyProgress(
      stage: CommitmentJourneyStage.declaration,
      declarationDraft: 'My pledge',
    );
    expect(
      commitmentStageValid(CommitmentJourneyStage.declaration, value, []),
      isFalse,
    );
  });
}
