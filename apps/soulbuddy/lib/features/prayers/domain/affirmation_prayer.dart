import 'prayer_release.dart';

/// The internal practice name. The customer-facing experience is a Prayer of
/// attention, and no customer-facing word may use these terms.
const String affirmationRepetitionMode = PrayerReleasePractice.affirmationRepetition;

/// The deliberate ways a counted prayer session can be answered.
enum AffirmationPrayerOutcome {
  /// Both phrases were counted to their targets.
  completed,

  /// The person stopped early; the actual counts are what was said.
  endedEarly;

  String get wireValue => name;
}

/// A counted prayer session record. Immutable once written: a completed or
/// ended-early session is never rewritten.
class AffirmationPrayerSession {
  const AffirmationPrayerSession({
    required this.id,
    required this.releaseItemId,
    required this.localDate,
    required this.startedAt,
    required this.endedAt,
    required this.outcome,
    required this.stepOneCount,
    required this.stepTwoCount,
    this.soundKey,
    this.narrationSpeed,
  });

  static const int stepOneTarget = 50;
  static const int stepTwoTarget = 10;

  final String id;
  final String releaseItemId;
  final String localDate;
  final DateTime startedAt;
  final DateTime endedAt;
  final AffirmationPrayerOutcome outcome;

  /// 0..50 for the first phrase.
  final int stepOneCount;

  /// 0..10 for the second phrase.
  final int stepTwoCount;

  final String? soundKey;
  final double? narrationSpeed;

  bool get completed => outcome == AffirmationPrayerOutcome.completed;

  Map<String, Object?> toRow({required String ownerId}) => {
    'id': id,
    'owner_id': ownerId,
    'release_item_id': releaseItemId,
    'local_date': localDate,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'outcome': outcome.wireValue,
    'step_one_count': stepOneCount,
    'step_two_count': stepTwoCount,
    'sound_key': soundKey,
    'narration_speed': narrationSpeed?.toString(),
  };

  /// The shape a terminal record must satisfy before it is written.
  ///
  /// A completed session requires exactly 50 and 10; an early exit records the
  /// counts actually reached and never exceeds either target.
  static void validate({
    required AffirmationPrayerOutcome outcome,
    required int stepOneCount,
    required int stepTwoCount,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (!endedAt.isBefore(startedAt) && endedAt != startedAt) {
      throw const FormatException('A session must end at or after it started.');
    }
    if (stepOneCount < 0 || stepOneCount > stepOneTarget) {
      throw const FormatException('The first phrase count is out of range.');
    }
    if (stepTwoCount < 0 || stepTwoCount > stepTwoTarget) {
      throw const FormatException('The second phrase count is out of range.');
    }
    if (outcome == AffirmationPrayerOutcome.completed &&
        (stepOneCount != stepOneTarget || stepTwoCount != stepTwoTarget)) {
      throw const FormatException(
        'A completed session needs the full count for both phrases.',
      );
    }
    if (outcome == AffirmationPrayerOutcome.endedEarly &&
        stepOneCount == stepOneTarget &&
        stepTwoCount == stepTwoTarget) {
      throw const FormatException(
        'A session with both phrases complete is a completed session.',
      );
    }
  }
}

/// The two structured repetition steps of the release item, already validated
/// against the source lines.
class AffirmationPrayerProfile {
  const AffirmationPrayerProfile({
    required this.stepOnePhrase,
    required this.stepOneSourceLine,
    required this.stepTwoPhrase,
    required this.stepTwoSourceLine,
  }) : stepOneTarget = AffirmationPrayerSession.stepOneTarget,
       stepTwoTarget = AffirmationPrayerSession.stepTwoTarget;

  final String stepOnePhrase;
  final int stepOneTarget;
  final String stepOneSourceLine;
  final String stepTwoPhrase;
  final int stepTwoTarget;
  final String stepTwoSourceLine;

  /// Reads the profile from a release item, refusing anything that does not
  /// rebuild its own source lines.
  static AffirmationPrayerProfile fromPractice(
    PrayerReleasePractice practice,
  ) {
    if (practice.mode != affirmationRepetitionMode || practice.steps.length != 2) {
      throw const FormatException(
        'This item does not carry the two counted prayer steps.',
      );
    }
    final steps = practice.steps;
    for (final step in steps) {
      if (!step.rebuildsSourceLine()) {
        throw const FormatException(
          'A counted prayer step must rebuild its exact source line.',
        );
      }
    }
    if (steps.first.targetCount != AffirmationPrayerSession.stepOneTarget ||
        steps.last.targetCount != AffirmationPrayerSession.stepTwoTarget) {
      throw const FormatException(
        'The counted prayer steps must target 50 and then 10.',
      );
    }

    return AffirmationPrayerProfile(
      stepOnePhrase: steps.first.phrase,
      stepOneSourceLine: steps.first.sourceLine,
      stepTwoPhrase: steps.last.phrase,
      stepTwoSourceLine: steps.last.sourceLine,
    );
  }
}
