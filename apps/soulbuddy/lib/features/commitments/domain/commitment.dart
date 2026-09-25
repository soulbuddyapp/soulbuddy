enum CommitmentJourneySlot {
  primary('primary');

  const CommitmentJourneySlot(this.wireValue);
  final String wireValue;
}

enum CommitmentGuideId {
  surrender('surrender'),
  direction('direction'),
  peace('peace');

  const CommitmentGuideId(this.wireValue);
  final String wireValue;
}

enum CommitmentPracticeCategory {
  joyPleasure('joy_pleasure'),
  explorationAdventure('exploration_adventure'),
  attentionSelfEsteem('attention_self_esteem');

  const CommitmentPracticeCategory(this.wireValue);
  final String wireValue;
}

abstract final class CommitmentTextLimits {
  static const name = 120;
  static const need = 500;
  static const calling = 1500;
  static const practice = 1000;
  static const declaration = 4000;

  static int forField(String field) => switch (field) {
    'name' => name,
    'need' => need,
    'calling' => calling,
    'practice' => practice,
    'declaration' => declaration,
    _ => throw ArgumentError.value(field, 'field'),
  };
}

String validateCommitmentText(String field, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.runes.length > CommitmentTextLimits.forField(field)) {
    throw ArgumentError.value(field, 'field');
  }
  return trimmed;
}

void validatePracticeCount(int count) {
  if (count < 1 || count > 12) throw ArgumentError.value(count, 'count');
}
