import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/data/daily_formation_repository.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_catalog.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_profile.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_progress.dart';
import 'package:soulbuddy/features/daily_formation/presentation/daily_formation_card.dart';
import 'package:soulbuddy/features/daily_formation/providers/daily_formation_providers.dart';
import 'package:soulbuddy/features/guide/data/guide_repository.dart';
import 'package:soulbuddy/features/guide/providers/guide_providers.dart';

void main() {
  testWidgets('first teaching saves a named private reflection', (
    tester,
  ) async {
    final data = <String, String>{};
    Future<String?> read(String key) async => data[key];
    Future<void> write(String key, String value) async {
      data[key] = value;
    }

    final catalog = FormationCatalog(
      version: 1,
      sourceSha256: 'test',
      videos: [
        FormationVideo(
          id: 'V1',
          title: 'Teaching',
          channel: 'Source',
          youtubeUrl: 'https://youtube.com/watch?v=123',
          youtubeId: '123',
          runtimeSeconds: 60,
          status: 'PRODUCTION_READY',
        ),
      ],
      packs: const [FormationPack(id: 'P1', order: 1, title: 'Formation')],
      days: const [
        FormationDay(
          id: 'D1',
          day: 1,
          packId: 'P1',
          focus: 'Image of God',
          objective: '',
          scripture: 'Genesis 1',
          reflection: 'Original',
          action: 'Act',
          videoIds: ['V1'],
        ),
      ],
      rules: const [],
    );
    final repo = DailyFormationRepository(read: read, write: write);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyFormationCatalogProvider.overrideWith((ref) async => catalog),
          dailyFormationProfileProvider.overrideWith(
            (ref) async => const FormationProfile(ready: true, minutes: 10),
          ),
          dailyFormationProgressProvider.overrideWith(
            (ref) async => const FormationProgress.initial(),
          ),
          dailyFormationRepositoryProvider.overrideWithValue(repo),
          guideRepositoryProvider.overrideWithValue(
            GuideRepository(read: read, write: write),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DailyFormationCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your Guide'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Mika');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Private reflection'), findsOneWidget);
    expect(find.text('Mika'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'My sister listened');
    await tester.ensureVisible(find.text('Complete today'));
    await tester.tap(find.text('Complete today'));
    await tester.pumpAndSettle();
    expect(data[GuideRepository.storageKey], 'Mika');
    expect(
      (await repo.load()).completions.single.reflection,
      'My sister listened',
    );
  });
}
