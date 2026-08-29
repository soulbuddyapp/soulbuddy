import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-prayer-generation-archive-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('historical generated prayer data remains readable', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/archive.db',
    );
    addTearDown(database.close);
    const requestId = '0198a400-0000-7000-8000-000000000001';
    const createdAt = '2026-08-11T08:00:00.000Z';

    await database.powersync.execute(
      '''
      INSERT INTO prayer_generation_requests(
        id, owner_id, style, reach, grounding, language_preference, purpose,
        request_text, status, draft_title, draft_body, draft_action,
        generated_title, generated_body, generated_action, prompt_version,
        consented_provider, consented_disclosure_version, attempt_count,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        requestId,
        'owner-1',
        'situational',
        'personal',
        'general_christian',
        'christian',
        'guidance',
        'Help me respond truthfully.',
        'ready',
        'A truthful response',
        'Father, help me answer with truth and love. Amen.',
        'Speak calmly and tell the truth.',
        'A truthful response',
        'Father, help me answer with truth and love. Amen.',
        'Speak calmly and tell the truth.',
        'legacy-v1',
        'deepseek',
        'deepseek-1',
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
        '0198a400-0000-7000-8000-000000000002',
        requestId,
        'encounter',
        'memory-1',
        'A conversation I remember',
        'We chose to speak truthfully and forgive.',
        createdAt,
      ],
    );

    final repository = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final request = await repository.watch(requestId).first;

    expect(request, isNotNull);
    expect(request!.status, PrayerGenerationStatus.ready);
    expect(request.draftTitle, 'A truthful response');
    expect(
      request.draftBody,
      'Father, help me answer with truth and love. Amen.',
    );
    expect(request.consentedProvider, 'deepseek');
    expect(request.contexts, hasLength(1));
    expect(request.contexts.single.sourceId, 'memory-1');
    await expectLater(repository.watchPending(), emitsDone);
    expect(await database.powersync.getNextCrudTransaction(), isNull);
  });

  test('historical generation archive rejects every mutation', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/read-only.db',
    );
    addTearDown(database.close);
    const requestId = '0198a400-0000-7000-8000-000000000003';
    const createdAt = '2026-08-11T08:00:00.000Z';

    await database.powersync.execute(
      '''
      INSERT INTO prayer_generation_requests(
        id, owner_id, style, reach, grounding, purpose, request_text, status,
        attempt_count, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        requestId,
        'owner-1',
        'daily',
        'personal',
        'general_christian',
        'daily',
        'Help me walk faithfully today.',
        'ready',
        0,
        createdAt,
        createdAt,
      ],
    );

    final repository = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final original = (await repository.watch(requestId).first)!;

    await expectLater(
      repository.create(
        style: PrayerStyle.daily,
        reach: PrayerReach.personal,
        grounding: PrayerGrounding.generalChristian,
        purpose: PrayerPurpose.daily,
        requestText: 'A new request must never be created.',
      ),
      throwsStateError,
    );
    await expectLater(
      repository.update(
        original.copyWith(requestText: 'A mutation must never be stored.'),
      ),
      throwsStateError,
    );
    await expectLater(
      repository.replaceContexts(requestId, const []),
      throwsStateError,
    );
    await expectLater(
      repository.queue(
        requestId,
        provider: 'deepseek',
        disclosureVersion: 'deepseek-1',
      ),
      throwsStateError,
    );
    await expectLater(
      repository.claim(requestId, 'attempt-1', DateTime.utc(2026, 8, 29)),
      throwsStateError,
    );
    await expectLater(
      repository.storeDraft(
        requestId,
        'attempt-1',
        const PrayerGeneratedDraft(
          title: 'Blocked',
          body: 'Blocked',
          promptVersion: 'retired',
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      repository.defer(
        requestId,
        'attempt-1',
        nextAttemptAt: DateTime.utc(2026, 8, 30),
      ),
      throwsStateError,
    );
    await expectLater(
      repository.requireAttention(requestId, 'attempt-1', 'retired'),
      throwsStateError,
    );

    final unchanged = await repository.watch(requestId).first;
    expect(unchanged?.requestText, 'Help me walk faithfully today.');
    expect(unchanged?.status, PrayerGenerationStatus.ready);
    expect(await database.powersync.getNextCrudTransaction(), isNull);
  });
}
