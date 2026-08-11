import 'library_prayer.dart';

enum PrayerStyle {
  daily('daily'),
  situational('situational');

  const PrayerStyle(this.wireValue);

  final String wireValue;

  static PrayerStyle fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown prayer style: $value'),
  );
}

enum PrayerReach {
  personal('personal'),
  encompassing('encompassing');

  const PrayerReach(this.wireValue);

  final String wireValue;

  static PrayerReach fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown prayer reach: $value'),
  );
}

enum PrayerGenerationStatus {
  editing('editing'),
  queued('queued'),
  generating('generating'),
  ready('ready'),
  needsAttention('needs_attention');

  const PrayerGenerationStatus(this.wireValue);

  final String wireValue;

  static PrayerGenerationStatus fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () =>
        throw FormatException('Unknown prayer generation status: $value'),
  );
}

enum PrayerContextType {
  encounter('encounter'),
  scripture('scripture');

  const PrayerContextType(this.wireValue);

  final String wireValue;

  static PrayerContextType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown prayer context type: $value'),
  );
}

class PrayerGenerationContext {
  const PrayerGenerationContext._({
    required this.type,
    required this.sourceId,
    required this.displayLabel,
    required this.excerptSnapshot,
    this.translation,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
  });

  const PrayerGenerationContext.encounter({
    required String sourceId,
    required String displayLabel,
    required String excerptSnapshot,
  }) : this._(
         type: PrayerContextType.encounter,
         sourceId: sourceId,
         displayLabel: displayLabel,
         excerptSnapshot: excerptSnapshot,
       );

  const PrayerGenerationContext.scripture({
    required String sourceId,
    required String displayLabel,
    required String excerptSnapshot,
    required String translation,
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) : this._(
         type: PrayerContextType.scripture,
         sourceId: sourceId,
         displayLabel: displayLabel,
         excerptSnapshot: excerptSnapshot,
         translation: translation,
         book: book,
         chapter: chapter,
         firstVerse: firstVerse,
         lastVerse: lastVerse,
       );

  final PrayerContextType type;
  final String sourceId;
  final String displayLabel;
  final String excerptSnapshot;
  final String? translation;
  final String? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;

  factory PrayerGenerationContext.fromRow(Map<String, dynamic> row) {
    return PrayerGenerationContext._(
      type: PrayerContextType.fromWire(row['context_type'] as String),
      sourceId: row['source_id'] as String,
      displayLabel: row['display_label'] as String,
      excerptSnapshot: row['excerpt_snapshot'] as String,
      translation: row['translation'] as String?,
      book: row['book'] as String?,
      chapter: row['chapter'] as int?,
      firstVerse: row['first_verse'] as int?,
      lastVerse: row['last_verse'] as int?,
    );
  }
}

class PrayerGeneratedDraft {
  const PrayerGeneratedDraft({
    required this.title,
    required this.body,
    required this.promptVersion,
    this.action,
  });

  final String title;
  final String body;
  final String? action;
  final String promptVersion;
}

class PrayerGenerationRequest {
  const PrayerGenerationRequest({
    required this.id,
    required this.ownerId,
    required this.style,
    required this.reach,
    required this.grounding,
    required this.purpose,
    required this.requestText,
    required this.status,
    required this.attemptCount,
    required this.contexts,
    required this.createdAt,
    required this.updatedAt,
    this.beneficiaryChoice,
    this.surrenderChoice,
    this.responsibilityChoice,
    this.alignmentChoice,
    this.draftTitle,
    this.draftBody,
    this.draftAction,
    this.generatedTitle,
    this.generatedBody,
    this.generatedAction,
    this.promptVersion,
    this.providerDisclosureVersion,
    this.consentedProvider,
    this.consentedDisclosureVersion,
    this.activeAttemptId,
    this.attemptStartedAt,
    this.nextAttemptAt,
    this.lastAttemptAt,
    this.failureCode,
  });

  final String id;
  final String ownerId;
  final PrayerStyle style;
  final PrayerReach reach;
  final PrayerGrounding grounding;
  final PrayerPurpose purpose;
  final String requestText;
  final String? beneficiaryChoice;
  final String? surrenderChoice;
  final String? responsibilityChoice;
  final String? alignmentChoice;
  final PrayerGenerationStatus status;
  final String? draftTitle;
  final String? draftBody;
  final String? draftAction;
  final String? generatedTitle;
  final String? generatedBody;
  final String? generatedAction;
  final String? promptVersion;
  final String? providerDisclosureVersion;
  final String? consentedProvider;
  final String? consentedDisclosureVersion;
  final String? activeAttemptId;
  final DateTime? attemptStartedAt;
  final DateTime? nextAttemptAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String? failureCode;
  final List<PrayerGenerationContext> contexts;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasUserEdits =>
      generatedBody != null &&
      (draftTitle != generatedTitle ||
          draftBody != generatedBody ||
          draftAction != generatedAction);

