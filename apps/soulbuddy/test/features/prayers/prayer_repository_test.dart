import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-prayers-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('uses stable wire values for prayer grounding and purpose', () {
    expect(PrayerGrounding.values.map((value) => value.wireValue), [
      'general_christian',
      'catholic',
    ]);
    expect(PrayerPurpose.values.map((value) => value.wireValue), [
      'daily',
      'gratitude',
      'guidance',
      'family',
      'healing',
      'work',
      'forgiveness',
      'difficult_time',
    ]);
  });

  test(
    'merges published canonical and bundled prayers with canonical precedence',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
      );

      await _seedBundledPrayer(
        database.powersync,
        id: 'shared',
        title: 'Bundled copy',
        helpfulCount: 99,
      );
      await _seedCanonicalPrayer(
        database.powersync,
        id: 'shared',
        title: 'Canonical copy',
        helpfulCount: 8,
      );
      await _seedCanonicalPrayer(
        database.powersync,
        id: 'lowercase',
        title: 'alpha',
        helpfulCount: 3,
      );
      await _seedBundledPrayer(
        database.powersync,
        id: 'uppercase',
        title: 'Beta',
        helpfulCount: 3,
      );
      await _seedCanonicalPrayer(
        database.powersync,
        id: 'unpublished',
        title: 'Not ready',
        helpfulCount: 100,
        publishedAt: null,
      );
      await _seedBundledPrayer(
        database.powersync,
        id: 'archived',
        title: 'Old copy',
        helpfulCount: 100,
        archivedAt: '2026-08-10T00:00:00.000Z',
      );

      final prayers = await repository.watchLibrary().first;

      expect(prayers.map((prayer) => prayer.id), [
        'shared',
        'lowercase',
        'uppercase',
      ]);
      expect(prayers.first.title, 'Canonical copy');
      expect(
        (await repository.watchPrayer('shared').first)?.title,
        'Canonical copy',
      );
      expect(await repository.watchPrayer('unpublished').first, isNull);
    },
  );

  test('filters the merged library by grounding and purpose', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    await _seedBundledPrayer(
      database.powersync,
      id: 'family',
      title: 'For my family',
      grounding: PrayerGrounding.catholic,
      purpose: PrayerPurpose.family,
    );
    await _seedCanonicalPrayer(
      database.powersync,
      id: 'work',
      title: 'Before work',
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.work,
    );

    final prayers = await repository
        .watchLibrary(
          grounding: PrayerGrounding.catholic,
          purpose: PrayerPurpose.family,
        )
        .first;

    expect(prayers.map((prayer) => prayer.title), ['For my family']);
  });

  test('toggles the viewer vote using one deterministic UUIDv5 row', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      now: () => DateTime.utc(2026, 8, 11, 12),
    );
    await _seedBundledPrayer(
      database.powersync,
      id: 'prayer-1',
      title: 'For today',
      helpfulCount: 4,
    );

    await repository.setHelpful('prayer-1', value: true);
    final marked = await repository.watchPrayer('prayer-1').first;
    final firstRows = await database.powersync.getAll(
      'SELECT id, owner_id, prayer_id FROM prayer_votes',
    );
    await repository.setHelpful('prayer-1', value: true);
    final secondRows = await database.powersync.getAll(
      'SELECT id FROM prayer_votes',
    );

    expect(marked?.viewerMarkedHelpful, isTrue);
    expect(marked?.helpfulCount, 4);
    expect(firstRows, hasLength(1));
    expect(firstRows.single['owner_id'], 'owner-1');
    expect(firstRows.single['prayer_id'], 'prayer-1');
    expect(
      firstRows.single['id'],
      matches(RegExp(r'^[0-9a-f-]{14}5[0-9a-f-]+$')),
    );
    expect(secondRows.single['id'], firstRows.single['id']);

    await repository.setHelpful('prayer-1', value: false);

    expect(
      (await repository.watchPrayer('prayer-1').first)?.viewerMarkedHelpful,
      isFalse,
    );
    expect(
      await database.powersync.getAll('SELECT id FROM prayer_votes'),
      isEmpty,
    );
  });

  test(
    'selects a prayer and completes its optional action for Today',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime(2026, 8, 11, 0, 30),
      );
      await _seedBundledPrayer(
        database.powersync,
        id: 'prayer-1',
        title: 'For today',
        action: 'Call someone who needs encouragement.',
      );

      await repository.selectForToday(
        const PrayerReference.library('prayer-1'),
        includeAction: true,
      );
      final selected = await repository.watchToday(DateTime(2026, 8, 11)).first;
      final rows = await database.powersync.getAll(
        'SELECT id, local_date FROM today_prayers',
      );

      expect(selected?.prayer.id, 'prayer-1');
      expect(selected?.includeAction, isTrue);
      expect(selected?.actionCompleted, isFalse);
      expect(selected?.localDate, DateTime(2026, 8, 11));
      expect(rows.single['local_date'], '2026-08-11');
      expect(rows.single['id'], matches(RegExp(r'^[0-9a-f-]{14}5[0-9a-f-]+$')));

      await repository.completeTodayAction(
        DateTime(2026, 8, 11),
        expectedPrayer: const PrayerReference.library('prayer-1'),
        value: true,
      );

      expect(
        (await repository.watchToday(DateTime(2026, 8, 11)).first)
            ?.actionCompleted,
        isTrue,
      );
      expect(await repository.watchToday(DateTime(2026, 8, 12)).first, isNull);
    },
  );

  test(
    'keeps the private vote and Today selection after database reopen',
    () async {
      final databasePath = '${temporaryDirectory.path}/soulbuddy.db';
      final firstDatabase = await openTestDatabase(databasePath);
      final firstRepository = PowerSyncPrayerRepository(
        database: firstDatabase.powersync,
        ownerId: 'owner-1',
        now: () => DateTime(2026, 8, 11, 12),
      );
      await _seedBundledPrayer(
        firstDatabase.powersync,
        id: 'prayer-1',
        title: 'Still here',
        action: 'Pause and give thanks.',
      );
      await firstRepository.setHelpful('prayer-1', value: true);
      await firstRepository.selectForToday(
        const PrayerReference.library('prayer-1'),
        includeAction: true,
      );
      await firstRepository.completeTodayAction(
        DateTime(2026, 8, 11),
        expectedPrayer: const PrayerReference.library('prayer-1'),
        value: true,
      );
      await firstDatabase.close();

      final reopenedDatabase = await openTestDatabase(databasePath);
      addTearDown(reopenedDatabase.close);
      final reopenedRepository = PowerSyncPrayerRepository(
        database: reopenedDatabase.powersync,
        ownerId: 'owner-1',
      );

      expect(
        (await reopenedRepository.watchPrayer('prayer-1').first)
            ?.viewerMarkedHelpful,
        isTrue,
      );
      final today = await reopenedRepository
          .watchToday(DateTime(2026, 8, 11))
          .first;
      expect(today?.prayer.title, 'Still here');
      expect(today?.actionCompleted, isTrue);
    },
  );

  test('ignores completion from a replaced Today selection', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      now: () => DateTime(2026, 8, 11, 12),
    );
    await _seedBundledPrayer(
      database.powersync,
      id: 'prayer-a',
      title: 'Prayer A',
      action: 'Action A',
    );
    await _seedBundledPrayer(
      database.powersync,
      id: 'prayer-b',
      title: 'Prayer B',
      action: 'Action B',
    );

    await repository.selectForToday(
      const PrayerReference.library('prayer-a'),
      includeAction: true,
    );
    final displayed = await repository.watchToday(DateTime(2026, 8, 11)).first;
    await repository.selectForToday(
      const PrayerReference.library('prayer-b'),
      includeAction: true,
    );

    await repository.completeTodayAction(
      displayed!.localDate,
      expectedPrayer: displayed.prayer.reference,
      value: true,
    );

    final current = await repository.watchToday(DateTime(2026, 8, 11)).first;
    expect(current?.prayer.id, 'prayer-b');
    expect(current?.actionCompleted, isFalse);
  });

  test('retains the immutable revision for a personal Today prayer', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/personal-today.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      now: () => DateTime(2026, 8, 11, 12),
    );
    await _seedPersonalPrayer(database.powersync);

    await repository.selectForToday(
      const PrayerReference.personal('personal-1'),
      includeAction: true,
    );

    final today = await repository.watchToday(DateTime(2026, 8, 11)).first;
    expect(
      today?.prayer.reference,
      const PrayerReference.personal('personal-1'),
    );
    expect(today?.prayerRevisionId, 'personal-revision-1');
  });
}

