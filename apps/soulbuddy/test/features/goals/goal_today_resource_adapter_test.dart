import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/goals/application/goal_today_composer.dart';
import 'package:soulbuddy/features/goals/application/goal_today_resource_adapter.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/goals/domain/goal_link.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reminder.dart';
import 'package:soulbuddy/features/prayers/domain/today_prayer.dart';

void main() {
  const adapter = GoalTodayResourceAdapter();
  const composer = GoalTodayComposer();

  test('projects linked prayer titles and Scripture with typed handles', () {
    final personal = _personalPrayerLink('personal-link', 'goal-1', 'prayer-1');
    final library = _libraryPrayerLink('library-link', 'goal-1', 'library-1');
    final scripture = _scriptureLink(
      'scripture-link',
      'goal-1',
      book: 'James',
      chapter: 1,
      firstVerse: 5,
      lastVerse: 6,
    );

    final projection = adapter.project(
      activeGoalLinks: [personal, library, scripture],
      duePrayerOccurrences: const [],
      prayerTitles: const {
        PrayerReference.personal('prayer-1'): 'My evening prayer',
        PrayerReference.library('library-1'): 'Prayer for wisdom',
      },
    );

    expect(projection.candidates, hasLength(3));
    expect(projection.candidates.map((candidate) => candidate.kind), [
      GoalTodayResourceKind.prayer,
      GoalTodayResourceKind.prayer,
      GoalTodayResourceKind.scripture,
    ]);
    expect(projection.candidates.map((candidate) => candidate.label), [
      'My evening prayer',
      'Prayer for wisdom',
      'James 1:5-6',
    ]);
    expect(
      projection.handlesByStableKey.values
          .whereType<GoalTodayLinkedPrayerHandle>(),
      hasLength(2),
    );
    expect(
      projection.handlesByStableKey.values
          .whereType<GoalTodayScriptureHandle>(),
      hasLength(1),
    );
  });

  test('missing prayer title stays visible with neutral fallback', () {
    final projection = adapter.project(
      activeGoalLinks: [
        _personalPrayerLink('link-1', 'goal-1', 'prayer-1'),
      ],
      duePrayerOccurrences: const [],
    );

    expect(projection.candidates, hasLength(1));
    expect(projection.candidates.single.label, 'Prayer');
  });

  test('due reminder replaces generic copy of its linked personal prayer', () {
    final link = _personalPrayerLink('link-1', 'goal-1', 'prayer-1');
    final reminder = _dueReminder('prayer-1');
    final projection = adapter.project(
      activeGoalLinks: [link],
      duePrayerOccurrences: [reminder],
      prayerTitles: const {
        PrayerReference.personal('prayer-1'): 'Saved prayer title',
      },
    );

    final sections = composer.compose(
      goals: [_goal('goal-1')],
      dueActions: const [],
      resources: projection.candidates,
    );

    expect(sections, hasLength(1));
    expect(sections.single.items, hasLength(1));
    final selected = sections.single.items.single as GoalTodayResourceItem;
    expect(selected.resource.kind, GoalTodayResourceKind.reminder);
    expect(selected.resource.label, 'Morning prayer');
    expect(projection.handleFor(selected), isA<GoalTodayReminderHandle>());
    expect(
      (projection.handleFor(selected)! as GoalTodayReminderHandle)
          .occurrence
          .prayerRevisionId,
      'revision-1',
    );
    expect(projection.dueRemindersOutsideActiveGoals, isEmpty);
  });

  test(
    'linked legacy Today prayer wins its generic copy and keeps payload',
    () {
      final link = _libraryPrayerLink('link-1', 'goal-1', 'library-1');
      final today = _legacyToday(const PrayerReference.library('library-1'));
      final projection = adapter.project(
        activeGoalLinks: [link],
        duePrayerOccurrences: const [],
        prayerTitles: const {
          PrayerReference.library('library-1'): 'Generic saved title',
        },
        legacyToday: today,
      );

      final selected =
          composer
                  .compose(
                    goals: [_goal('goal-1')],
                    dueActions: const [],
                    resources: projection.candidates,
                  )
                  .single
                  .items
                  .single
              as GoalTodayResourceItem;

      final handle = projection.handleFor(selected);
      expect(selected.resource.label, 'Prayer for today');
      expect(handle, isA<GoalTodayLegacyPrayerHandle>());
      expect((handle! as GoalTodayLegacyPrayerHandle).today, same(today));
      expect(projection.legacyTodayOutsideActiveGoals, isNull);
    },
  );

  test('legacy Today outside active Goal links remains explicit', () {
    final today = _legacyToday(const PrayerReference.library('library-1'));
    final projection = adapter.project(
      activeGoalLinks: [
        _libraryPrayerLink('other-link', 'goal-1', 'different-prayer'),
      ],
      duePrayerOccurrences: const [],
      legacyToday: today,
    );

    expect(projection.legacyTodayOutsideActiveGoals, same(today));
    expect(
      projection.candidates.where(
        (candidate) => candidate.dedupeKey == 'prayer:library:library-1',
      ),
      isEmpty,
    );
  });

  test('due reminder outside active Goal links remains explicit', () {
    final reminder = _dueReminder('prayer-1');
    final projection = adapter.project(
      activeGoalLinks: [
        _personalPrayerLink('other-link', 'goal-1', 'different-prayer'),
      ],
      duePrayerOccurrences: [reminder],
    );

    expect(projection.dueRemindersOutsideActiveGoals, [same(reminder)]);
    expect(
      projection.candidates.where(
        (candidate) => candidate.kind == GoalTodayResourceKind.reminder,
      ),
      isEmpty,
    );
  });

  test(
    'unscheduled due reminder is ignored instead of reading occurrenceKey',
    () {
      final link = _personalPrayerLink('link-1', 'goal-1', 'prayer-1');
      final projection = adapter.project(
        activeGoalLinks: [link],
        duePrayerOccurrences: [_dueReminder('prayer-1', scheduled: false)],
      );

      expect(
        projection.candidates.where(
          (candidate) => candidate.kind == GoalTodayResourceKind.reminder,
        ),
        isEmpty,
      );
      expect(
        projection.candidates.where(
          (candidate) => candidate.kind == GoalTodayResourceKind.prayer,
        ),
        hasLength(1),
      );
      expect(projection.dueRemindersOutsideActiveGoals, isEmpty);
    },
  );
}

