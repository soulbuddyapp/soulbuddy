import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/editorial/data/editorial_prayer_repository.dart';
import 'package:soulbuddy/features/editorial/domain/editorial_item.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/providers/goal_onboarding_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

void main() {
  test('first Goal reads only the reviewed editorial prayer provider', () async {
    final repository = _FixtureEditorialPrayerRepository({
      PrayerPurpose.guidance: [
        _editorialPrayer(
          id: '0198a100-0000-7000-8000-000000000003',
          title: 'For guidance',
          purpose: PrayerPurpose.guidance,
        ),
      ],
    });
    final container = ProviderContainer(
      overrides: [
        editorialPrayerRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);

    final prayers = await container.read(
      firstGoalPrayerOptionsProvider(GoalStarterKey.direction).future,
    );

    expect(prayers.map((prayer) => prayer.title), ['For guidance']);
    expect(repository.purposes, [PrayerPurpose.guidance]);
  });

  test('first Goal fallback remains reviewed and capped at three', () async {
    final fallback = List.generate(
      4,
      (index) => _editorialPrayer(
        id: '0198a100-0000-7000-8000-00000000010${index + 1}',
        title: 'Reviewed ${index + 1}',
        purpose: PrayerPurpose.daily,
      ),
    );
    final repository = _FixtureEditorialPrayerRepository({null: fallback});
    final container = ProviderContainer(
      overrides: [
        editorialPrayerRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);

    final prayers = await container.read(
      firstGoalPrayerOptionsProvider(GoalStarterKey.direction).future,
    );

    expect(prayers.map((prayer) => prayer.title), [
      'Reviewed 1',
      'Reviewed 2',
      'Reviewed 3',
    ]);
    expect(repository.purposes, [PrayerPurpose.guidance, null]);
  });
}

class _FixtureEditorialPrayerRepository implements EditorialPrayerRepository {
  _FixtureEditorialPrayerRepository(this.itemsByPurpose);

  final Map<PrayerPurpose?, List<EditorialPrayer>> itemsByPurpose;
  final purposes = <PrayerPurpose?>[];

  @override
  Stream<List<EditorialPrayer>> watchApproved({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  }) {
    purposes.add(purpose);
    return Stream.value(itemsByPurpose[purpose] ?? const []);
  }

  @override
  Stream<EditorialPrayer?> watchApprovedPrayer(String id) => Stream.value(null);
}

EditorialPrayer _editorialPrayer({
  required String id,
  required String title,
  required PrayerPurpose purpose,
}) {
  return EditorialPrayer(
    prayer: LibraryPrayer(
      id: id,
      title: title,
      body: 'Father, help me take the next faithful step. Amen.',
      grounding: PrayerGrounding.generalChristian,
      purpose: purpose,
      helpfulCount: 0,
      viewerMarkedHelpful: false,
    ),
    editorial: EditorialItem(
      id: id,
      kind: EditorialContentKind.preparedPrayer,
      contentVersion: 1,
      provenance: 'soulbuddy_editorial',
      sourceRef: 'fixture:v1',
      reviewState: EditorialReviewState.approved,
      reviewedOn: DateTime.utc(2026, 8, 29),
      publishedAt: DateTime.utc(2026, 8, 29),
      tags: const ['prayer'],
    ),
  );
}