  PrayerGenerationRequest copyWith({
    PrayerStyle? style,
    PrayerReach? reach,
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    String? requestText,
    String? beneficiaryChoice,
    String? surrenderChoice,
    String? responsibilityChoice,
    String? alignmentChoice,
    String? draftTitle,
    String? draftBody,
    String? draftAction,
    bool clearBeneficiaryChoice = false,
    bool clearSurrenderChoice = false,
    bool clearResponsibilityChoice = false,
    bool clearAlignmentChoice = false,
    bool clearDraftAction = false,
    List<PrayerGenerationContext>? contexts,
  }) {
    return PrayerGenerationRequest(
      id: id,
      ownerId: ownerId,
      style: style ?? this.style,
      reach: reach ?? this.reach,
      grounding: grounding ?? this.grounding,
      purpose: purpose ?? this.purpose,
      requestText: requestText ?? this.requestText,
      beneficiaryChoice: clearBeneficiaryChoice
          ? null
          : beneficiaryChoice ?? this.beneficiaryChoice,
      surrenderChoice: clearSurrenderChoice
          ? null
          : surrenderChoice ?? this.surrenderChoice,
      responsibilityChoice: clearResponsibilityChoice
          ? null
          : responsibilityChoice ?? this.responsibilityChoice,
      alignmentChoice: clearAlignmentChoice
          ? null
          : alignmentChoice ?? this.alignmentChoice,
      status: status,
      draftTitle: draftTitle ?? this.draftTitle,
      draftBody: draftBody ?? this.draftBody,
      draftAction: clearDraftAction ? null : draftAction ?? this.draftAction,
      generatedTitle: generatedTitle,
      generatedBody: generatedBody,
      generatedAction: generatedAction,
      promptVersion: promptVersion,
      providerDisclosureVersion: providerDisclosureVersion,
      consentedProvider: consentedProvider,
      consentedDisclosureVersion: consentedDisclosureVersion,
      activeAttemptId: activeAttemptId,
      attemptStartedAt: attemptStartedAt,
      nextAttemptAt: nextAttemptAt,
      attemptCount: attemptCount,
      lastAttemptAt: lastAttemptAt,
      failureCode: failureCode,
      contexts: contexts ?? this.contexts,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory PrayerGenerationRequest.fromRow(
    Map<String, dynamic> row, {
    List<PrayerGenerationContext> contexts = const [],
  }) {
    return PrayerGenerationRequest(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      style: PrayerStyle.fromWire(row['style'] as String),
      reach: PrayerReach.fromWire(row['reach'] as String),
      grounding: PrayerGrounding.fromWire(row['grounding'] as String),
      purpose: PrayerPurpose.fromWire(row['purpose'] as String),
      requestText: row['request_text'] as String,
      beneficiaryChoice: row['beneficiary_choice'] as String?,
      surrenderChoice: row['surrender_choice'] as String?,
      responsibilityChoice: row['responsibility_choice'] as String?,
      alignmentChoice: row['alignment_choice'] as String?,
      status: PrayerGenerationStatus.fromWire(row['status'] as String),
      draftTitle: row['draft_title'] as String?,
      draftBody: row['draft_body'] as String?,
      draftAction: row['draft_action'] as String?,
      generatedTitle: row['generated_title'] as String?,
      generatedBody: row['generated_body'] as String?,
      generatedAction: row['generated_action'] as String?,
      promptVersion: row['prompt_version'] as String?,
      providerDisclosureVersion: row['provider_disclosure_version'] as String?,
      consentedProvider: row['consented_provider'] as String?,
      consentedDisclosureVersion:
          row['consented_disclosure_version'] as String?,
      activeAttemptId: row['active_attempt_id'] as String?,
      attemptStartedAt: _optionalDate(row['attempt_started_at']),
      nextAttemptAt: _optionalDate(row['next_attempt_at']),
      attemptCount: row['attempt_count'] as int? ?? 0,
      lastAttemptAt: _optionalDate(row['last_attempt_at']),
      failureCode: row['failure_code'] as String?,
      contexts: List.unmodifiable(contexts),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

DateTime? _optionalDate(Object? value) {
  return value == null ? null : DateTime.parse(value as String);
}
