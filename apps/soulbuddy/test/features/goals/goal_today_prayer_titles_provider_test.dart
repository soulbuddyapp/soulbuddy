import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/database/app_database_provider.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';
import 'package:soulbuddy/core/identity/local_identity_providers.dart';
import 'package:soulbuddy/features/goals/providers/goal_today_providers.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-goal-prayer-titles-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'projects active Goal prayer titles in one owner-scoped read model',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/titles.db',
      );
      final powersync = database.powersync;
      const ownerId = 'owner-1';
      const timestamp = '2026-08-29T06:30:00.000Z';

      Future<void> insertGoal(
        String id, {
        String status = 'active',
        int position = 0,
      }) => powersync.execute(
        '''
        INSERT INTO goals(
          id, owner_id, starter_key, mode, status, current_revision_id,
          position, created_at, updated_at, archived_at
        ) VALUES (?, ?, NULL, 'mixed', ?, ?, ?, ?, ?, NULL)
        ''',
        [id, ownerId, status, 'revision-$id', position, timestamp, timestamp],
      );

      await insertGoal('goal-active');
      await insertGoal('goal-paused', status: 'paused', position: 1);

      await powersync.execute(
        '''
        INSERT INTO personal_prayers(
          id, owner_id, title, style, reach, grounding, purpose,
          current_revision_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, 'situational', 'personal', 'general_christian',
                  'daily', ?, ?, ?, NULL)
        ''',
        [
          'personal-1',
          ownerId,
          'My evening prayer',
          'revision-personal-1',
          timestamp,
          timestamp,
        ],
      );
      await powersync.execute(
        '''
        INSERT INTO personal_prayers(
          id, owner_id, title, style, reach, grounding, purpose,
          current_revision_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, 'situational', 'personal', 'general_christian',
                  'daily', ?, ?, ?, NULL)
        ''',
        [
          'personal-paused',
          ownerId,
          'Paused Goal prayer',
          'revision-personal-paused',
          timestamp,
          timestamp,
        ],
      );
      await powersync.execute(
        '''
        INSERT INTO personal_prayers(
          id, owner_id, title, style, reach, grounding, purpose,
          current_revision_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, 'situational', 'personal', 'general_christian',
                  'daily', ?, ?, ?, ?)
        ''',
        [
          'personal-archived',
          ownerId,
          'Archived prayer',
          'revision-personal-archived',
          timestamp,
          timestamp,
          timestamp,
        ],
      );

      await powersync.execute(
        '''
        INSERT INTO bundled_prayers(
          id, title, body, grounding, language_style, purpose, action,
          helpful_count, content_version, archived_at
        ) VALUES (?, ?, ?, 'general_christian', 'christian', 'guidance',
                  NULL, 0, 1, NULL)
        ''',
        ['library-bundled', 'Bundled prayer for wisdom', 'Lord, guide me.'],
      );
      await powersync.execute(
        '''
        INSERT INTO bundled_prayers(
          id, title, body, grounding, language_style, purpose, action,
          helpful_count, content_version, archived_at
        ) VALUES (?, ?, ?, 'general_christian', 'christian', 'guidance',
                  NULL, 0, 1, NULL)
        ''',
        ['library-canonical', 'Older bundled title', 'Lord, guide me.'],
      );
      await powersync.execute(
        '''
        INSERT INTO library_prayers(
          id, title, body, grounding, language_style, purpose, action,
          helpful_count, published_at, archived_at
        ) VALUES (?, ?, ?, 'general_christian', 'christian', 'guidance',
                  NULL, 0, ?, NULL)
        ''',
        [
          'library-canonical',
          'Reviewed canonical prayer',
          'Lord, guide me.',
          timestamp,
        ],
      );

      Future<void> link({
        required String id,
        required String goalId,
        required String type,
        String? personalPrayerId,
        String? libraryPrayerId,
      }) => powersync.execute(
        '''
        INSERT INTO goal_links(
          id, goal_id, owner_id, link_type, personal_prayer_id,
          library_prayer_id, encounter_id, voice_tablet_id, circle_id,
          translation, book, chapter, first_verse, last_verse, role,
          created_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL,
                  NULL, NULL, NULL, NULL, NULL, 'primary_prayer', ?, NULL)
        ''',
        [
          id,
          goalId,
          ownerId,
          type,
          personalPrayerId,
          libraryPrayerId,
          timestamp,
        ],
      );

      await link(
        id: 'link-personal',
        goalId: 'goal-active',
        type: 'personal_prayer',
        personalPrayerId: 'personal-1',
      );
      await link(
        id: 'link-bundled',
        goalId: 'goal-active',
        type: 'library_prayer',
        libraryPrayerId: 'library-bundled',
      );
      await link(
        id: 'link-canonical',
        goalId: 'goal-active',
        type: 'library_prayer',
        libraryPrayerId: 'library-canonical',
      );
      await link(
        id: 'link-paused',
        goalId: 'goal-paused',
        type: 'personal_prayer',
        personalPrayerId: 'personal-paused',
      );
      await link(
        id: 'link-archived-prayer',
        goalId: 'goal-active',
        type: 'personal_prayer',
        personalPrayerId: 'personal-archived',
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => database),
          localIdentityProvider.overrideWith(
            (ref) async =>
                const LocalIdentity(ownerId: ownerId, deviceId: 'device-1'),
          ),
        ],
      );
      final subscription = container.listen(
        activeGoalPrayerTitlesProvider,
        (previous, next) {},
        fireImmediately: true,
      );

      try {
        final titles = await container.read(
          activeGoalPrayerTitlesProvider.future,
        );

        expect(titles, {
          const PrayerReference.personal('personal-1'): 'My evening prayer',
          const PrayerReference.library('library-bundled'):
              'Bundled prayer for wisdom',
          const PrayerReference.library('library-canonical'):
              'Reviewed canonical prayer',
        });
        expect(
          titles.containsKey(const PrayerReference.personal('personal-paused')),
          isFalse,
        );
        expect(
          titles.containsKey(
            const PrayerReference.personal('personal-archived'),
          ),
          isFalse,
        );
      } finally {
        subscription.close();
        container.dispose();
        await database.close();
      }
    },
  );
}
