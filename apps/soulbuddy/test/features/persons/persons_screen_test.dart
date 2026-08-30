import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/domain/prayer_person.dart';
import 'package:soulbuddy/features/persons/presentation/persons_screen.dart';
import 'package:soulbuddy/features/persons/providers/person_providers.dart';

void main() {
  testWidgets('gives a first person a compact, clear starting point', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: PersonsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Persons'), findsOneWidget);
    expect(
      find.text('Who would you like to remember in prayer?'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-first-person')), findsOneWidget);
  });

  testWidgets('shows saved people with relationship and cadence', (
    tester,
  ) async {
    final person = PrayerPerson(
      id: 'person-1',
      ownerId: 'owner-1',
      name: 'Mum',
      relationship: 'Mother',
      cadence: PersonPrayerCadence.daily,
      weekdaysMask: 0,
      createdAt: DateTime.utc(2026, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 30),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPeopleProvider.overrideWith((ref) => Stream.value([person])),
        ],
        child: const MaterialApp(home: Scaffold(body: PersonsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mum'), findsOneWidget);
    expect(find.text('Mother · Daily'), findsOneWidget);
  });

  testWidgets('empty state remains usable at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: PersonsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('add-first-person')), findsOneWidget);
  });
}
