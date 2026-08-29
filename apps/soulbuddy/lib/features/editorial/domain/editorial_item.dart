import 'dart:convert';

enum EditorialContentKind {
  preparedPrayer('prepared_prayer'),
  prayerFrame('prayer_frame'),
  goalStarterCopy('goal_starter_copy'),
  returnCopy('return_copy'),
  guardInstruction('guard_instruction'),
  safetyNotice('safety_notice'),
  exhortation('exhortation'),
  bibleStudyQuestion('bible_study_question'),
  bibleStudyPlan('bible_study_plan');

  const EditorialContentKind(this.wireValue);

  final String wireValue;

  static EditorialContentKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wireValue == value,
    orElse: () =>
        throw FormatException('Unknown editorial content kind: $value'),
  );
}

enum EditorialReviewState {
  draft('draft'),
  approved('approved');

  const EditorialReviewState(this.wireValue);

  final String wireValue;

  static EditorialReviewState fromWire(String value) => values.firstWhere(
    (state) => state.wireValue == value,
    orElse: () =>
        throw FormatException('Unknown editorial review state: $value'),
  );
}

class EditorialItem {
  const EditorialItem({
    required this.id,
    required this.kind,
    required this.contentVersion,
    required this.provenance,
    required this.sourceRef,
    required this.reviewState,
    required this.reviewedOn,
    required this.publishedAt,
    required this.tags,
    this.archivedAt,
  });

  final String id;
  final EditorialContentKind kind;
  final int contentVersion;
  final String provenance;
  final String sourceRef;
  final EditorialReviewState reviewState;
  final DateTime reviewedOn;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final List<String> tags;

  bool get isSelectable =>
      reviewState == EditorialReviewState.approved &&
      publishedAt != null &&
      archivedAt == null;

  factory EditorialItem.fromRow(Map<String, dynamic> row) {
    final decodedTags = jsonDecode(row['tags_json'] as String);
    if (decodedTags is! List<dynamic> ||
        decodedTags.any((tag) => tag is! String)) {
      throw const FormatException('Editorial tags must be a string list.');
    }
    return EditorialItem(
      id: row['id'] as String,
      kind: EditorialContentKind.fromWire(row['content_kind'] as String),
      contentVersion: row['content_version'] as int,
      provenance: row['provenance'] as String,
      sourceRef: row['source_ref'] as String,
      reviewState: EditorialReviewState.fromWire(row['review_state'] as String),
      reviewedOn: _reviewDate(row['reviewed_on'] as String),
      publishedAt: _optionalDateTime(row['published_at'] as String?),
      archivedAt: _optionalDateTime(row['archived_at'] as String?),
      tags: List.unmodifiable(decodedTags.cast<String>()),
    );
  }
}

DateTime _reviewDate(String value) =>
    DateTime.parse('${value}T00:00:00.000Z').toUtc();

DateTime? _optionalDateTime(String? value) =>
    value == null ? null : DateTime.parse(value).toUtc();
