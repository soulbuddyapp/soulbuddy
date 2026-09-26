import 'package:soulbuddy/features/commitments/data/powersync_commitment_finalizer.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_journey_practice_draft_repository.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_prayer_narration_preparer.dart';
import 'package:soulbuddy/features/commitments/data/powersync_commitment_personal_prayer_narration_cache_repository.dart';
import 'package:soulbuddy/features/prayers/data/prayer_narration_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_narration.dart';
import '../../helpers/powersync_test_database.dart';

void main() {
  test(
    'finalization transfers only the selected consented revision cache',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'commitment-prayer-finalize-',
      );
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await db.powersync.execute(
        "INSERT INTO personal_prayers(id,owner_id,current_revision_id) VALUES('prayer','alice','revision')",
      );
      await db.powersync.execute(
        "INSERT INTO personal_prayer_revisions(id,owner_id,prayer_id) VALUES('revision','alice','prayer')",
      );
      final cache = PowerSyncCommitmentPersonalPrayerNarrationCacheRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      await cache.save(
        commitmentId: 'draft',
        personalPrayerId: 'prayer',
        deviceId: 'device',
        narration: PrayerNarration(
          revisionId: 'revision',
          contentType: 'audio/mpeg',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        consent: true,
      );
      await PowerSyncCommitmentJourneyPracticeDraftRepository(
        database: db.powersync,
        ownerId: 'alice',
      ).save([
        const CommitmentPracticeDraft(
          id: 'practice',
          category: CommitmentPracticeCategory.joyPleasure,
          body: 'Help a neighbor',
        ),
      ]);
      final result =
          await PowerSyncCommitmentFinalizer(
            database: db.powersync,
            ownerId: 'alice',
            deviceId: 'device',
          ).finalize(
            const CommitmentJourneyProgress(
              name: 'Service',
              keyNeedOne: 'Hope',
              keyNeedTwo: 'Peace',
              keyNeedThree: 'Grace',
              calling: 'Serve faithfully',
              guideId: CommitmentGuideId.peace,
              declarationDraft: 'I offer this to God.',
              declarationReviewed: true,
              frequency: CommitmentMeditationFrequency.daily,
              localTime: '07:30',
              timezone: 'Africa/Lagos',
              durationMinutes: 10,
              personalPrayerId: 'prayer',
              personalPrayerRevisionId: 'revision',
            ),
          );
      expect(
        (await cache.load(
          commitmentId: result.commitmentId,
          deviceId: 'device',
        ))!.bytes,
        [1, 2, 3],
      );
      expect(
        await cache.load(commitmentId: 'draft', deviceId: 'device'),
        isNull,
      );
      expect(
        await db.powersync.getAll('SELECT * FROM prayer_sessions'),
        isEmpty,
      );
    },
  );
  test(
    'consent gates uploader and TTS; exact immutable IDs only cross boundary',
    () async {
      final calls = <Map<String, Object>>[];
      final service = CommitmentPrayerNarrationPreparer(
        repository: _Narrator(calls),
        uploadPrerequisite:
            ({required personalPrayerId, required revisionId}) async {
              calls.add({
                'prayerId': personalPrayerId,
                'revisionId': revisionId,
              });
            },
      );
      await expectLater(
        service.prepare(
          personalPrayerId: 'prayer',
          prayerRevisionId: 'revision',
          consent: false,
        ),
        throwsA(isA<PrayerNarrationException>()),
      );
      expect(calls, isEmpty);
      final result = await service.prepare(
        personalPrayerId: 'prayer',
        prayerRevisionId: 'revision',
        consent: true,
      );
      expect(result.revisionId, 'revision');
      expect(calls, [
        {'prayerId': 'prayer', 'revisionId': 'revision'},
        {
          'personalPrayerId': 'prayer',
          'prayerRevisionId': 'revision',
          'consent': true,
        },
      ]);
    },
  );
  test('wrong revision and empty provider audio are rejected', () async {
    final service = CommitmentPrayerNarrationPreparer(
      repository: _Narrator([], revision: 'other'),
      uploadPrerequisite:
          ({required personalPrayerId, required revisionId}) async {},
    );
    await expectLater(
      service.prepare(
        personalPrayerId: 'prayer',
        prayerRevisionId: 'revision',
        consent: true,
      ),
      throwsA(isA<PrayerNarrationException>()),
    );
  });
  test(
    'private bytes are local, owner and device scoped, and stale revisions are ignored',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'commitment-prayer-cache-',
      );
      final db = await openTestDatabase('${dir.path}/test.db');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await db.powersync.execute(
        "INSERT INTO personal_prayers(id,owner_id,current_revision_id) VALUES('prayer','alice','revision')",
      );
      final pending = await db.powersync.getNextCrudTransaction();
      await pending!.complete();
      final cache = PowerSyncCommitmentPersonalPrayerNarrationCacheRepository(
        database: db.powersync,
        ownerId: 'alice',
      );
      final narration = PrayerNarration(
        revisionId: 'revision',
        contentType: 'audio/mpeg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await cache.save(
        commitmentId: 'draft',
        personalPrayerId: 'prayer',
        deviceId: 'device',
        narration: narration,
        consent: true,
      );
      expect(
        (await cache.load(commitmentId: 'draft', deviceId: 'device'))!.bytes,
        [1, 2, 3],
      );
      expect(
        await cache.load(commitmentId: 'draft', deviceId: 'other'),
        isNull,
      );
      expect(
        await PowerSyncCommitmentPersonalPrayerNarrationCacheRepository(
          database: db.powersync,
          ownerId: 'bob',
        ).load(commitmentId: 'draft', deviceId: 'device'),
        isNull,
      );
      expect(await db.powersync.getNextCrudTransaction(), isNull);
      await db.powersync.execute(
        "UPDATE personal_prayers SET current_revision_id='new' WHERE id='prayer'",
      );
      expect(
        await cache.load(commitmentId: 'draft', deviceId: 'device'),
        isNull,
      );
    },
  );
}

class _Narrator implements PrayerNarrationRepository {
  _Narrator(this.calls, {this.revision});
  final List<Map<String, Object>> calls;
  final String? revision;
  @override
  Future<PrayerNarration> prepare({
    required String personalPrayerId,
    required String prayerRevisionId,
    required bool consent,
  }) async {
    calls.add({
      'personalPrayerId': personalPrayerId,
      'prayerRevisionId': prayerRevisionId,
      'consent': consent,
    });
    return PrayerNarration(
      revisionId: revision ?? prayerRevisionId,
      contentType: 'audio/mpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }
}
