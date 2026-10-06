import 'dart:convert';

import 'library_prayer.dart';

/// A published weekly prayer collection, mirrored locally so discovery works
/// offline. [addedAt] is null until the person deliberately adds it.
class PrayerRelease {
  const PrayerRelease({
    required this.id,
    required this.slug,
    required this.title,
    required this.discoveryLabel,
    required this.discoveryDetail,
    this.publishedAt,
    this.addedAt,
    this.items = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String discoveryLabel;
  final String discoveryDetail;
  final DateTime? publishedAt;
  final DateTime? addedAt;
  final List<PrayerReleaseItem> items;

  bool get added => addedAt != null;

  PrayerReleaseItem? get attentionItem {
    for (final item in items) {
      if (item.hasAttentionPractice) return item;
    }
    return null;
  }
}

/// One ordered entry of a release. Before an add this carries metadata only;
/// [PrayerReleaseItemContent] holds the exact wording afterwards.
class PrayerReleaseItem {
  const PrayerReleaseItem({
    required this.id,
    required this.sortOrder,
    required this.kind,
    required this.libraryPrayerId,
    this.title,
    this.hasAttentionPractice = false,
    this.narrationAvailable = false,
  });

  final String id;
  final int sortOrder;
  final PrayerReleaseItemKind kind;
  final String libraryPrayerId;
  final String? title;
  final bool hasAttentionPractice;
  final bool narrationAvailable;
}

enum PrayerReleaseItemKind { prayer, meditationPrayer }

extension PrayerReleaseItemKindValue on PrayerReleaseItemKind {
  String get wireValue => switch (this) {
    PrayerReleaseItemKind.prayer => 'prayer',
    PrayerReleaseItemKind.meditationPrayer => 'meditation_prayer',
  };

  /// The customer-facing type label; `kind` never alters the source wording.
  String get label => switch (this) {
    PrayerReleaseItemKind.prayer => 'Prayer',
    PrayerReleaseItemKind.meditationPrayer => 'Meditation prayer',
  };

  static PrayerReleaseItemKind fromWire(String value) => switch (value) {
    'prayer' => PrayerReleaseItemKind.prayer,
    'meditation_prayer' => PrayerReleaseItemKind.meditationPrayer,
    _ => throw FormatException('Unknown prayer release kind: $value'),
  };
}

/// The exact wording of an added release item, stored verbatim.
class PrayerReleaseItemContent {
  const PrayerReleaseItemContent({
    required this.releaseId,
    required this.releaseSlug,
    required this.sortOrder,
    required this.kind,
    required this.libraryPrayerId,
    required this.title,
    required this.body,
    required this.contentSha256,
    this.itemId,
    this.grounding,
    this.languageStyle,
    this.purpose,
    this.action,
    this.practice,
  });

  final String releaseId;
  final String releaseSlug;
  final int sortOrder;
  final PrayerReleaseItemKind kind;
  final String libraryPrayerId;
  final String title;
  final String body;
  final String contentSha256;

  /// The server's release-item id, used when recording a counted session.
  final String? itemId;
  final String? grounding;
  final String? languageStyle;
  final String? purpose;
  final String? action;
  final PrayerReleasePractice? practice;

  PrayerGrounding? get prayerGrounding => grounding == null
      ? null
      : PrayerGrounding.values
          .where((value) => value.wireValue == grounding)
          .firstOrNull;

  PrayerPurpose? get prayerPurpose => purpose == null
      ? null
      : PrayerPurpose.values
          .where((value) => value.wireValue == purpose)
          .firstOrNull;

  factory PrayerReleaseItemContent.fromRow(Map<String, dynamic> row) {
    return PrayerReleaseItemContent(
      releaseId: row['release_id'] as String,
      releaseSlug: row['release_slug'] as String,
      sortOrder: row['sort_order'] as int? ?? 0,
      kind: PrayerReleaseItemKindValue.fromWire(row['kind'] as String),
      libraryPrayerId: row['library_prayer_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      contentSha256: row['content_sha256'] as String,
      itemId: row['item_id'] as String?,
      grounding: row['grounding'] as String?,
      languageStyle: row['language_style'] as String?,
      purpose: row['purpose'] as String?,
      action: row['action'] as String?,
      practice: _practiceFromRow(
        row['practice_mode'] as String?,
        row['practice_steps_json'] as String?,
      ),
    );
  }

  static PrayerReleasePractice? _practiceFromRow(String? mode, String? steps) {
    if (mode == null && steps == null) return null;

    return PrayerReleasePractice.fromRow(mode, steps);
  }
}

/// The structured practice profile for one item. The phrase is the source line
/// without its repetition suffix, and [sourceLine] is the exact source text.
class PrayerReleasePractice {
  const PrayerReleasePractice({required this.mode, required this.steps});

  /// Internal name only; the experience is presented as a Prayer of attention.
  static const affirmationRepetition = 'affirmation_repetition';

  final String mode;
  final List<PrayerReleasePracticeStep> steps;

  factory PrayerReleasePractice.fromRow(String? mode, String? stepsJson) {
    if (mode == null || stepsJson == null || stepsJson.isEmpty) {
      throw const FormatException(
        'A practice profile needs its mode and steps.',
      );
    }

    final parsed = jsonDecode(stepsJson);
    if (parsed is! List || parsed.isEmpty) {
      throw const FormatException('Practice steps must be a non-empty list.');
    }

    final steps = <PrayerReleasePracticeStep>[];
    for (final entry in parsed) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Each practice step must be an object.');
      }
      steps.add(
        PrayerReleasePracticeStep(
          phrase: entry['phrase'] as String,
          targetCount: (entry['target_count'] as num).toInt(),
          sourceLine: entry['source_line'] as String,
        ),
      );
    }

    return PrayerReleasePractice(
      mode: mode,
      steps: List.unmodifiable(steps),
    );
  }
}

class PrayerReleasePracticeStep {
  const PrayerReleasePracticeStep({
    required this.phrase,
    required this.targetCount,
    required this.sourceLine,
  });

  /// The paced repetition text, which is the source line without its suffix.
  final String phrase;
  final int targetCount;

  /// The exact source line, including its repetition suffix.
  final String sourceLine;

  /// The source line must rebuild from the phrase and count, or the profile is
  /// not usable.
  bool rebuildsSourceLine() =>
      sourceLine == PrayerReleasePracticeStep.sourceLineFor(phrase, targetCount);

  static String sourceLineFor(String phrase, int targetCount) =>
      '$phrase (x$targetCount)';
}

/// The account's weekly delivery preference, cached locally.
class PrayerReleasePreference {
  const PrayerReleasePreference({
    this.weeklyEnabled = false,
    this.notificationEnabled = true,
    this.timeZone,
  });

  /// Opt-in is false until the person deliberately turns it on.
  final bool weeklyEnabled;
  final bool notificationEnabled;
  final String? timeZone;

  bool get receivesDelivery => weeklyEnabled && notificationEnabled;

  factory PrayerReleasePreference.fromRow(Map<String, dynamic> row) {
    return PrayerReleasePreference(
      weeklyEnabled: row['weekly_enabled'] == 1,
      notificationEnabled: row['notification_enabled'] == 1,
      timeZone: row['time_zone'] as String?,
    );
  }
}
