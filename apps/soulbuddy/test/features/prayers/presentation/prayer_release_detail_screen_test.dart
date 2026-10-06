import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_release_detail_screen.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_release_providers.dart';

import '../../../helpers/in_memory_prayer_release_repository.dart';
import '../../../helpers/prayer_release_fixtures.dart';

void main() {
  late InMemoryPrayerReleaseRepository repository;

  setUp(() {
    repository = InMemoryPrayerReleaseRepository(
      releases: [releaseFixture()],
      content: {releaseSlug: releaseContentFixture()},
    );
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required GoRouter router,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/prayers/releases/$releaseSlug',
      routes: [
        GoRoute(
          path: '/prayers',
          builder: (context, state) => const Scaffold(body: Text('Prayers')),
        ),
        GoRoute(
          path: '/prayers/releases/:slug',
          builder: (context, state) =>
              PrayerReleaseDetailScreen(slug: state.pathParameters['slug']!),
        ),
        GoRoute(
          path: '/prayers/releases/:slug/attention',
          builder: (context, state) => const Scaffold(body: Text('Attention')),
        ),
        GoRoute(
          path: '/prayers/:prayerId',
          builder: (context, state) => Scaffold(
            body: Text('Prayer ${state.pathParameters['prayerId']}'),
          ),
        ),
      ],
    );
  }

  testWidgets('offers only the compact add action before an add', (
    tester,
  ) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);

    expect(find.text('This week’s prayer'), findsOneWidget);
    expect(find.text('Renewed mind & guarded heart'), findsOneWidget);
    expect(find.byKey(const Key('prayer-release-add')), findsOneWidget);

    // No entry bodies and no per-entry actions before an add.
    expect(find.text(firstPrayerBody), findsNothing);
    expect(find.text(repetitionsBody), findsNothing);
    expect(find.byKey(const Key('prayer-release-open-0')), findsNothing);
    expect(find.text('Be still before God'), findsNothing);
  });

  testWidgets('presents five ordered entries with their exact text', (
    tester,
  ) async {
    repository.putRelease(
      releaseFixture(added: true),
      items: releaseContentFixture(),
    );
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);

    for (var index = 0; index < 5; index++) {
      expect(find.byKey(Key('prayer-release-item-$index')), findsOneWidget);
    }

    expect(find.text('${1} \u00B7 Prayer'), findsOneWidget);
    expect(find.text('${2} \u00B7 Meditation prayer'), findsOneWidget);
    expect(find.text('${3} \u00B7 Prayer'), findsOneWidget);
    expect(find.text('${4} \u00B7 Meditation prayer'), findsOneWidget);
    expect(find.text('${5} \u00B7 Prayer'), findsOneWidget);

    expect(find.text(firstPrayerTitle), findsOneWidget);
    expect(find.text(meditationTitle), findsOneWidget);
    expect(find.text(thirdPrayerTitle), findsOneWidget);
    expect(find.text(repetitionsTitle), findsOneWidget);
    expect(find.text(fifthPrayerTitle), findsOneWidget);

    // The exact source wording, including the leading `+` and the counts.
    expect(find.text(firstPrayerBody), findsOneWidget);
    expect(find.text(repetitionsBody), findsOneWidget);
    expect(find.textContaining('(x50)'), findsOneWidget);
    expect(find.textContaining('(x10)'), findsOneWidget);
    expect(find.textContaining('rebuked o Lord'), findsOneWidget);
  });

  testWidgets('opens each canonical prayer in the ordinary detail flow', (
    tester,
  ) async {
    repository.putRelease(
      releaseFixture(added: true),
      items: releaseContentFixture(),
    );
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);
    await tester.ensureVisible(find.byKey(const Key('prayer-release-open-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prayer-release-open-4')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer release-prayer-4'), findsOneWidget);
  });

  testWidgets('offers the Prayer of attention only for the practice item', (
    tester,
  ) async {
    repository.putRelease(
      releaseFixture(added: true),
      items: releaseContentFixture(),
    );
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);
    await tester.ensureVisible(
      find.byKey(const Key('prayer-release-attention-3')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prayer-release-attention-3')), findsOneWidget);
    expect(find.byKey(const Key('prayer-release-attention-0')), findsNothing);

    await tester.tap(find.byKey(const Key('prayer-release-attention-3')));
    await tester.pumpAndSettle();

    expect(find.text('Attention'), findsOneWidget);
  });

  testWidgets('adds once and then presents the ordered collection', (
    tester,
  ) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);
    await tester.tap(find.byKey(const Key('prayer-release-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prayer-release-item-0')), findsOneWidget);
    expect(find.byKey(const Key('prayer-release-add')), findsNothing);
    expect(find.text(firstPrayerBody), findsOneWidget);
  });

  testWidgets('offers a retry when the add does not complete', (tester) async {
    repository.failAdd = true;
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router);
    await tester.tap(find.byKey(const Key('prayer-release-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prayer-release-retry')), findsOneWidget);
    expect(find.text('The prayers were not added.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.failAdd = false;
    await tester.tap(find.byKey(const Key('prayer-release-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prayer-release-item-0')), findsOneWidget);
  });

  testWidgets('renders without overflow at two times text scale', (
    tester,
  ) async {
    repository.putRelease(
      releaseFixture(added: true),
      items: releaseContentFixture(),
    );
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpDetail(tester, router: router, textScale: 2);

    // Scroll through every entry at the larger type size; the whole collection
    // must render without overflowing.
    await tester.scrollUntilVisible(
      find.byKey(const Key('prayer-release-item-4')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(fifthPrayerTitle), findsOneWidget);
  });

  testWidgets('says so plainly when the collection is unavailable', (
    tester,
  ) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    repository.dispose();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith(
            (ref) async => InMemoryPrayerReleaseRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection unavailable'), findsOneWidget);
  });
}
