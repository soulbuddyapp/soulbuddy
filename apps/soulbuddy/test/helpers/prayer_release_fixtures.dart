import 'package:soulbuddy/features/prayers/domain/prayer_release.dart';

const releaseSlug = 'renewed-mind-and-guarded-heart-v1';

const firstPrayerTitle = 'Daily Prayer Against Temptations';
const firstPrayerBody =
    '+\nJesus humbled himself unto death, even death on a Cross\n'
    'May I not regress in my transformation journey to be as Christ';

const meditationTitle = 'Brief Meditation';
const thirdPrayerTitle = 'Affirmative Prayer to resist occasions of Sin';
const repetitionsTitle = 'New Adam repetitions';
const repetitionsBody =
    'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)\n'
    'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)';
const fifthPrayerTitle =
    'Daily Prayer to join our hearts to the heart of Jesus';

const preparationText = 'Before you Pray - Preparation for a graceful prayer\n'
    'Begin with the sign of the cross.';

PrayerRelease releaseFixture({
  bool added = false,
  String? addedAt,
  bool withAttentionItem = true,
}) {
  return PrayerRelease(
    id: 'release-1',
    slug: releaseSlug,
    title: 'Renewed mind & guarded heart',
    discoveryLabel: 'This week’s prayer',
    discoveryDetail:
        'Prayer and meditation for purity, discipline, and a renewed mind.',
    publishedAt: DateTime.utc(2026, 10, 5, 7),
    addedAt: added ? (DateTime.tryParse(addedAt ?? '2026-10-06T09:00:00Z')) : null,
    items: [
      PrayerReleaseItem(
        id: 'release-item-0',
        sortOrder: 0,
        kind: PrayerReleaseItemKind.prayer,
        libraryPrayerId: 'release-prayer-0',
        title: firstPrayerTitle,
      ),
      PrayerReleaseItem(
        id: 'release-item-1',
        sortOrder: 1,
        kind: PrayerReleaseItemKind.meditationPrayer,
        libraryPrayerId: 'release-prayer-1',
        title: meditationTitle,
      ),
      PrayerReleaseItem(
        id: 'release-item-2',
        sortOrder: 2,
        kind: PrayerReleaseItemKind.prayer,
        libraryPrayerId: 'release-prayer-2',
        title: thirdPrayerTitle,
      ),
      if (withAttentionItem)
        PrayerReleaseItem(
          id: 'release-item-3',
          sortOrder: 3,
          kind: PrayerReleaseItemKind.meditationPrayer,
          libraryPrayerId: 'release-prayer-3',
          title: repetitionsTitle,
          hasAttentionPractice: true,
        ),
      PrayerReleaseItem(
        id: 'release-item-4',
        sortOrder: 4,
        kind: PrayerReleaseItemKind.prayer,
        libraryPrayerId: 'release-prayer-4',
        title: fifthPrayerTitle,
      ),
    ],
  );
}

/// The five ordered entries with their exact wording.
List<PrayerReleaseItemContent> releaseContentFixture() {
  PrayerReleaseItemContent item(
    int sortOrder,
    PrayerReleaseItemKind kind,
    String title,
    String body,
    String libraryPrayerId, {
    PrayerReleasePractice? practice,
  }) {
    return PrayerReleaseItemContent(
      releaseId: 'release-1',
      releaseSlug: releaseSlug,
      sortOrder: sortOrder,
      kind: kind,
      libraryPrayerId: libraryPrayerId,
      title: title,
      body: body,
      contentSha256: 'hash-$sortOrder',
      itemId: 'release-item-$sortOrder',
      grounding: 'general_christian',
      languageStyle: 'christian',
      purpose: kind == PrayerReleaseItemKind.prayer ? 'daily' : 'guidance',
      action: null,
      practice: practice,
    );
  }

  const stepOnePhrase =
      'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus';
  const stepTwoPhrase =
      'In moments that distract me from your perfect will, let Satan be rebuked o Lord';

  return [
    item(0, PrayerReleaseItemKind.prayer, firstPrayerTitle, firstPrayerBody,
        'release-prayer-0'),
    item(
      1,
      PrayerReleaseItemKind.meditationPrayer,
      meditationTitle,
      'The Holy Spirit is our greatest gift for transformation.',
      'release-prayer-1',
    ),
    item(
      2,
      PrayerReleaseItemKind.prayer,
      thirdPrayerTitle,
      '+\nI hereby give myself to God',
      'release-prayer-2',
    ),
    item(
      3,
      PrayerReleaseItemKind.meditationPrayer,
      repetitionsTitle,
      repetitionsBody,
      'release-prayer-3',
      practice: const PrayerReleasePractice(
        mode: PrayerReleasePractice.affirmationRepetition,
        steps: [
          PrayerReleasePracticeStep(
            phrase: stepOnePhrase,
            targetCount: 50,
            sourceLine: '$stepOnePhrase (x50)',
          ),
          PrayerReleasePracticeStep(
            phrase: stepTwoPhrase,
            targetCount: 10,
            sourceLine: '$stepTwoPhrase (x10)',
          ),
        ],
      ),
    ),
    item(
      4,
      PrayerReleaseItemKind.prayer,
      fifthPrayerTitle,
      'Heavenly Father, Your Word says that out of the abundance of the heart, '
      'the mouth speaks.',
      'release-prayer-4',
    ),
  ];
}
