import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_generation_repository.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_generation_request.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_language.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-prayer-generation-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'saves choices and explicit context atomically without upload CRUD',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncPrayerGenerationRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime.utc(2026, 8, 11, 8),
        uuid: const Uuid(),
      );

      final request = await repository.create(
        style: PrayerStyle.situational,
        reach: PrayerReach.encompassing,
        grounding: PrayerGrounding.generalChristian,
        purpose: PrayerPurpose.family,
        languagePreference: PrayerLanguagePreference.jesus,
        requestText: '  Give us wisdom as we care for our family.  ',
      );
      await repository.replaceContexts(request.id, const [
        PrayerGenerationContext.encounter(
          sourceId: '0198a400-0000-7000-8000-000000000001',
          displayLabel: 'A conversation I remember',
          excerptSnapshot: 'We chose to speak truthfully and forgive.',
        ),
      ]);

      final saved = await repository.watch(request.id).first;
      expect(saved?.status, PrayerGenerationStatus.editing);
      expect(saved?.languagePreference, PrayerLanguagePreference.jesus);
      expect(saved?.requestText, 'Give us wisdom as we care for our family.');
      expect(saved?.contexts, hasLength(1));
      expect(saved?.contexts.single.type, PrayerContextType.encounter);
      expect(await database.powersync.getNextCrudTransaction(), isNull);
    },
  );

  test('rejects empty and overlong request text before writing', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/validation.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );

    Future<void> create(String text) => repository.create(
      style: PrayerStyle.daily,
      reach: PrayerReach.personal,
      grounding: PrayerGrounding.catholic,
      purpose: PrayerPurpose.guidance,
      requestText: text,
    );

    await expectLater(create('   '), throwsArgumentError);
    await expectLater(
      create(List.filled(501, 'a').join()),
      throwsArgumentError,
    );
    expect(
      await database.powersync.getAll(
        'SELECT id FROM prayer_generation_requests',
      ),
      isEmpty,
    );
  });

  test('owner-scopes reads and updates', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/owners.db',
    );
    addTearDown(database.close);
    final first = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final second = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-2',
    );
    final request = await first.create(
      style: PrayerStyle.daily,
      reach: PrayerReach.personal,
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.daily,
      requestText: 'Help me walk faithfully today.',
    );

    await second.update(request.copyWith(requestText: 'Changed by another'));

    expect(await second.watch(request.id).first, isNull);
    expect(
      (await first.watch(request.id).first)?.requestText,
      'Help me walk faithfully today.',
    );
  });

  test('claims only eligible work and reclaims an expired lease', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/claim.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      now: () => DateTime.utc(2026, 8, 11, 8),
    );
    final request = await repository.create(
      style: PrayerStyle.situational,
      reach: PrayerReach.personal,
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.guidance,
      requestText: 'Show me how to respond truthfully.',
    );
    await repository.queue(
      request.id,
      provider: 'deepseek',
      disclosureVersion: '2026-08-11',
    );

    expect(
      await repository.claim(
        request.id,
        'attempt-1',
        DateTime.utc(2026, 8, 11, 8),
      ),
      isTrue,
    );
    expect(
      await repository.claim(
        request.id,
        'attempt-2',
        DateTime.utc(2026, 8, 11, 8, 0, 19),
      ),
      isFalse,
    );
    expect(
      await repository.claim(
        request.id,
        'attempt-3',
        DateTime.utc(2026, 8, 11, 8, 0, 21),
      ),
      isTrue,
    );

    final claimed = await repository.watch(request.id).first;
    expect(claimed?.activeAttemptId, 'attempt-3');
    expect(claimed?.attemptCount, 2);
  });

  test(
    'ignores stale attempt completion and stores the active draft',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/draft.db',
      );
      addTearDown(database.close);
      final repository = PowerSyncPrayerGenerationRepository(
        database: database.powersync,
        ownerId: 'owner-1',
        now: () => DateTime.utc(2026, 8, 11, 8),
      );
      final request = await repository.create(
        style: PrayerStyle.daily,
        reach: PrayerReach.encompassing,
        grounding: PrayerGrounding.catholic,
        purpose: PrayerPurpose.family,
        requestText: 'Keep our household close to you.',
      );
      await repository.queue(
        request.id,
        provider: 'deepseek',
        disclosureVersion: '2026-08-11',
      );
      await repository.claim(
        request.id,
        'active-attempt',
        DateTime.utc(2026, 8, 11, 8),
      );

      const draft = PrayerGeneratedDraft(
        title: 'For our household',
        body: 'Father, keep our household close to you. Amen.',
        action: 'Speak one word of peace at home.',
        promptVersion: 'prayer-v1',
      );
      await repository.storeDraft(request.id, 'stale-attempt', draft);
      expect(
        (await repository.watch(request.id).first)?.status,
        PrayerGenerationStatus.generating,
      );

      await repository.storeDraft(request.id, 'active-attempt', draft);

      final saved = await repository.watch(request.id).first;
      expect(saved?.status, PrayerGenerationStatus.ready);
      expect(saved?.draftBody, draft.body);
      expect(saved?.promptVersion, 'prayer-v1');
      expect(saved?.activeAttemptId, isNull);
      expect(saved?.hasUserEdits, isFalse);

      await repository.update(
        saved!.copyWith(
          draftBody: 'Father, keep our household close to you in love. Amen.',
          clearDraftAction: true,
        ),
      );
      final edited = await repository.watch(request.id).first;
      expect(edited?.draftAction, isNull);
      expect(edited?.hasUserEdits, isTrue);
    },
  );

  test('defers transient failures and marks permanent failures', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/failure.db',
    );
    addTearDown(database.close);
    final repository = PowerSyncPrayerGenerationRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      now: () => DateTime.utc(2026, 8, 11, 8),
    );
    final request = await repository.create(
      style: PrayerStyle.situational,
      reach: PrayerReach.personal,
      grounding: PrayerGrounding.generalChristian,
      purpose: PrayerPurpose.difficultTime,
      requestText: 'Help me remain faithful in this difficulty.',
    );
    await repository.queue(
      request.id,
      provider: 'deepseek',
      disclosureVersion: '2026-08-11',
    );
    await repository.claim(
      request.id,
      'attempt-1',
      DateTime.utc(2026, 8, 11, 8),
    );

    final retryAt = DateTime.utc(2026, 8, 11, 8, 1);
    await repository.defer(
      request.id,
      'attempt-1',
      nextAttemptAt: retryAt,
      failureCode: 'temporarily_unavailable',
    );
    final deferred = await repository.watch(request.id).first;
    expect(deferred?.status, PrayerGenerationStatus.queued);
    expect(deferred?.nextAttemptAt, retryAt);

    await repository.claim(request.id, 'attempt-2', retryAt);
    await repository.requireAttention(
      request.id,
      'attempt-2',
      'draft_needs_attention',
    );
    final failed = await repository.watch(request.id).first;
    expect(failed?.status, PrayerGenerationStatus.needsAttention);
    expect(failed?.failureCode, 'draft_needs_attention');
    expect(failed?.activeAttemptId, isNull);
  });
}
