import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_generation_request.dart';
import '../application/goal_onboarding_flow.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';
import '../domain/goal_link.dart';
import '../domain/goal_onboarding_progress.dart';
import 'goal_onboarding_finalizer.dart';

class PowerSyncGoalOnboardingFinalizer implements GoalOnboardingFinalizer {
  PowerSyncGoalOnboardingFinalizer({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Future<GoalOnboardingFinalizationResult> finalize(
    GoalOnboardingProgress progress,
  ) async {
    final checked = GoalOnboardingFlow.beginSaving(progress);
    final starterKey = checked.starterKey;
    if (starterKey == null) {
      throw StateError('A Goal starter is required before saving.');
    }
    final title = _requiredText(checked.title, 'title', 120);
    final situation = _optionalText(
      checked.currentSituation,
      'currentSituation',
      4000,
    );
    final todayAction = _optionalText(checked.todayAction, 'todayAction', 1000);
    final guardNote = _optionalText(checked.guardNote, 'guardNote', 1000);
    final mode = GoalOnboardingFlow.inferredMode(checked);
    final prayerSource = checked.prayerSource!;
    final normalizedOwnerId = _requiredText(ownerId, 'ownerId', 120);
    final normalizedDeviceId = _requiredText(deviceId, 'deviceId', 120);
    final now = _now();
    final timestamp = now.toUtc().toIso8601String();
    final goalId = _uuid.v7();
    final goalRevisionId = _uuid.v7();

    String? createdPersonalPrayerId;

    // Goal creation, user-authored prayer creation, linking, Today actions and
    // progress cleanup are one local transaction. A retry after interruption
    // therefore cannot observe or duplicate a half-created first Goal.
    await database.writeTransaction((transaction) async {
      Future<void> insertTodayAction(
        String body,
        GoalActionKind kind,
      ) async {
        await transaction.execute(
          '''
          INSERT INTO goal_actions(
            id, goal_id, owner_id, body, action_kind, schedule_type,
            local_time, timezone, once_at, weekdays_mask, enabled,
            created_at, updated_at, archived_at
          ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?, NULL, 1, ?, ?, NULL)
          ''',
          [
            _uuid.v7(),
            goalId,
            normalizedOwnerId,
            body,
            kind.wireValue,
            GoalScheduleType.today.wireValue,
            now.toUtc().toIso8601String(),
            timestamp,
            timestamp,
          ],
        );
      }

      String? personalPrayerId;
      String? libraryPrayerId;
      String? translation;
      String? book;
      int? chapter;
      int? firstVerse;
      int? lastVerse;
      late final GoalLinkType linkType;
      late final GoalLinkRole linkRole;

      switch (prayerSource) {
        case GoalOnboardingPrayerSource.ownWords:
          final body = _requiredText(
            checked.ownPrayerText,
            'ownPrayerText',
            4000,
          );
          personalPrayerId = _uuid.v7();
          final prayerRevisionId = _uuid.v7();
          createdPersonalPrayerId = personalPrayerId;
          await transaction.execute(
            '''
            INSERT INTO personal_prayers(
              id, owner_id, title, style, reach, grounding, purpose,
              current_revision_id, created_at, updated_at, archived_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
            ''',
            [
              personalPrayerId,
              normalizedOwnerId,
              title,
              PrayerStyle.situational.wireValue,
              PrayerReach.personal.wireValue,
              PrayerGrounding.generalChristian.wireValue,
              _purposeFor(starterKey).wireValue,
              prayerRevisionId,
              timestamp,
              timestamp,
            ],
          );
          await transaction.execute(
            '''
            INSERT INTO personal_prayer_revisions(
              id, prayer_id, owner_id, body, action, created_at, device_id
            ) VALUES (?, ?, ?, ?, NULL, ?, ?)
            ''',
            [
              prayerRevisionId,
              personalPrayerId,
              normalizedOwnerId,
              body,
              timestamp,
              normalizedDeviceId,
            ],
          );
          linkType = GoalLinkType.personalPrayer;
          linkRole = GoalLinkRole.primaryPrayer;
          break;
        case GoalOnboardingPrayerSource.personalPrayer:
          personalPrayerId = _requiredText(
            checked.prayerResourceId,
            'prayerResourceId',
            120,
          );
          final prayer = await transaction.getOptional(
            '''
            SELECT id FROM personal_prayers
            WHERE id = ? AND owner_id = ? AND archived_at IS NULL
            LIMIT 1
            ''',
            [personalPrayerId, normalizedOwnerId],
          );
          if (prayer == null) throw StateError('Prayer is not available.');
          linkType = GoalLinkType.personalPrayer;
          linkRole = GoalLinkRole.primaryPrayer;
          break;
        case GoalOnboardingPrayerSource.libraryPrayer:
          libraryPrayerId = _requiredText(
            checked.prayerResourceId,
            'prayerResourceId',
            120,
          );
          final remote = await transaction.getOptional(
            '''
            SELECT id FROM library_prayers
            WHERE id = ? AND archived_at IS NULL
            LIMIT 1
            ''',
            [libraryPrayerId],
          );
          final bundled = remote ??
              await transaction.getOptional(
                '''
                SELECT id FROM bundled_prayers
                WHERE id = ? AND archived_at IS NULL
                LIMIT 1
                ''',
                [libraryPrayerId],
              );
          if (bundled == null) throw StateError('Prayer is not available.');
          linkType = GoalLinkType.libraryPrayer;
          linkRole = GoalLinkRole.primaryPrayer;
          break;
        case GoalOnboardingPrayerSource.scripture:
          translation = _requiredText(
            checked.scriptureTranslation,
            'scriptureTranslation',
            20,
          );
          book = _requiredText(checked.scriptureBook, 'scriptureBook', 80);
          chapter = _positive(checked.scriptureChapter, 'scriptureChapter');
          firstVerse = _positive(
            checked.scriptureFirstVerse,
            'scriptureFirstVerse',
          );
          lastVerse = _positive(
            checked.scriptureLastVerse,
            'scriptureLastVerse',
          );
          if (lastVerse < firstVerse || lastVerse - firstVerse + 1 > 20) {
            throw ArgumentError.value(
              lastVerse,
              'scriptureLastVerse',
              'must define 1-20 consecutive verses',
            );
          }
          linkType = GoalLinkType.scripture;
          linkRole = GoalLinkRole.reference;
          break;
      }

      final maximumRow = await transaction.getOptional(
        'SELECT MAX(position) AS maximum FROM goals '
        'WHERE owner_id = ? AND archived_at IS NULL',
        [normalizedOwnerId],
      );
      final position = ((maximumRow?['maximum'] as num?)?.toInt() ?? -1) + 1;
      await transaction.execute(
        '''
        INSERT INTO goals(
          id, owner_id, starter_key, mode, status, current_revision_id,
          position, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          goalId,
          normalizedOwnerId,
          starterKey.wireValue,
          mode.wireValue,
          GoalStatus.active.wireValue,
          goalRevisionId,
          position,
          timestamp,
          timestamp,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO goal_revisions(
          id, goal_id, owner_id, title, current_situation, why_it_matters,
          created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
        ''',
        [
          goalRevisionId,
          goalId,
          normalizedOwnerId,
          title,
          situation,
          timestamp,
          normalizedDeviceId,
        ],
      );

      await transaction.execute(
        '''
        INSERT INTO goal_links(
          id, goal_id, owner_id, link_type, personal_prayer_id,
          library_prayer_id, encounter_id, voice_tablet_id, circle_id,
          translation, book, chapter, first_verse, last_verse, role,
          created_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          _uuid.v7(),
          goalId,
          normalizedOwnerId,
          linkType.wireValue,
          personalPrayerId,
          libraryPrayerId,
          translation,
          book,
          chapter,
          firstVerse,
          lastVerse,
          linkRole.wireValue,
          timestamp,
        ],
      );

      if (todayAction != null) {
        await insertTodayAction(todayAction, GoalActionKind.nextStep);
      }
      if (guardNote != null) {
        await insertTodayAction(guardNote, GoalActionKind.guard);
      }

      await transaction.execute(
        'DELETE FROM goal_onboarding_progress WHERE id = ?',
        ['current'],
      );
    });

    return GoalOnboardingFinalizationResult(
      goalId: goalId,
      createdPersonalPrayerId: createdPersonalPrayerId,
    );
  }
}

PrayerPurpose _purposeFor(GoalStarterKey starterKey) => switch (starterKey) {
  GoalStarterKey.direction => PrayerPurpose.guidance,
  GoalStarterKey.difficultTime => PrayerPurpose.difficultTime,
  GoalStarterKey.closerToGod ||
  GoalStarterKey.stopControl ||
  GoalStarterKey.other => PrayerPurpose.daily,
};

String _requiredText(String? value, String name, int maximum) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must contain 1-$maximum characters',
    );
  }
  return normalized;
}

String? _optionalText(String? value, String name, int maximum) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.runes.length > maximum) {
    throw ArgumentError.value(value, name, 'must not exceed $maximum characters');
  }
  return normalized;
}

int _positive(int? value, String name) {
  if (value == null || value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
  return value;
}
