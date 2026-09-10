import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_coordinator.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';
import 'package:soulbuddy/features/formation/presentation/formation_reading_screen.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/sacred_hours/domain/sacred_hour.dart';
import 'package:soulbuddy/features/sacred_hours/providers/sacred_hour_providers.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_reminder_coordinator.dart';
import 'package:soulbuddy/features/circles/application/circle_reminder_coordinator.dart';
import 'package:soulbuddy/features/circles/domain/circle.dart';
import 'package:soulbuddy/features/circles/providers/circle_providers.dart';

import '../helpers/in_memory_encounter_repository.dart';
import '../helpers/in_memory_prayer_repository.dart';

void main() {
  testWidgets('opens a formation reading from the production route', (
    tester,
  ) async {
    addTearDown(() => appRouter.go('/today'));
    appRouter.go('/formation/readings/overcoming-sin');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingCompleteProvider.overrideWith((ref) => true)],
        child: const SoulBuddyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(FormationReadingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows all five top-level destinations', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const SoulBuddyApp(),
      ),
    );

    for (final label in ['Today', 'Goals', 'Persons', 'Remember', 'Circles']) {
      expect(find.text(label), findsWidgets);
    }
    for (final key in [
      'nav-piece-today',
      'nav-piece-goal',
      'nav-piece-person',
      'nav-piece-remember',
      'nav-piece-circle',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    await tester.tap(find.text('Remember').last);
    await tester.pumpAndSettle();

    expect(find.text('Remember'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens reviewed or own-words prayer creation from the library', (
    tester,
  ) async {
    final encounters = InMemoryEncounterRepository();
    final prayers = InMemoryPrayerRepository(prayers: const []);
    addTearDown(encounters.close);
    addTearDown(prayers.close);
    appRouter.go('/prayers');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          encounterRepositoryProvider.overrideWith((ref) async => encounters),
          prayerRepositoryProvider.overrideWith((ref) async => prayers),
        ],
        child: const SoulBuddyApp(),
      ),
    );

    await tester.tap(find.byKey(const Key('for-this-moment-choice')));
    await tester.pumpAndSettle();

    expect(find.text('For this moment'), findsOneWidget);
    expect(
      find.text('Choose a reviewed prayer or use your own words.'),
      findsOneWidget,
    );
  });

  testWidgets('ordinary notification tap opens the owned saved prayer', (
    tester,
  ) async {
    final events = StreamController<PrayerReminderCoordinatorEvent>();
    addTearDown(events.close);
    appRouter.go('/today');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          prayerReminderEventsProvider.overrideWith((ref) => events.stream),
          duePrayerOccurrencesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          personalPrayerProvider(
            'prayer-1',
          ).overrideWith((ref) => Stream.value(_personalPrayer())),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    events.add(PrayerReminderOpened(_dueOccurrence()));
    await tester.pumpAndSettle();

    expect(find.text('Saved prayer'), findsOneWidget);
    expect(find.text('Evening prayer'), findsWidgets);
    expect(
      find.byKey(const Key('spiritual-session-mini-player')),
      findsOneWidget,
    );
  });

  testWidgets('opens a Sacred Hour session from its stable route', (
    tester,
  ) async {
    appRouter.go(
      '/sacred-hours/hour-1?occurrence='
      'hour-1%402026-08-31T05%3A00%3A00.000Z',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          sacredHourProvider(
            'hour-1',
          ).overrideWith((ref) => Stream.value(_sacredHour())),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Morning Sacred Hour'), findsOneWidget);
    expect(find.text('Begin with prayer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Sacred Hour notification action opens its occurrence', (
    tester,
  ) async {
    final events = StreamController<SacredHourOpened>();
    addTearDown(events.close);
    appRouter.go('/today');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          sacredHourReminderEventsProvider.overrideWith((ref) => events.stream),
          sacredHourProvider(
            'hour-1',
          ).overrideWith((ref) => Stream.value(_sacredHour())),
          currentOrNextSacredHourProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await tester.pump();
    events.add(
      const SacredHourOpened(
        hourId: 'hour-1',
        occurrenceKey: 'hour-1@2026-08-31T05:00:00.000Z',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Morning Sacred Hour'), findsOneWidget);
    expect(find.text('Begin with prayer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Circle notification action opens its Circle', (tester) async {
    final events = StreamController<CircleReminderOpened>();
    addTearDown(events.close);
    appRouter.go('/today');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((ref) => true),
          circleReminderEventsProvider.overrideWith((ref) => events.stream),
          circleProvider('circle-1').overrideWith((ref) async => _circle()),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await tester.pump();

    events.add(
      const CircleReminderOpened(
        circleId: 'circle-1',
        occurrenceKey: 'circle-1@2026-09-10T07:30:00.000Z',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Walk together'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Circle _circle() => Circle(
  publicId: 'circle-1',
  name: 'Walk together',
  category: CircleCategory.accountability,
  description: 'Honest accountability and prayer.',
  visibility: CircleVisibility.private,
  status: CircleStatus.active,
  directoryListed: false,
  provider: CircleProvider.telegram,
  openUri: Uri.parse('https://t.me/+walk-together'),
  capabilities: const ['open_link'],
  isOwner: false,
);

SacredHour _sacredHour() => SacredHour(
  id: 'hour-1',
  ownerId: 'owner-1',
  purpose: SacredHourPurpose.morning,
  name: 'Morning Sacred Hour',
  localTime: PrayerLocalTime(hour: 6, minute: 0),
  timezone: 'Africa/Lagos',
  durationMinutes: 60,
  prayerMinutes: 15,
  enabled: true,
  sound: SacredHourSound.gentleChime,
  createdAt: DateTime.utc(2026, 8, 31),
  updatedAt: DateTime.utc(2026, 8, 31),
);

PersonalPrayer _personalPrayer() => PersonalPrayer(
  id: 'prayer-1',
  ownerId: 'owner-1',
  title: 'Evening prayer',
  style: 'daily',
  reach: 'personal',
  grounding: PrayerGrounding.generalChristian,
  purpose: PrayerPurpose.daily,
  currentRevisionId: 'revision-1',
  body: 'Father, remain with me this evening. Amen.',
  createdAt: DateTime.utc(2026, 8, 11),
  updatedAt: DateTime.utc(2026, 8, 11),
);

DuePrayerOccurrence _dueOccurrence() {
  final at = DateTime.utc(2026, 8, 11, 18);
  return DuePrayerOccurrence(
    reminder: PrayerReminder(
      id: 'reminder-1',
      ownerId: 'owner-1',
      personalPrayerId: 'prayer-1',
      schedule: PrayerReminderSchedule.daily(
        localTime: PrayerLocalTime(hour: 19, minute: 0),
        timezone: 'Africa/Lagos',
      ),
      enabled: true,
      createdAt: at,
      updatedAt: at,
    ),
    device: PrayerReminderDevice(
      id: 'device-row-1',
      reminderId: 'reminder-1',
      deviceId: 'device-1',
      enabledOnDevice: true,
      nextOccurrenceAt: at,
      platformNotificationId: 77,
      scheduledTimezone: 'Africa/Lagos',
      updatedAt: at,
    ),
    prayerTitle: 'Evening prayer',
    prayerBody: 'Father, remain with me this evening. Amen.',
    prayerRevisionId: 'revision-1',
    occurrenceAt: at,
  );
}
