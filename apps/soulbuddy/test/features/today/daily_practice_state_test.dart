import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/remember/domain/daily_memory.dart';
import 'package:soulbuddy/features/remember/providers/daily_memory_providers.dart';
import 'package:soulbuddy/features/today/domain/daily_practice_state.dart';
import 'package:soulbuddy/features/today/providers/daily_practice_providers.dart';

void main() {
  test('projects factual Pray, Act, and Remember completion', () async {
    final container = _container(
      today: _today(actionCompleted: true),
      memory: _memory(DailyMemoryStatus.remembered),
      prayed: true,
    );
    addTearDown(container.dispose);

    expect(
      await _nextData(container),
      const DailyPracticeState(
        available: {
          DailyPractice.pray,
          DailyPractice.act,
          DailyPractice.remember,
        },
        completed: {
          DailyPractice.pray,
          DailyPractice.act,
          DailyPractice.remember,
        },
      ),
    );
  });

  test('excludes an absent practical action', () async {
    final container = _container(
      today: _today(includeAction: false),
      memory: _memory(DailyMemoryStatus.active),
      prayed: true,
    );
    addTearDown(container.dispose);

    expect(
      await _nextData(container),
      const DailyPracticeState(
        available: {DailyPractice.pray, DailyPractice.remember},
        completed: {DailyPractice.pray},
      ),
    );
  });

  test('does not mark a selected prayer as prayed', () async {
    final container = _container(today: _today(), memory: null, prayed: false);
    addTearDown(container.dispose);

    expect(
      await _nextData(container),
      const DailyPracticeState(
        available: {DailyPractice.pray, DailyPractice.act},
        completed: {},
      ),
    );
  });

  test('projects remembrance without requiring a selected prayer', () async {
    final container = _container(
      today: null,
      memory: _memory(DailyMemoryStatus.remembered),
      prayed: false,
    );
    addTearDown(container.dispose);

    expect(
      await _nextData(container),
      const DailyPracticeState(
        available: {DailyPractice.remember},
        completed: {DailyPractice.remember},
      ),
    );
  });

  test('ignores prayer and remembrance values from a stale date', () async {
    final container = _container(
      today: _today(localDate: DateTime(2026, 8, 12)),
      memory: _memory(
        DailyMemoryStatus.remembered,
        localDate: DateTime(2026, 8, 12),
      ),
      prayed: true,
    );
    addTearDown(container.dispose);

    expect(
      await _nextData(container),
      const DailyPracticeState(available: {}, completed: {}),
    );
  });

  test('surfaces a session projection failure', () async {
    final container = ProviderContainer(
      overrides: [
        todayPrayerDateProvider.overrideWith(
          (ref) => Stream.value((year: 2026, month: 8, day: 13)),
        ),
        todayPrayerProvider.overrideWith((ref) => Stream.value(_today())),
        dailyMemoryProvider.overrideWith((ref) => Stream.value(null)),
        prayerSessionForDateProvider.overrideWith(
          (ref, request) => Stream.error(StateError('session unavailable')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(_nextData(container), throwsStateError);
  });

  test('reprojects every later repository emission', () async {
    final todayChanges = StreamController<TodayPrayer>();
    addTearDown(todayChanges.close);
    final container = ProviderContainer(
      overrides: [
        todayPrayerDateProvider.overrideWith(
          (ref) => Stream.value((year: 2026, month: 8, day: 13)),
        ),
        todayPrayerProvider.overrideWith((ref) async* {
          yield _today();
          yield* todayChanges.stream;
        }),
        dailyMemoryProvider.overrideWith((ref) => Stream.value(null)),
        prayerSessionForDateProvider.overrideWith(
          (ref, request) => Stream.value(false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final updated = Completer<DailyPracticeState>();
    final subscription = container.listen(dailyPracticeStateProvider, (
      previous,
      next,
    ) {
      if (next case AsyncData(:final value)
          when value.completed.contains(DailyPractice.act) &&
              !updated.isCompleted) {
        updated.complete(value);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await _nextData(container);

    todayChanges.add(_today(actionCompleted: true));

    expect(
      await updated.future,
      const DailyPracticeState(
        available: {DailyPractice.pray, DailyPractice.act},
        completed: {DailyPractice.act},
      ),
    );
  });
}

ProviderContainer _container({
  required TodayPrayer? today,
  required DailyMemory? memory,
  required bool prayed,
}) {
  return ProviderContainer(
    overrides: [
      todayPrayerDateProvider.overrideWith(
        (ref) => Stream.value((year: 2026, month: 8, day: 13)),
      ),
      todayPrayerProvider.overrideWith((ref) => Stream.value(today)),
      dailyMemoryProvider.overrideWith((ref) => Stream.value(memory)),
      prayerSessionForDateProvider.overrideWith(
        (ref, request) => Stream.value(prayed),
      ),
    ],
  );
}

Future<DailyPracticeState> _nextData(ProviderContainer container) async {
  final completer = Completer<DailyPracticeState>();
  final subscription = container.listen(dailyPracticeStateProvider, (
    previous,
    next,
  ) {
    if (next case AsyncData(:final value)) {
      if (!completer.isCompleted) completer.complete(value);
    } else if (next case AsyncError(:final error, :final stackTrace)) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await completer.future;
  } finally {
    subscription.close();
  }
}

TodayPrayer _today({
  bool includeAction = true,
  bool actionCompleted = false,
  DateTime? localDate,
}) {
  return TodayPrayer(
    prayer: const PrayerDisplayValue(
      reference: PrayerReference.library('library-1'),
      title: 'For this day',
      body: 'Father, keep me near you today. Amen.',
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.daily,
      action: 'Help one person quietly.',
      helpfulCount: 0,
      viewerMarkedHelpful: false,
    ),
    localDate: localDate ?? DateTime(2026, 8, 13),
    includeAction: includeAction,
    actionCompleted: actionCompleted,
  );
}

DailyMemory _memory(DailyMemoryStatus status, {DateTime? localDate}) {
  return DailyMemory(
    occurrenceId: 'occurrence-1',
    localDate: localDate ?? DateTime(2026, 8, 13),
    memory: Encounter(
      id: 'encounter-1',
      ownerId: 'owner-1',
      title: 'God provided',
      body: 'A remembered deed of the Lord.',
      occurredOn: '2026-08-01',
      isAltar: true,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      currentRevisionId: 'revision-1',
      syncState: EncounterSyncState.synced,
    ),
    status: status,
  );
}
