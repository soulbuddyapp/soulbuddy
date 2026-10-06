import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/presentation/weekly_prayer_release_card.dart';
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

  Future<void> pumpCard(
    WidgetTester tester, {
    required Widget child,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
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

  testWidgets('shows a compact pre-add state with one action', (tester) async {
    await pumpCard(
      tester,
      child: WeeklyPrayerReleaseCard(release: releaseFixture(), onOpen: () {}),
    );

    expect(find.text('This week’s prayer'), findsOneWidget);
    expect(find.text('Renewed mind & guarded heart'), findsOneWidget);
    expect(
      find.text(
        'Prayer and meditation for purity, discipline, and a renewed mind.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('weekly-prayer-release-add')), findsOneWidget);
    expect(find.text('Add prayers'), findsOneWidget);

    // No source wording and no second library heading.
    expect(find.text(repetitionsBody), findsNothing);
    expect(find.text(firstPrayerBody), findsNothing);
    expect(find.text(repetitionsTitle), findsNothing);
    expect(find.text(fifthPrayerTitle), findsNothing);
  });

  testWidgets('adds once and then shows the added state', (tester) async {
    await pumpCard(
      tester,
      child: WeeklyPrayerReleaseCard(
        release: releaseFixture(),
        onOpen: () {},
        onAdded: (slug) => repository.putRelease(
          releaseFixture(added: true),
          items: releaseContentFixture(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('weekly-prayer-release-add')));
    await tester.pumpAndSettle();

    expect(find.text('Added'), findsOneWidget);
    expect(find.byKey(const Key('weekly-prayer-release-add')), findsNothing);
  });

  testWidgets('offers a retry after a failed add', (tester) async {
    repository.failAdd = true;

    await pumpCard(
      tester,
      child: WeeklyPrayerReleaseCard(release: releaseFixture(), onOpen: () {}),
    );

    await tester.tap(find.byKey(const Key('weekly-prayer-release-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('weekly-prayer-release-retry')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Add prayers'), findsOneWidget);

    repository.failAdd = false;
    await tester.tap(find.byKey(const Key('weekly-prayer-release-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Added'), findsOneWidget);
    expect(find.byKey(const Key('weekly-prayer-release-retry')), findsNothing);
  });

  testWidgets('renders without overflow at two times text scale', (
    tester,
  ) async {
    await pumpCard(
      tester,
      textScale: 2,
      child: WeeklyPrayerReleaseCard(release: releaseFixture(), onOpen: () {}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Add prayers'), findsOneWidget);
  });

  testWidgets('opens the detail from the added state', (tester) async {
    var opened = false;

    await pumpCard(
      tester,
      child: WeeklyPrayerReleaseCard(
        release: releaseFixture(added: true),
        onOpen: () => opened = true,
      ),
    );

    await tester.tap(find.byKey(const Key('weekly-prayer-release-open')));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}
