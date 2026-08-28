enum GoalLinkType {
  personalPrayer('personal_prayer'),
  libraryPrayer('library_prayer'),
  encounter('encounter'),
  voiceTablet('voice_tablet'),
  circle('circle'),
  scripture('scripture');

  const GoalLinkType(this.wireValue);

  final String wireValue;

  static GoalLinkType fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal link type: $value'),
  );
}

enum GoalLinkRole {
  primaryPrayer('primary_prayer'),
  supportingPrayer('supporting_prayer'),
  primaryCircle('primary_circle'),
  support('support'),
  reference('reference');

  const GoalLinkRole(this.wireValue);

  final String wireValue;

  static GoalLinkRole fromWire(String value) => values.firstWhere(
    (item) => item.wireValue == value,
    orElse: () => throw FormatException('Unknown goal link role: $value'),
  );
}

class GoalLinkDraft {
  const GoalLinkDraft._({
    required this.type,
    required this.role,
    this.personalPrayerId,
    this.libraryPrayerId,
    this.encounterId,
    this.voiceTabletId,
    this.circleId,
    this.translation,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
  });

  const GoalLinkDraft.personalPrayer(
    String prayerId, {
    GoalLinkRole role = GoalLinkRole.primaryPrayer,
  }) : this._(
         type: GoalLinkType.personalPrayer,
         role: role,
         personalPrayerId: prayerId,
       );

  const GoalLinkDraft.libraryPrayer(
    String prayerId, {
    GoalLinkRole role = GoalLinkRole.primaryPrayer,
  }) : this._(
         type: GoalLinkType.libraryPrayer,
         role: role,
         libraryPrayerId: prayerId,
       );

  const GoalLinkDraft.encounter(
    String encounterId, {
    GoalLinkRole role = GoalLinkRole.reference,
  }) : this._(
         type: GoalLinkType.encounter,
         role: role,
         encounterId: encounterId,
       );

  const GoalLinkDraft.voiceTablet(
    String voiceTabletId, {
    GoalLinkRole role = GoalLinkRole.support,
  }) : this._(
         type: GoalLinkType.voiceTablet,
         role: role,
         voiceTabletId: voiceTabletId,
       );

  const GoalLinkDraft.circle(
    String circleId, {
    GoalLinkRole role = GoalLinkRole.primaryCircle,
  }) : this._(type: GoalLinkType.circle, role: role, circleId: circleId);

  const GoalLinkDraft.scripture({
    required String translation,
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
    GoalLinkRole role = GoalLinkRole.reference,
  }) : this._(
         type: GoalLinkType.scripture,
         role: role,
         translation: translation,
         book: book,
         chapter: chapter,
         firstVerse: firstVerse,
         lastVerse: lastVerse,
       );

  final GoalLinkType type;
  final GoalLinkRole role;
  final String? personalPrayerId;
  final String? libraryPrayerId;
  final String? encounterId;
  final String? voiceTabletId;
  final String? circleId;
  final String? translation;
  final String? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;

  bool get hasValidShape {
    final directTargets = [
      personalPrayerId,
      libraryPrayerId,
      encounterId,
      voiceTabletId,
      circleId,
    ].where((value) => value != null).length;
    final hasScripture =
        translation != null ||
        book != null ||
        chapter != null ||
        firstVerse != null ||
        lastVerse != null;

    return switch (type) {
      GoalLinkType.personalPrayer =>
        personalPrayerId != null && directTargets == 1 && !hasScripture,
      GoalLinkType.libraryPrayer =>
        libraryPrayerId != null && directTargets == 1 && !hasScripture,
      GoalLinkType.encounter =>
        encounterId != null && directTargets == 1 && !hasScripture,
      GoalLinkType.voiceTablet =>
        voiceTabletId != null && directTargets == 1 && !hasScripture,
      GoalLinkType.circle =>
        circleId != null && directTargets == 1 && !hasScripture,
      GoalLinkType.scripture =>
        directTargets == 0 &&
            translation != null &&
            book != null &&
            chapter != null &&
            chapter! > 0 &&
            firstVerse != null &&
            firstVerse! > 0 &&
            lastVerse != null &&
            lastVerse! >= firstVerse!,
    };
  }
}

class GoalLink {
  const GoalLink({
    required this.id,
    required this.goalId,
    required this.ownerId,
    required this.type,
    required this.role,
    required this.createdAt,
    this.personalPrayerId,
    this.libraryPrayerId,
    this.encounterId,
    this.voiceTabletId,
    this.circleId,
    this.translation,
    this.book,
    this.chapter,
    this.firstVerse,
    this.lastVerse,
    this.archivedAt,
  });

  final String id;
  final String goalId;
  final String ownerId;
  final GoalLinkType type;
  final GoalLinkRole role;
  final String? personalPrayerId;
  final String? libraryPrayerId;
  final String? encounterId;
  final String? voiceTabletId;
  final String? circleId;
  final String? translation;
  final String? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;
  final DateTime createdAt;
  final DateTime? archivedAt;

  factory GoalLink.fromRow(Map<String, dynamic> row) => GoalLink(
    id: row['id'] as String,
    goalId: row['goal_id'] as String,
    ownerId: row['owner_id'] as String,
    type: GoalLinkType.fromWire(row['link_type'] as String),
    role: GoalLinkRole.fromWire(row['role'] as String),
    personalPrayerId: row['personal_prayer_id'] as String?,
    libraryPrayerId: row['library_prayer_id'] as String?,
    encounterId: row['encounter_id'] as String?,
    voiceTabletId: row['voice_tablet_id'] as String?,
    circleId: row['circle_id'] as String?,
    translation: row['translation'] as String?,
    book: row['book'] as String?,
    chapter: (row['chapter'] as num?)?.toInt(),
    firstVerse: (row['first_verse'] as num?)?.toInt(),
    lastVerse: (row['last_verse'] as num?)?.toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
    archivedAt: switch (row['archived_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}
