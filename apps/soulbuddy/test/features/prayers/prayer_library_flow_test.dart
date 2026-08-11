import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
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
    expect(find.text('Choose from library'), findsOneWidget);
    expect(find.text('Create personalized'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For my family'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('grounding-general-christian')),
    );
    await tester.tap(find.byKey(const Key('grounding-general-christian')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('purpose-family')));
    await tester.tap(find.byKey(const Key('purpose-family')));
    await tester.pumpAndSettle();

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

    for (final key in [
      'library-choice',
      'personalized-choice',
      'grounding-all',
      'grounding-general-christian',
    ]) {
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

  testWidgets('Retry rebuilds a failed prayer repository', (tester) async {
    final repository = _repository();
    addTearDown(repository.close);
    var attempts = 0;
    final router = GoRouter(
      initialLocation: '/prayers',
      routes: [
        GoRoute(
          path: '/prayers',
          builder: (context, state) => const Scaffold(body: PrayersScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerRepositoryProvider.overrideWith((ref) async {
            attempts += 1;
            if (attempts == 1) throw StateError('startup failed');
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

    await tester.scrollUntilVisible(
      find.text('The prayer library could not be opened just now.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('The prayer library could not be opened just now.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    await tester.scrollUntilVisible(
      find.text('For my family'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('For my family'), findsOneWidget);
  });
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

const _familyPrayerBody =
    'Father, hold my family in your mercy. Teach us to listen before '
    'answering, forgive without keeping score, and meet ordinary needs with '
    'patient love. Give us our daily bread and make our home ready to welcome '
    'and serve others. In Jesus’ name. Amen.';
