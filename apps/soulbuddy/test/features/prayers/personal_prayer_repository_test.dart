import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_personal_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
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
      await database.powersync.getAll('SELECT id FROM prayer_generation_requests'),
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
    'accepts one draft as prayer revision and explicit links atomically',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/accept.db',
      );
      addTearDown(database.close);
      final generationRepository = PowerSyncPrayerGenerationRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime.utc(2026, 8, 11, 8),
        uuid: const Uuid(),
      );
      final request = await generationRepository.create(
        style: PrayerStyle.situational,
        reach: PrayerReach.encompassing,
        grounding: PrayerGrounding.generalChristian,
        purpose: PrayerPurpose.family,
        requestText: 'Give us wisdom as we care for our family.',
      );
      await generationRepository.replaceContexts(request.id, const [
        PrayerGenerationContext.encounter(
          sourceId: '0198a400-0000-7000-8000-000000000001',
          displayLabel: 'A conversation I remember',
          excerptSnapshot: 'We chose to speak truthfully and forgive.',
        ),
      ]);
      await generationRepository.queue(
        request.id,
        provider: 'deepseek',
        disclosureVersion: '2026-08-11',
      );
      await generationRepository.claim(
        request.id,
        'attempt-1',
        DateTime.utc(2026, 8, 11, 8),
      );
      await generationRepository.storeDraft(
        request.id,
        'attempt-1',
        const PrayerGeneratedDraft(
          title: 'For wisdom in my family',
          body:
              'Father, give us wisdom and make us ready to act in love. Amen.',
          action: 'Call and listen without defending myself.',
          promptVersion: 'prayer-v1',
        ),
      );
      final repository = PowerSyncPersonalPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        deviceId: 'device-1',
        now: () => DateTime.utc(2026, 8, 11, 8, 1),
        uuid: const Uuid(),
      );

      final accepted = await repository.accept(
        requestId: request.id,
        title: 'For wisdom in my family',
        body: 'Father, give us wisdom and make us ready to act in love. Amen.',
        action: 'Call and listen without defending myself.',
      );
      final replayed = await repository.accept(
        requestId: request.id,
        title: 'For wisdom in my family',
        body: 'Father, give us wisdom and make us ready to act in love. Amen.',
        action: 'Call and listen without defending myself.',
      );

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
      expect(
        (await generationRepository.watch(request.id).first)?.status,
        PrayerGenerationStatus.ready,
      );
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