Future<void> _seedCanonicalPrayer(
  PowerSyncDatabase database, {
  required String id,
  required String title,
  int helpfulCount = 0,
  PrayerGrounding grounding = PrayerGrounding.generalChristian,
  PrayerPurpose purpose = PrayerPurpose.daily,
  String? action,
  String? publishedAt = '2026-08-01T00:00:00.000Z',
  String? archivedAt,
}) async {
  await database.execute(
    '''
    INSERT INTO library_prayers(
      id, title, body, grounding, purpose, action, helpful_count,
      published_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id,
      title,
      '$title body',
      grounding.wireValue,
      purpose.wireValue,
      action,
      helpfulCount,
      publishedAt,
      archivedAt,
    ],
  );
}

Future<void> _seedBundledPrayer(
  PowerSyncDatabase database, {
  required String id,
  required String title,
  int helpfulCount = 0,
  PrayerGrounding grounding = PrayerGrounding.generalChristian,
  PrayerPurpose purpose = PrayerPurpose.daily,
  String? action,
  String? archivedAt,
}) async {
  await database.execute(
    '''
    INSERT INTO bundled_prayers(
      id, title, body, grounding, purpose, action, helpful_count,
      content_version, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id,
      title,
      '$title body',
      grounding.wireValue,
      purpose.wireValue,
      action,
      helpfulCount,
      1,
      archivedAt,
    ],
  );
}

Future<void> _seedPersonalPrayer(PowerSyncDatabase database) async {
  await database.execute(
    '''
    INSERT INTO personal_prayers(
      id, owner_id, title, style, reach, grounding, purpose,
      current_revision_id, created_at, updated_at, archived_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''',
    [
      'personal-1',
      'owner-1',
      'A personal prayer',
      'daily',
      'personal',
      'general_christian',
      'daily',
      'personal-revision-1',
      '2026-08-11T07:00:00.000Z',
      '2026-08-11T07:00:00.000Z',
    ],
  );
  await database.execute(
    '''
    INSERT INTO personal_prayer_revisions(
      id, prayer_id, owner_id, body, action, created_at, device_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'personal-revision-1',
      'personal-1',
      'owner-1',
      'Father, lead me today. Amen.',
      'Act with patience.',
      '2026-08-11T07:00:00.000Z',
      'device-1',
    ],
  );
}
