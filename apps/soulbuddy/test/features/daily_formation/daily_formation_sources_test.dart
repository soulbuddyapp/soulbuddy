import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_catalog.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_profile.dart';
import 'package:soulbuddy/features/daily_formation/domain/formation_progress.dart';
import 'package:soulbuddy/features/daily_formation/presentation/daily_formation_card.dart';
import 'package:soulbuddy/features/daily_formation/providers/daily_formation_providers.dart';

void main() {
  testWidgets(
    'alternative teaching sources remain reachable on a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalog = FormationCatalog(
        version: 1,
        sourceSha256: 'test',
        videos: [
          for (var index = 1; index <= 3; index++)
            FormationVideo(
              id: 'V$index',
              title: 'Teaching $index',
              channel: 'BibleProject',
              youtubeUrl: 'https://www.youtube.com/watch?v=test$index',
              youtubeId: 'test$index',
              runtimeSeconds: 300,
              status: 'PRODUCTION_READY',
            ),
        ],
        packs: const [FormationPack(id: 'P01', order: 1, title: 'Renewal')],
        days: const [
          FormationDay(
            id: 'D001',
            day: 1,
            packId: 'P01',
            focus: 'Renew the mind',
            objective: 'Practice attentive listening.',
            scripture: 'Romans 12:2',
            reflection: 'What deserves attention?',
            action: 'Read Scripture.',
            videoIds: ['V1', 'V2', 'V3'],
          ),
        ],
        rules: const [],
      );
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
          ],
          child: const MaterialApp(home: Scaffold(body: DailyFormationCard())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose another'));
      await tester.pumpAndSettle();
      expect(find.text('More teaching'), findsOneWidget);
      await tester.ensureVisible(find.text('Dr. Myles Munroe · Munroe Global'));
      await tester.pumpAndSettle();
      expect(find.text('BibleProject'), findsWidgets);
      expect(find.text('Fr. Mike Schmitz · Ascension'), findsOneWidget);
      expect(find.text('Dr. Myles Munroe · Munroe Global'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