Goal _goal(String id) => Goal(
  id: id,
  ownerId: 'owner-1',
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-$id',
  position: 0,
  title: 'Goal $id',
  createdAt: DateTime.utc(2026, 8, 28, 8),
  updatedAt: DateTime.utc(2026, 8, 28, 8),
);

GoalLink _personalPrayerLink(String id, String goalId, String prayerId) =>
    GoalLink(
      id: id,
      goalId: goalId,
      ownerId: 'owner-1',
      type: GoalLinkType.personalPrayer,
      role: GoalLinkRole.primaryPrayer,
      personalPrayerId: prayerId,
      createdAt: DateTime.utc(2026, 8, 28, 8),
    );

GoalLink _libraryPrayerLink(String id, String goalId, String prayerId) =>
    GoalLink(
      id: id,
      goalId: goalId,
      ownerId: 'owner-1',
      type: GoalLinkType.libraryPrayer,
      role: GoalLinkRole.primaryPrayer,
      libraryPrayerId: prayerId,
      createdAt: DateTime.utc(2026, 8, 28, 8),
    );

GoalLink _scriptureLink(
  String id,
  String goalId, {
  required String book,
  required int chapter,
  required int firstVerse,
  required int lastVerse,
}) => GoalLink(
  id: id,
  goalId: goalId,
  ownerId: 'owner-1',
  type: GoalLinkType.scripture,
  role: GoalLinkRole.reference,
  translation: 'RSVCE',
  book: book,
  chapter: chapter,
  firstVerse: firstVerse,
  lastVerse: lastVerse,
  createdAt: DateTime.utc(2026, 8, 28, 8),
);

DuePrayerOccurrence _dueReminder(String prayerId, {bool scheduled = true}) {
  final occurrenceAt = scheduled ? DateTime.utc(2026, 8, 28, 8) : null;
  final schedule = PrayerReminderSchedule.daily(
    localTime: PrayerLocalTime(hour: 9, minute: 0),
    timezone: 'Africa/Lagos',
  );
  return DuePrayerOccurrence(
    reminder: PrayerReminder(
      id: 'reminder-1',
      ownerId: 'owner-1',
      personalPrayerId: prayerId,
      schedule: schedule,
      enabled: true,
      createdAt: DateTime.utc(2026, 8, 27),
      updatedAt: DateTime.utc(2026, 8, 28),
    ),
    device: PrayerReminderDevice(
      id: 'device-row-1',
      reminderId: 'reminder-1',
      deviceId: 'device-1',
      enabledOnDevice: true,
      nextOccurrenceAt: occurrenceAt,
      platformNotificationId: 1,
      updatedAt: DateTime.utc(2026, 8, 28),
    ),
    prayerTitle: 'Morning prayer',
    prayerBody: 'Lord, guide me.',
    prayerRevisionId: 'revision-1',
    occurrenceAt: occurrenceAt,
  );
}

TodayPrayer _legacyToday(PrayerReference reference) => TodayPrayer(
  prayer: PrayerDisplayValue(
    reference: reference,
    title: 'Prayer for today',
    body: 'Lord, guide me.',
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.guidance,
  ),
  localDate: DateTime(2026, 8, 28),
  includeAction: false,
  actionCompleted: false,
);
