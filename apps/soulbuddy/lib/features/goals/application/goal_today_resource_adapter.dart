import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../../prayers/domain/today_prayer.dart';
import '../domain/goal_action.dart';
import '../domain/goal_link.dart';
import 'goal_today_composer.dart';

class GoalTodayResourceProjection {
  const GoalTodayResourceProjection({
    required this.candidates,
    required this.handlesByStableKey,
    this.dueRemindersOutsideActiveGoals = const [],
    this.legacyTodayOutsideActiveGoals,
  });

  final List<GoalTodayResourceCandidate> candidates;
  final Map<String, GoalTodayResourceHandle> handlesByStableKey;
  final List<DuePrayerOccurrence> dueRemindersOutsideActiveGoals;
  final TodayPrayer? legacyTodayOutsideActiveGoals;

  GoalTodayResourceHandle? handleFor(GoalTodayResourceItem item) =>
      handlesByStableKey[item.resource.stableKey];
}

sealed class GoalTodayResourceHandle {
  const GoalTodayResourceHandle(this.link);

  final GoalLink link;
}

final class GoalTodayLinkedPrayerHandle extends GoalTodayResourceHandle {
  const GoalTodayLinkedPrayerHandle(super.link, this.prayer);

  final PrayerReference prayer;
}

final class GoalTodayScriptureHandle extends GoalTodayResourceHandle {
  const GoalTodayScriptureHandle(super.link);
}

final class GoalTodayReminderHandle extends GoalTodayResourceHandle {
  const GoalTodayReminderHandle(super.link, this.occurrence);

  final DuePrayerOccurrence occurrence;
}

final class GoalTodayLegacyPrayerHandle extends GoalTodayResourceHandle {
  const GoalTodayLegacyPrayerHandle(super.link, this.today);

  final TodayPrayer today;
}

class GoalTodayResourceAdapter {
  const GoalTodayResourceAdapter();

