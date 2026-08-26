import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/database/app_database.dart';
import 'package:soulbuddy/features/prayers/data/powersync_voice_tablet_repository.dart';
import 'package:soulbuddy/features/prayers/data/voice_tablet_repository.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  late Directory temporaryDirectory;
  late AppDatabase database;
  late PowerSyncVoiceTabletRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-voice-tablet-',
    );
    database = await openTestDatabase('${temporaryDirectory.path}/app.db');
    repository = PowerSyncVoiceTabletRepository(
      database: database.powersync,
      ownerId: 'owner-1',
      deviceId: 'device-1',
      now: () => DateTime.utc(2026, 8, 26, 7),
    );
    await _seedPersonalPrayer(database, ownerId: 'owner-1');
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'attaches a full prayer and short refrain to the exact revision',
    () async {
      final saved = await repository.create(
        VoiceTabletCreateRequest(
          source: VoiceTabletSource.personal(
            prayerId: 'prayer-1',
            revisionId: 'revision-1',
          ),
          title: 'Morning surrender',
          fullRecording: _attachment(
            id: 'full-1',
            key: 'voice/full-1.m4a',
            duration: const Duration(minutes: 2),
          ),
          refrain: _attachment(
            id: 'refrain-1',
            key: 'voice/refrain-1.m4a',
            duration: const Duration(seconds: 20),
          ),
        ),
      );

      expect(saved.source.revisionId, 'revision-1');
      expect(saved.fullAudio?.duration, const Duration(minutes: 2));
      expect(saved.refrainAudio?.duration, const Duration(seconds: 20));
      expect(await repository.watch(saved.id).first, saved);
      expect(await repository.ownedStorageKeys(), {
        'voice/full-1.m4a',
        'voice/refrain-1.m4a',
      });
    },
  );

  test('rejects a refrain longer than twenty five seconds', () {
    expect(
      () => VoiceTabletAudioAttachment(
        id: 'refrain-long',
        kind: VoiceTabletAudioKind.refrain,
        draft: _draft(const Duration(seconds: 26)),
        committed: const CommittedAudio(
          storageKey: 'voice/refrain-long.m4a',
          byteSize: 1024,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a prayer owned by another installation identity', () async {
    final foreign = PowerSyncVoiceTabletRepository(
      database: database.powersync,
      ownerId: 'owner-2',
      deviceId: 'device-2',
      now: () => DateTime.utc(2026, 8, 26, 7),
    );

    await expectLater(
      foreign.create(
        VoiceTabletCreateRequest(
          source: VoiceTabletSource.personal(
            prayerId: 'prayer-1',
            revisionId: 'revision-1',
          ),
          title: 'Foreign tablet',
          fullRecording: _attachment(
            id: 'full-foreign',
            key: 'voice/foreign.m4a',
            duration: const Duration(seconds: 10),
          ),
        ),
      ),
      throwsStateError,
    );
  });

  test('replaces audio only after the new metadata is committed', () async {
    final saved = await repository.create(
      VoiceTabletCreateRequest(
        source: VoiceTabletSource.personal(
          prayerId: 'prayer-1',
          revisionId: 'revision-1',
        ),
        title: 'Morning surrender',
        fullRecording: _attachment(
          id: 'full-original',
          key: 'voice/full-original.m4a',
          duration: const Duration(seconds: 30),
        ),
      ),
    );

    final replacement = await repository.replaceAudio(
      saved.id,
      _attachment(
        id: 'full-replacement',
        key: 'voice/full-replacement.m4a',
        duration: const Duration(seconds: 35),
      ),
    );

    expect(replacement.replacedStorageKey, 'voice/full-original.m4a');
    expect(replacement.tablet.fullAudio?.id, 'full-replacement');
    expect(await repository.ownedStorageKeys(), {'voice/full-replacement.m4a'});
  });

  test('archives metadata and returns local assets for explicit cleanup', () async {
    final saved = await repository.create(
      VoiceTabletCreateRequest(
        source: VoiceTabletSource.personal(
          prayerId: 'prayer-1',
          revisionId: 'revision-1',
        ),
        title: 'Morning surrender',
        fullRecording: _attachment(
          id: 'full-archive',
          key: 'voice/full-archive.m4a',
          duration: const Duration(seconds: 30),
        ),
        refrain: _attachment(
          id: 'refrain-archive',
          key: 'voice/refrain-archive.m4a',
          duration: const Duration(seconds: 15),
        ),
      ),
    );

    final keys = await repository.archive(saved.id);

    expect(keys, {
      'voice/full-archive.m4a',
      'voice/refrain-archive.m4a',
    });
    expect(await repository.watch(saved.id).first, isNull);
    expect(await repository.ownedStorageKeys(), isEmpty);
  });
}

VoiceTabletAudioAttachment _attachment({
  required String id,
  required String key,
  required Duration duration,
}) => VoiceTabletAudioAttachment(
  id: id,
  kind: id.startsWith('refrain')
      ? VoiceTabletAudioKind.refrain
      : VoiceTabletAudioKind.fullPrayer,
  draft: _draft(duration),
  committed: CommittedAudio(storageKey: key, byteSize: 1024),
);

RecordedAudioDraft _draft(Duration duration) => RecordedAudioDraft(
  temporaryKey: 'temporary/take.m4a',
  mimeType: 'audio/mp4',
  duration: duration,
  waveform: const [0.1, 0.4, 0.8, 0.2],
);

Future<void> _seedPersonalPrayer(
  AppDatabase database, {
  required String ownerId,
}) async {
  const createdAt = '2026-08-26T07:00:00.000Z';
  await database.powersync.writeTransaction((transaction) async {
    await transaction.execute(
      '''
      INSERT INTO personal_prayer_revisions(
        id, prayer_id, owner_id, body, action, created_at, device_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'revision-1',
        'prayer-1',
        ownerId,
        'Father, keep me in your truth today.',
        null,
        createdAt,
        'device-1',
      ],
    );
    await transaction.execute(
      '''
      INSERT INTO personal_prayers(
        id, owner_id, title, style, reach, grounding, purpose,
        current_revision_id, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        'prayer-1',
        ownerId,
        'Morning surrender',
        'daily',
        'personal',
        'general_christian',
        'character',
        'revision-1',
        createdAt,
        createdAt,
      ],
    );
  });
}
