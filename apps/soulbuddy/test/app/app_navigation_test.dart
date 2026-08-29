import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/app/router.dart';
import 'package:soulbuddy/features/prayers/application/prayer_reminder_coordinator.dart';
import 'package:soulbuddy/features/onboarding/providers/onboarding_providers.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../helpers/in_memory_encounter_repository.dart';
import '../helpers/in_memory_prayer_repository.dart';

void main() {
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

    for (final label in ['Today', 'Goals', 'Record', 'Remember', 'Circles']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Remember').last);
    await tester.pumpAndSettle();

    expect(find.text('What you have recorded'), findsOneWidget);
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
    expect(find.text('Evening prayer'), findsOneWidget);
  });
}

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