  GoalTodayResourceProjection project({
    required List<GoalLink> activeGoalLinks,
    required List<DuePrayerOccurrence> duePrayerOccurrences,
    Map<PrayerReference, String> prayerTitles = const {},
    TodayPrayer? legacyToday,
  }) {
    final links = activeGoalLinks
        .where((link) => link.archivedAt == null)
        .toList(growable: false);
    final candidates = <GoalTodayResourceCandidate>[];
    final handles = <String, GoalTodayResourceHandle>{};
    final dueOutsideActiveGoals = <DuePrayerOccurrence>[];

    void add(
      GoalTodayResourceCandidate candidate,
      GoalTodayResourceHandle handle,
    ) {
      candidates.add(candidate);
      handles[candidate.stableKey] = handle;
    }

    // Due reminders are added before their generic prayer resources. The
    // composer gives reminders a higher explicit rank, while the shared prayer
    // dedupe key guarantees one visible representation per Goal. Reminders that
    // are not yet linked to an active Goal remain explicit migration content.
    for (final occurrence in duePrayerOccurrences) {
      final occurrenceAt = occurrence.occurrenceAt;
      if (occurrenceAt == null) continue;
      final prayer = PrayerReference.personal(
        occurrence.reminder.personalPrayerId,
      );
      final matchingLinks = links
          .where((link) => _matchesPrayer(link, prayer))
          .toList(growable: false);
      if (matchingLinks.isEmpty) {
        dueOutsideActiveGoals.add(occurrence);
        continue;
      }
      for (final link in matchingLinks) {
        final stableKey = '${link.goalId}:reminder:${occurrence.occurrenceKey}';
        add(
          GoalTodayResourceCandidate(
            goalId: link.goalId,
            stableKey: stableKey,
            dedupeKey: _prayerDedupeKey(prayer),
            kind: GoalTodayResourceKind.reminder,
            label: _nonEmptyLabel(occurrence.prayerTitle, fallback: 'Prayer'),
            dueAt: occurrenceAt,
          ),
          GoalTodayReminderHandle(link, occurrence),
        );
      }
    }

    TodayPrayer? legacyOutsideActiveGoals;
    if (legacyToday != null) {
      final prayer = legacyToday.prayer.reference;
      final matchingLinks = links
          .where((link) => _matchesPrayer(link, prayer))
          .toList(growable: false);
      if (matchingLinks.isEmpty) {
        legacyOutsideActiveGoals = legacyToday;
      } else {
        for (final link in matchingLinks) {
          final stableKey =
              '${link.goalId}:legacy-today:${goalLocalDateKey(legacyToday.localDate)}:'
              '${prayer.source.name}:${prayer.id}';
          add(
            GoalTodayResourceCandidate(
              goalId: link.goalId,
              stableKey: stableKey,
              dedupeKey: _prayerDedupeKey(prayer),
              kind: GoalTodayResourceKind.prayer,
              label: _nonEmptyLabel(
                legacyToday.prayer.title,
                fallback: 'Prayer',
              ),
            ),
            GoalTodayLegacyPrayerHandle(link, legacyToday),
          );
        }
      }
    }

    // Generic links come last so an existing Today selection wins within the
    // same prayer tier, while a due reminder still wins through explicit rank.
    // Titles are optional display metadata: an unavailable title must never
    // hide an otherwise valid linked prayer from an offline Goal.
    for (final link in links) {
      final prayer = _prayerReference(link);
      if (prayer != null) {
        final stableKey =
            '${link.goalId}:prayer:${prayer.source.name}:${prayer.id}';
        add(
          GoalTodayResourceCandidate(
            goalId: link.goalId,
            stableKey: stableKey,
            dedupeKey: _prayerDedupeKey(prayer),
            kind: GoalTodayResourceKind.prayer,
            label: _nonEmptyLabel(
              prayerTitles[prayer] ?? '',
              fallback: 'Prayer',
            ),
          ),
          GoalTodayLinkedPrayerHandle(link, prayer),
        );
        continue;
      }

      if (link.type != GoalLinkType.scripture || !_validScripture(link)) {
        continue;
      }
      final stableKey = '${link.goalId}:scripture:${link.id}';
      add(
        GoalTodayResourceCandidate(
          goalId: link.goalId,
          stableKey: stableKey,
          dedupeKey: _scriptureDedupeKey(link),
          kind: GoalTodayResourceKind.scripture,
          label: _scriptureLabel(link),
        ),
        GoalTodayScriptureHandle(link),
      );
    }

    return GoalTodayResourceProjection(
      candidates: List.unmodifiable(candidates),
      handlesByStableKey: Map.unmodifiable(handles),
      dueRemindersOutsideActiveGoals: List.unmodifiable(dueOutsideActiveGoals),
      legacyTodayOutsideActiveGoals: legacyOutsideActiveGoals,
    );
  }
}

PrayerReference? _prayerReference(GoalLink link) => switch (link.type) {
  GoalLinkType.personalPrayer when link.personalPrayerId != null =>
    PrayerReference.personal(link.personalPrayerId!),
  GoalLinkType.libraryPrayer when link.libraryPrayerId != null =>
    PrayerReference.library(link.libraryPrayerId!),
  _ => null,
};

bool _matchesPrayer(GoalLink link, PrayerReference prayer) =>
    _prayerReference(link) == prayer;

String _prayerDedupeKey(PrayerReference prayer) =>
    'prayer:${prayer.source.name}:${prayer.id}';

bool _validScripture(GoalLink link) =>
    link.translation != null &&
    link.translation!.trim().isNotEmpty &&
    link.book != null &&
    link.book!.trim().isNotEmpty &&
    link.chapter != null &&
    link.chapter! > 0 &&
    link.firstVerse != null &&
    link.firstVerse! > 0 &&
    link.lastVerse != null &&
    link.lastVerse! >= link.firstVerse!;

String _scriptureDedupeKey(GoalLink link) =>
    'scripture:${link.translation!.trim()}:${link.book!.trim()}:'
    '${link.chapter}:${link.firstVerse}:${link.lastVerse}';

String _scriptureLabel(GoalLink link) {
  final verse = link.firstVerse == link.lastVerse
      ? '${link.firstVerse}'
      : '${link.firstVerse}-${link.lastVerse}';
  return '${link.book!.trim()} ${link.chapter}:$verse';
}

String _nonEmptyLabel(String value, {required String fallback}) {
  final normalized = value.trim();
  return normalized.isEmpty ? fallback : normalized;
}
