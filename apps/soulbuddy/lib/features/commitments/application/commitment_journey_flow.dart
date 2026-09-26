import '../domain/commitment.dart';

bool commitmentStageValid(
  CommitmentJourneyStage stage,
  CommitmentJourneyProgress p,
  List<CommitmentPracticeDraft> practices,
) {
  bool text(String field, String? value) {
    try {
      validateCommitmentText(field, value ?? '');
      return true;
    } on ArgumentError {
      return false;
    }
  }

  switch (stage) {
    case CommitmentJourneyStage.needs:
      return [
        p.keyNeedOne,
        p.keyNeedTwo,
        p.keyNeedThree,
      ].every((v) => text('need', v));
    case CommitmentJourneyStage.calling:
      return text('calling', p.calling);
    case CommitmentJourneyStage.practices:
      return practices.isNotEmpty &&
          practices.length <= 12 &&
          practices.every((v) => text('practice', v.body));
    case CommitmentJourneyStage.declaration:
      return p.declarationReviewed && text('declaration', p.declarationDraft);
    case CommitmentJourneyStage.guide:
      return p.guideId != null;
    case CommitmentJourneyStage.schedule:
      try {
        validateCommitmentPlan(
          frequency: p.frequency!,
          weekdaysMask: p.weekdaysMask,
          localTime: p.localTime!,
          timezone: p.timezone!,
          durationMinutes: p.durationMinutes!,
        );
        return p.reminderMode != null;
      } catch (_) {
        return false;
      }
    case CommitmentJourneyStage.name:
      return text('name', p.name);
    default:
      return true;
  }
}

CommitmentJourneyStage commitmentResumeStage(
  CommitmentJourneyProgress p,
  List<CommitmentPracticeDraft> practices,
) {
  for (final stage in CommitmentJourneyStage.values) {
    if (stage.index >= p.stage.index) break;
    if (!commitmentStageValid(stage, p, practices)) return stage;
  }
  return p.stage == CommitmentJourneyStage.finalizing
      ? CommitmentJourneyStage.summary
      : p.stage;
}
