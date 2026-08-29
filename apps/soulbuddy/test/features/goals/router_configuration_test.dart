import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../../helpers/in_memory_prayer_repository.dart';

void main() {
  test('Goals shell constructs with legacy prayer routes preserved', () {
    expect(appRouter, isNotNull);
  });

  testWidgets('new prayer route opens reviewed and own-words flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => appRouter.go('/today'));

    appRouter.go('/prayers/create');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('For this moment'), findsOneWidget);
    expect(find.text('Choose a prayer style'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy prayer deep link stays inside the Goals shell branch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryPrayerRepository(prayers: const []);
    addTearDown(repository.close);
    addTearDown(() => appRouter.go('/today'));

    appRouter.go('/prayers/missing-prayer');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prayer not found'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
