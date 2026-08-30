import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/persons/data/person_repository.dart';
import 'package:soulbuddy/features/persons/domain/person_prayer_occurrence.dart';
import 'package:soulbuddy/features/persons/domain/prayer_person.dart';
import 'package:soulbuddy/features/persons/presentation/person_editor_screen.dart';
import 'package:soulbuddy/features/persons/providers/person_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';

void main() {
  testWidgets(
    'permission denial keeps the saved Person and explains reminders',
    (tester) async {
      final person = _person();
      final repository = _EditorRepository(person);
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (_, _) => const PersonEditorScreen(personId: 'person-1'),
          ),
          GoRoute(
            path: '/persons/:personId',
            builder: (_, state) => Scaffold(
              body: Text('Saved ${state.pathParameters['personId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prayerPersonProvider.overrideWith(
              (ref, id) => Stream.value(person),
            ),
            personRepositoryProvider.overrideWith((ref) async => repository),
            prayerDeviceTimezoneProvider.overrideWith(
              (ref) =>
                  () async => 'UTC',
            ),
            enablePersonPrayerRemindersProvider.overrideWith(
              (ref) =>
                  () async => false,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.updates, 1);
      expect(find.text('Saved person-1'), findsOneWidget);
      expect(
        find.text(
          'Person saved. Allow notifications to receive prayer reminders.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not save this person yet.'), findsNothing);
    },
  );

  testWidgets('timezone failure never blocks the core Person save', (
    tester,
  ) async {
    final person = _person();
    final repository = _EditorRepository(person);
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/edit',
          builder: (_, _) => const PersonEditorScreen(personId: 'person-1'),
        ),
        GoRoute(
          path: '/persons/:personId',
          builder: (_, state) =>
              Scaffold(body: Text('Saved ${state.pathParameters['personId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prayerPersonProvider.overrideWith((ref, id) => Stream.value(person)),
          personRepositoryProvider.overrideWith((ref) async => repository),
          prayerDeviceTimezoneProvider.overrideWith(
            (ref) =>
                () async => throw StateError('timezone unavailable'),
          ),
          enablePersonPrayerRemindersProvider.overrideWith(
            (ref) =>
                () async => true,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.updates, 1);
    expect(repository.lastDraft?.timezone, isNull);
    expect(find.text('Saved person-1'), findsOneWidget);
    expect(
      find.text('Person saved. Check the prayer reminder time on this device.'),
      findsOneWidget,
    );
    expect(find.text('Could not save this person yet.'), findsNothing);
  });
}

PrayerPerson _person() => PrayerPerson(
  id: 'person-1',
  ownerId: 'owner-1',
  name: 'Mum',
  relationship: 'Mother',
  cadence: PersonPrayerCadence.daily,
  localTime: '07:30',
  timezone: 'UTC',
  weekdaysMask: 0,
  createdAt: DateTime.utc(2026, 8, 30),
  updatedAt: DateTime.utc(2026, 8, 30),
);

class _EditorRepository implements PersonRepository {
  _EditorRepository(this.person);
  final PrayerPerson person;
  int updates = 0;
  PrayerPersonDraft? lastDraft;

  @override
  Future<PrayerPerson> update(String id, PrayerPersonDraft draft) async {
    updates++;
    lastDraft = draft;
    return person;
  }

  @override
  Stream<PrayerPerson?> watch(String id) => Stream.value(person);

  @override
  Future<void> archive(String id) => throw UnimplementedError();

  @override
  Future<PrayerPerson> create(PrayerPersonDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PersonPrayerOccurrence?> recordPrayer(
    String personId, {
    required DateTime localDate,
  }) => throw UnimplementedError();

  @override
  Stream<List<PrayerPerson>> watchActive() => throw UnimplementedError();

  @override
  Stream<List<DuePersonPrayer>> watchDue(DateTime localDate) =>
      throw UnimplementedError();

  @override
  Stream<List<PrayerPerson>> watchForReminders() => throw UnimplementedError();

  @override
  Stream<List<Encounter>> watchLinkedMemories(String personId) =>
      throw UnimplementedError();
}
