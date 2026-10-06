import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_release.dart';
import 'package:soulbuddy/features/prayers/presentation/weekly_prayer_preference_tile.dart';
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

  Future<void> pumpTile(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerReleaseRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: Scaffold(body: WeeklyPrayerPreferenceTile()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('is off until the person opts in', (tester) async {
    await pumpTile(tester);

    expect(find.text('Weekly prayers'), findsOneWidget);
    expect(find.text('One new prayer collection each week'), findsOneWidget);

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('weekly-prayers-preference')),
    );
    expect(tile.value, isFalse);
  });

  testWidgets('stores an opt-in with the device time zone', (tester) async {
    await pumpTile(tester);

    await tester.tap(find.byKey(const Key('weekly-prayers-preference')));
    await tester.pumpAndSettle();

    expect(repository.preference.weeklyEnabled, isTrue);
    expect(repository.preference.receivesDelivery, isTrue);
    expect(repository.preference.timeZone, isNotNull);
  });

  testWidgets('stops future delivery when turned off', (tester) async {
    repository.savePreference(
      const PrayerReleasePreference(
        weeklyEnabled: true,
        notificationEnabled: true,
        timeZone: 'UTC',
      ),
    );
    await pumpTile(tester);

    await tester.tap(find.byKey(const Key('weekly-prayers-preference')));
    await tester.pumpAndSettle();

    expect(repository.preference.weeklyEnabled, isFalse);
    expect(repository.preference.receivesDelivery, isFalse);
  });

  testWidgets('offers a retry when the preference cannot be stored', (
    tester,
  ) async {
    repository.failPreferenceSave = true;
    await pumpTile(tester);

    await tester.tap(find.byKey(const Key('weekly-prayers-preference')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('weekly-prayers-preference-retry')),
      findsOneWidget,
    );

    repository.failPreferenceSave = false;
    await tester.tap(find.byKey(const Key('weekly-prayers-preference-retry')));
    await tester.pumpAndSettle();

    // The retry repeats the choice that failed, not the stored one.
    expect(repository.preference.weeklyEnabled, isTrue);
    expect(
      find.byKey(const Key('weekly-prayers-preference-retry')),
      findsNothing,
    );
  });

  testWidgets('renders without overflow at two times text scale', (
    tester,
  ) async {
    await pumpTile(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Weekly prayers'), findsOneWidget);
  });
}
