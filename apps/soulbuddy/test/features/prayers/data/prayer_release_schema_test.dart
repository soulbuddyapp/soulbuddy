import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_schema.dart';
import 'package:soulbuddy/features/prayers/data/prayer_release_api_client.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_release_repository.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';
import 'package:uuid/uuid.dart';

import '../../../helpers/powersync_test_database.dart';

void main() {
  test('runtime schema opens every prayer release table', () async {
    final directory = await Directory.systemTemp.createTemp('release-schema-');
    final database = await openTestDatabase('${directory.path}/app.db');
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    for (final table in const [
      'prayer_release_cache',
      'prayer_release_item_cache',
      'prayer_release_preference_cache',
      'prayer_release_downloads',
      'prayer_release_item_content',
      'affirmation_prayer_sessions',
    ]) {
      expect(
        await database.powersync.getAll('SELECT id FROM $table LIMIT 1'),
        isEmpty,
        reason: '$table must exist in the runtime schema',
      );
    }
  });

  test('account-owned release rows are marked for PowerSync', () {
    Table tableNamed(String name) =>
        appSchema.tables.firstWhere((table) => table.name == name);

    // A local-only table records no changes, so a local row is readable but
    // never uploaded as a client mutation.
    bool isLocalOnly(String name) => tableNamed(name).localOnly;

    // The server owns the add, so the local download is a cache of its
    // response and must never be uploaded.
    expect(
      isLocalOnly('prayer_release_downloads'),
      isTrue,
      reason: 'a local download mirrors the server response',
    );
    expect(
      tableNamed('prayer_release_downloads').columns.map((c) => c.name),
      contains('owner_id'),
    );

    // A counted prayer session is written by this account and synced to it.
    expect(isLocalOnly('affirmation_prayer_sessions'), isFalse);
    expect(
      tableNamed('affirmation_prayer_sessions').columns.map((c) => c.name),
      containsAll(<String>[
        'owner_id',
        'release_item_id',
        'outcome',
        'step_one_count',
        'step_two_count',
      ]),
    );

    for (final local in const [
      'prayer_release_cache',
      'prayer_release_item_cache',
      'prayer_release_preference_cache',
      'prayer_release_item_content',
    ]) {
      expect(isLocalOnly(local), isTrue, reason: '$local is a local cache');
    }
  });

  test('a counted session is uploaded once for the owning account', () async {
    final directory = await Directory.systemTemp.createTemp('release-sync-');
    final path = '${directory.path}/app.db';
    final database = await openTestDatabase(path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final uuid = const Uuid();
    final ownerId = 'owner-1';
    final repository = PowerSyncPrayerReleaseRepository(
      database: database.powersync,
      ownerId: ownerId,
      now: () => DateTime.utc(2026, 10, 6, 12),
      client: _unusedClient(),
    );

    // A local download produces no upload of its own.
    await database.powersync.execute(
      '''
      INSERT INTO prayer_release_downloads(
        id, owner_id, release_id, release_slug, downloaded_at
      ) VALUES (?, ?, 'release-1', 'slug', '2026-10-06T09:00:00Z')
    ''',
      [uuid.v7(), ownerId],
    );
    expect(await database.powersync.getNextCrudTransaction(), isNull);

    final sessionId = uuid.v7();
    await repository.saveAffirmationSession(_session(id: sessionId));

    final transaction = await database.powersync.getNextCrudTransaction();
    expect(transaction, isNotNull);
    expect(transaction!.crud.map((entry) => entry.table), [
      'affirmation_prayer_sessions',
    ]);
    expect(transaction.crud.single.id, sessionId);

    // Saving the same terminal record again adds nothing.
    await repository.saveAffirmationSession(_session(id: sessionId));
    expect(
      await database.powersync.getAll(
        'SELECT id FROM affirmation_prayer_sessions',
      ),
      hasLength(1),
    );
  });
}

/// A terminal early exit that stops after twelve repetitions.
AffirmationPrayerSession _session({required String id}) {
  return AffirmationPrayerSession(
    id: id,
    releaseItemId: 'release-item-3',
    localDate: '2026-10-06',
    startedAt: DateTime.utc(2026, 10, 6, 9),
    endedAt: DateTime.utc(2026, 10, 6, 9, 12),
    outcome: AffirmationPrayerOutcome.endedEarly,
    stepOneCount: 12,
    stepTwoCount: 0,
    soundKey: 'oceanWaves',
    narrationSpeed: .85,
  );
}

/// A client that is never reached; these tests write local rows directly.
PrayerReleaseApiClient _unusedClient() {
  return PrayerReleaseApiClient(
    apiBaseUri: Uri.parse('https://api.example.test'),
    accessToken: () async => 'session-token',
    httpClient: MockClient((_) async => throw StateError('not used')),
  );
}
