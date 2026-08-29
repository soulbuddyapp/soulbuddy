import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-personal-prayers-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('creates user-authored prayer without a generation request', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/own-words.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPersonalPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 28, 4),
      uuid: const Uuid(),
    );

    final prayer = await repository.createOwnWords(
      title: 'Find direction',
      body: 'Father, give me wisdom for the next faithful step.',
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.guidance,
    );

    expect(prayer.body, 'Father, give me wisdom for the next faithful step.');
    expect(prayer.purpose, PrayerPurpose.guidance);
    expect(prayer.style, PrayerStyle.situational.wireValue);
    expect(prayer.reach, PrayerReach.personal.wireValue);
    expect(
      await database.powersync.getAll(
        'SELECT id FROM prayer_generation_requests',
      ),
      isEmpty,
    );
    final rows = await database.powersync.getAll(
      'SELECT id, current_revision_id FROM personal_prayers',
    );
    final revisions = await database.powersync.getAll(
      'SELECT id, prayer_id, body FROM personal_prayer_revisions',
    );
    expect(rows, hasLength(1));
    expect(revisions, hasLength(1));
    expect(rows.single['current_revision_id'], revisions.single['id']);
    expect(revisions.single['prayer_id'], rows.single['id']);
    expect(revisions.single['body'], prayer.body);
  });

  test(
    'accepts historical draft idempotently without mutating legacy archive',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/accept.db',
      );
      addTearDown(database.close);
      const requestId = '0198a400-0000-7000-8000-000000000010';
      const createdAt = '2026-08-11T08:00:00.000Z';
      await database.powersync.execute(
        '''
        INSERT INTO prayer_generation_requests(
          id, owner_id, style, reach, grounding, purpose, request_text,
          status, draft_title, draft_body, draft_action, attempt_count,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          requestId,
          'owner-1',
          'situational',
          'encompassing',
          'general_christian',
          'family',
          'Give us wisdom as we care for our family.',
          'ready',
          'For wisdom in my family',
          'Father, give us wisdom and make us ready to act in love. Amen.',
          'Call and listen without defending myself.',
          1,
          createdAt,
          createdAt,
        ],
      );
      await database.powersync.execute(
        '''
        INSERT INTO prayer_generation_contexts(
          id, request_id, context_type, source_id, display_label,
          excerpt_snapshot, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          '0198a400-0000-7000-8000-000000000011',
          requestId,
          'encounter',
          '0198a400-0000-7000-8000-000000000001',
          'A conversation I remember',
          'We chose to speak truthfully and forgive.',
          createdAt,
        ],
      );
      final repository = PowerSyncPersonalPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 11, 8, 1),
        uuid: const Uuid(),
      );

      final accepted = await repository.accept(
        requestId: requestId,
        title: 'For wisdom in my family',
        body: 'Father, give us wisdom and make us ready to act in love. Amen.',
        action: 'Call and listen without defending myself.',
      );
      final replayed = await repository.accept(
        requestId: requestId,
        title: 'For wisdom in my family',
        body: 'Father, give us wisdom and make us ready to act in love. Amen.',
        action: 'Call and listen without defending myself.',
      );

      expect(accepted.id, requestId);
      expect(accepted.currentRevisionId, isNotEmpty);
      expect(replayed.id, accepted.id);
      expect(
        await database.powersync.getAll('SELECT * FROM personal_prayers'),
        hasLength(1),
      );
      expect(
        await database.powersync.getAll(
          'SELECT * FROM personal_prayer_revisions',
        ),
        hasLength(1),
      );
      final links = await database.powersync.getAll(
        'SELECT * FROM personal_prayer_links',
      );
      expect(links, hasLength(1));
      expect(
        links.single['encounter_id'],
        '0198a400-0000-7000-8000-000000000001',
      );
      expect(links.single['excerpt_snapshot'], isNull);
      final legacy = await database.powersync.get(
        '''
        SELECT accepted_prayer_id, updated_at
        FROM prayer_generation_requests
        WHERE id = ?
        ''',
        [requestId],
      );
      expect(legacy['accepted_prayer_id'], isNull);
      expect(legacy['updated_at'], createdAt);
    },
  );

  test(
    'Today reads a personal current revision without library voting',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/today.db',
      );
      addTearDown(database.close);
      await database.powersync.execute(
        '''
      INSERT INTO personal_prayers(
        id, owner_id, title, style, reach, grounding, purpose,
        current_revision_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
        [
          '0198a800-0000-7000-8000-000000000001',
          'owner-1',
          'My accepted prayer',
          'daily',
          'personal',
          'general_christian',
          'daily',
          '0198a800-0000-7000-8000-000000000002',
          '2026-08-11T08:00:00.000Z',
          '2026-08-11T08:00:00.000Z',
        ],
      );
      await database.powersync.execute(
        '''
      INSERT INTO personal_prayer_revisions(
        id, prayer_id, owner_id, body, action, created_at, device_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          '0198a800-0000-7000-8000-000000000002',
          '0198a800-0000-7000-8000-000000000001',
          'owner-1',
          'Father, guide me today. Amen.',
          'Listen before answering.',
          '2026-08-11T08:00:00.000Z',
          'device-1',
        ],
      );
      final todayRepository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime(2026, 8, 11, 8),
        uuid: const Uuid(),
      );
      const reference = PrayerReference.personal(
        '0198a800-0000-7000-8000-000000000001',
      );

      await todayRepository.selectForToday(reference, includeAction: true);
      final today = await todayRepository
          .watchToday(DateTime(2026, 8, 11))
          .first;

      expect(today?.prayer.reference, reference);
      expect(today?.prayer.title, 'My accepted prayer');
      expect(today?.prayer.viewerMarkedHelpful, isFalse);
      expect(
        await database.powersync.getAll('SELECT id FROM prayer_votes'),
        isEmpty,
      );
    },
  );
}
