import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/presentation/prayer_detail_screen.dart';
import 'package:soulbuddy/features/prayers/presentation/prayers_screen.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../../helpers/in_memory_prayer_repository.dart';

void main() {
  test('filter and detail stream providers release unused watchers', () {
    expect(
      prayerLibraryProvider((grounding: null, purpose: null)).isAutoDispose,
      isTrue,
    );
    expect(prayerProvider('family').isAutoDispose, isTrue);
  });

  testWidgets('filters, opens, marks Helpful, and selects a prayer for today', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.close);
    await _pumpFlow(tester, repository: repository);

    expect(find.text('Prayers'), findsOneWidget);
    expect(find.byKey(const Key('prayers-living-vine')), findsNothing);
    expect(find.text('Prayer is communion'), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Personalized'), findsOneWidget);
    expect(find.byKey(const Key('personalized-choice')), findsOneWidget);
    expect(find.byKey(const Key('prayer-filter-disclosure')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Library')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('prayer-filter-disclosure'))).dy,
      ),
    );
    expect(find.text('Refine the library'), findsOneWidget);
    expect(find.byKey(const Key('grounding-general-christian')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For my family'), findsOneWidget);
    _expectNoRejectedVisualLanguage(tester);

    await tester.ensureVisible(
      find.byKey(const Key('prayer-filter-disclosure')),
    );
    await tester.tap(find.byKey(const Key('prayer-filter-disclosure')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('grounding-general-christian')),
    );
    await tester.tap(find.byKey(const Key('grounding-general-christian')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('purpose-family')));
    await tester.tap(find.byKey(const Key('purpose-family')));
    await tester.pumpAndSettle();

    expect(find.text('General Christian · Family'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For my family'), findsOneWidget);
    expect(find.text('A Catholic family prayer'), findsNothing);

    await tester.tap(find.text('For my family'));
    await tester.pumpAndSettle();

    expect(find.text(_familyPrayerBody), findsOneWidget);
    expect(find.text('Ease someone’s burden today.'), findsOneWidget);
    expect(find.text('Helpful · 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('helpful-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byKey(const Key('use-today')));
    await tester.pumpAndSettle();
    expect(find.text('Include the suggested action'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.byKey(const Key('confirm-use-today')));
    await tester.pumpAndSettle();

    expect(repository.selectedPrayerId, 'family');
    expect(repository.selectedIncludeAction, isTrue);
    expect(find.text('Today destination'), findsOneWidget);
  });

  testWidgets('keeps controls and prayer copy usable at 200% text scale', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpFlow(
      tester,
      repository: repository,
      textScaler: const TextScaler.linear(2),
    );

    for (final key in ['personalized-choice', 'prayer-filter-disclosure']) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
      );
    }
    await tester.tap(find.byKey(const Key('prayer-filter-disclosure')));
    await tester.pumpAndSettle();
    for (final key in ['grounding-all', 'grounding-general-christian']) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('For my family'));
    await tester.tap(find.text('For my family'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(_familyPrayerBody));
    expect(find.text(_familyPrayerBody), findsOneWidget);
    expect(tester.takeException(), isNull);

    final visibleCopy = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ')
        .toLowerCase();
    expect(visibleCopy, isNot(contains('streak')));
    expect(visibleCopy, isNot(contains('rank')));
    expect(visibleCopy, isNot(contains('leaderboard')));
  });

  testWidgets('keeps confirmation open while a Today selection is saving', (
    tester,
  ) async {
    final repository = DelayedSelectionPrayerRepository(prayers: _prayers());
    addTearDown(repository.completeSelection);
    addTearDown(repository.close);
    await _pumpFlow(tester, repository: repository);

    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('For my family'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('use-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-use-today')));
    await tester.pump();
    await repository.selectionStarted.future;

    expect(find.textContaining('Saving'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Use this prayer today?'), findsOneWidget);
    expect(find.text(_familyPrayerBody), findsOneWidget);

    repository.completeSelection();
    await tester.pumpAndSettle();

    expect(find.text('Today destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Retry preserves healthy shared providers when prayer startup fails',
    (tester) async {
      final repository = _repository();
      addTearDown(repository.close);
      final database = _UnusedAppDatabase();

      var databaseCreations = 0;
      var databaseDisposals = 0;
      var identityCreations = 0;
      var identityDisposals = 0;
      var repositoryAttempts = 0;
      final router = _prayersOnlyRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) async {
              databaseCreations += 1;
              ref.onDispose(() => databaseDisposals += 1);
              return database;
            }),
            localIdentityProvider.overrideWith((ref) async {
              identityCreations += 1;
              ref.onDispose(() => identityDisposals += 1);
              return const LocalIdentity(
                ownerId: 'test-owner',
                deviceId: 'test-device',
              );
            }),
            prayerRepositoryProvider.overrideWith((ref) async {
              await ref.watch(appDatabaseProvider.future);
              await ref.watch(localIdentityProvider.future);
              repositoryAttempts += 1;
              if (repositoryAttempts == 1) {
                throw StateError('prayer startup failed');
              }
              return repository;
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapLibraryRetry(tester);

      expect(repositoryAttempts, 2);
      expect(databaseCreations, 1);
      expect(databaseDisposals, 0);
      expect(identityCreations, 1);
      expect(identityDisposals, 0);
      await tester.scrollUntilVisible(
        find.text('For my family'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('For my family'), findsOneWidget);
    },
  );

  testWidgets('Retry rebuilds a failed shared identity provider', (
    tester,
  ) async {
    final repository = _repository();
    addTearDown(repository.close);
    final database = _UnusedAppDatabase();

    var databaseCreations = 0;
    var databaseDisposals = 0;
    var identityAttempts = 0;
    var repositoryAttempts = 0;
    final router = _prayersOnlyRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async {
            databaseCreations += 1;
            ref.onDispose(() => databaseDisposals += 1);
            return database;
          }),
          localIdentityProvider.overrideWith((ref) async {
            identityAttempts += 1;
            if (identityAttempts == 1) {
              throw StateError('identity startup failed');
            }
            return const LocalIdentity(
              ownerId: 'test-owner',
              deviceId: 'test-device',
            );
          }),
          prayerRepositoryProvider.overrideWith((ref) async {
            repositoryAttempts += 1;
            await ref.watch(appDatabaseProvider.future);
            await ref.watch(localIdentityProvider.future);
            return repository;
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapLibraryRetry(tester);

    expect(repositoryAttempts, 2);
    expect(identityAttempts, 2);
    expect(databaseCreations, 1);
    expect(databaseDisposals, 0);
    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For my family'), findsOneWidget);
  });
}

void _expectNoRejectedVisualLanguage(WidgetTester tester) {
  final copy = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join(' ')
      .toLowerCase();
  for (final word in [
    'vine',
    'branch',
    'blossom',
    'fruit',
    'olive tree',
    'memorial stone',
    'score',
    'streak',
    'leaderboard',
  ]) {
    expect(copy, isNot(contains(word)));
  }
}

GoRouter _prayersOnlyRouter() {
  return GoRouter(
    initialLocation: '/prayers',
    routes: [
      GoRoute(
        path: '/prayers',
        builder: (context, state) => const Scaffold(body: PrayersScreen()),
      ),
    ],
  );
}

Future<void> _tapLibraryRetry(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('The prayer library could not be opened just now.'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  expect(
    find.text('The prayer library could not be opened just now.'),
    findsOneWidget,
  );
  await tester.ensureVisible(find.text('Try again'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Try again'));
  await tester.pumpAndSettle();
}

Future<void> _pumpFlow(
  WidgetTester tester, {
  required InMemoryPrayerRepository repository,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final router = GoRouter(
    initialLocation: '/prayers',
    routes: [
      GoRoute(
        path: '/prayers',
        builder: (context, state) => const Scaffold(body: PrayersScreen()),
        routes: [
          GoRoute(
            path: ':prayerId',
            builder: (context, state) => Scaffold(
              body: PrayerDetailScreen(
                prayerId: state.pathParameters['prayerId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/today',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Today destination'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InMemoryPrayerRepository _repository() {
  return InMemoryPrayerRepository(prayers: _prayers());
}

List<LibraryPrayer> _prayers() {
  return const [
    LibraryPrayer(
      id: 'family',
      title: 'For my family',
      body: _familyPrayerBody,
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.family,
      helpfulCount: 12,
      viewerMarkedHelpful: false,
      action: 'Ease someone’s burden today.',
    ),
    LibraryPrayer(
      id: 'catholic-family',
      title: 'A Catholic family prayer',
      body: 'Lord, help this family. Through Christ our Lord. Amen.',
      grounding: PrayerGrounding.catholic,
      purpose: PrayerPurpose.family,
      helpfulCount: 4,
      viewerMarkedHelpful: false,
    ),
    LibraryPrayer(
      id: 'daily',
      title: 'For this day',
      body: 'Father, guide this day. In Jesus’ name. Amen.',
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.daily,
      helpfulCount: 2,
      viewerMarkedHelpful: false,
    ),
  ];
}

class _UnusedAppDatabase implements AppDatabase {
  @override
  PowerSyncDatabase get powersync => throw UnsupportedError(
    'The retry integration test does not access the database.',
  );

  @override
  Future<void> close() async {}
}

const _familyPrayerBody =
    'Father, hold my family in your mercy. Teach us to listen before '
    'answering, forgive without keeping score, and meet ordinary needs with '
    'patient love. Give us our daily bread and make our home ready to welcome '
    'and serve others. In Jesus’ name. Amen.';
