import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/onboarding/data/first_prayer_progress_repository.dart';
import 'package:soulbuddy/features/onboarding/domain/first_prayer_progress.dart';
import 'package:soulbuddy/features/onboarding/presentation/legacy_first_prayer_migration_screen.dart';
import 'package:soulbuddy/features/onboarding/providers/first_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../../helpers/in_memory_prayer_repository.dart';

void main() {
  testWidgets(
    'unfinished legacy setup moves explicitly to reviewed creation without generation',
    (tester) async {
      final progressRepository = _ProgressRepository(
        const FirstPrayerProgress(stage: FirstPrayerStage.detailChoice),
      );
      var generationReads = 0;
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstPrayerProgressRepositoryProvider.overrideWith(
              (ref) async => progressRepository,
            ),
            prayerGenerationRepositoryProvider.overrideWith((ref) async {
              generationReads++;
              throw StateError('Generation must not be read during migration.');
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with reviewed prayers'), findsOneWidget);
      expect(find.textContaining('external prayer-writing service'), findsNothing);
      expect(generationReads, 0);

      await tester.tap(
        find.byKey(const Key('legacy-prayer-continue-reviewed')),
      );
      await tester.pumpAndSettle();

      expect(progressRepository.cleared, isTrue);
      expect(find.text('reviewed-create'), findsOneWidget);
      expect(generationReads, 0);
    },
  );

  testWidgets('already-selected historical prayer still opens unchanged', (
    tester,
  ) async {
    const prayerId = '0198a100-0000-7000-8000-000000000003';
    final progressRepository = _ProgressRepository(
      const FirstPrayerProgress(
        stage: FirstPrayerStage.prayer,
        selectedPrayerType: 'library',
        selectedPrayerId: prayerId,
      ),
    );
    final prayers = InMemoryPrayerRepository(
      prayers: const [
        LibraryPrayer(
          id: prayerId,
          title: 'For guidance',
          body: 'Historical reviewed prayer body.',
          grounding: PrayerGrounding.generalChristian,
          purpose: PrayerPurpose.guidance,
          helpfulCount: 0,
          viewerMarkedHelpful: false,
        ),
      ],
    );
    addTearDown(prayers.close);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstPrayerProgressRepositoryProvider.overrideWith(
            (ref) async => progressRepository,
          ),
          prayerRepositoryProvider.overrideWith((ref) async => prayers),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historical reviewed prayer body.'), findsOneWidget);
    expect(find.text('Continue with reviewed prayers'), findsNothing);
    expect(progressRepository.cleared, isFalse);
  });

  testWidgets('migration choice remains usable at 320px and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progressRepository = _ProgressRepository(
      const FirstPrayerProgress(stage: FirstPrayerStage.detailChoice),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstPrayerProgressRepositoryProvider.overrideWith(
            (ref) async => progressRepository,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('legacy-prayer-continue-reviewed')),
    );
    expect(
      find.byKey(const Key('legacy-prayer-continue-reviewed')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/welcome/prayer',
    routes: [
      GoRoute(
        path: '/welcome/prayer',
        builder: (context, state) => const LegacyFirstPrayerMigrationScreen(),
      ),
      GoRoute(
        path: '/prayers/create',
        builder: (context, state) => const Text('reviewed-create'),
      ),
      GoRoute(
        path: '/today',
        builder: (context, state) => const Text('today'),
      ),
    ],
  );
}

class _ProgressRepository implements FirstPrayerProgressRepository {
  _ProgressRepository(this.progress);

  FirstPrayerProgress? progress;
  bool cleared = false;

  @override
  Future<FirstPrayerProgress?> load() async => progress;

  @override
  Future<void> save(FirstPrayerProgress value) async {
    progress = value;
  }

  @override
  Future<void> clear() async {
    progress = null;
    cleared = true;
  }
}
