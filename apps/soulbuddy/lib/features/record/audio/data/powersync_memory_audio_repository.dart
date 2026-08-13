import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/memory_audio.dart';
import 'memory_audio_repository.dart';

class PowerSyncMemoryAudioRepository implements MemoryAudioRepository {
  PowerSyncMemoryAudioRepository({
    required this.database,
    required String ownerId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : ownerId = _owner(ownerId),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<MemoryAudio?> watchForEncounter(String encounterId) {
    final normalizedId = _recordId(encounterId, 'encounterId');
    return database
        .watch(
          '''
          SELECT * FROM memory_audio_assets
          WHERE owner_id = ? AND encounter_id = ?
          LIMIT 1
          ''',
          parameters: [ownerId, normalizedId],
        )
        .map((rows) => rows.isEmpty ? null : MemoryAudio.fromRow(rows.single));
  }

  @override
  Future<MemoryAudio> attach(
    MemoryAudioDraft draft, {
    required String encounterId,
    required String revisionId,
    required String durableKey,
    required int byteSize,
  }) async {
    final normalizedEncounterId = _recordId(encounterId, 'encounterId');
    final normalizedRevisionId = _recordId(revisionId, 'revisionId');
    final createdAt = _now().toUtc();
    final saved = MemoryAudio(
      id: _uuid.v7(),
      encounterId: normalizedEncounterId,
      revisionId: normalizedRevisionId,
      storageKey: durableKey,
      mimeType: draft.mimeType,
      duration: draft.duration,
      byteSize: byteSize,
      waveform: draft.waveform,
      createdAt: createdAt,
    );

    await database.writeTransaction((transaction) async {
      final source = await transaction.getOptional(
        '''
        SELECT encounter.id
        FROM encounters AS encounter
        JOIN encounter_revisions AS revision
          ON revision.id = encounter.current_revision_id
         AND revision.encounter_id = encounter.id
         AND revision.owner_id = encounter.owner_id
        WHERE encounter.id = ?
          AND encounter.owner_id = ?
          AND encounter.archived_at IS NULL
          AND encounter.current_revision_id = ?
        LIMIT 1
        ''',
        [normalizedEncounterId, ownerId, normalizedRevisionId],
      );
      if (source == null) {
        throw StateError('The memory is not available for audio attachment.');
      }

      final existing = await transaction.getOptional(
        '''
        SELECT id FROM memory_audio_assets
        WHERE owner_id = ? AND encounter_id = ?
        LIMIT 1
        ''',
        [ownerId, normalizedEncounterId],
      );
      if (existing != null) {
        throw StateError('This memory already has an audio attachment.');
      }

      await transaction.execute(
        '''
        INSERT INTO memory_audio_assets(
          id, owner_id, encounter_id, encounter_revision_id,
          storage_key, mime_type, duration_ms, byte_size,
          waveform_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          saved.id,
          ownerId,
          saved.encounterId,
          saved.revisionId,
          saved.storageKey,
          saved.mimeType,
          saved.duration.inMilliseconds,
          saved.byteSize,
          jsonEncode(saved.waveform),
          saved.createdAt.toIso8601String(),
        ],
      );
    });
    return saved;
  }

  @override
  Future<String?> deleteMetadata(String encounterId) async {
    final normalizedId = _recordId(encounterId, 'encounterId');
    String? storageKey;
    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        '''
        SELECT id, storage_key FROM memory_audio_assets
        WHERE owner_id = ? AND encounter_id = ?
        LIMIT 1
        ''',
        [ownerId, normalizedId],
      );
      if (existing == null) return;
      storageKey = existing['storage_key'] as String;
      await transaction.execute(
        'DELETE FROM memory_audio_assets WHERE id = ? AND owner_id = ?',
        [existing['id'], ownerId],
      );
    });
    return storageKey;
  }

  @override
  Future<Set<String>> ownedStorageKeys() async {
    final rows = await database.getAll(
      'SELECT storage_key FROM memory_audio_assets WHERE owner_id = ?',
      [ownerId],
    );
    return rows.map((row) => row['storage_key'] as String).toSet();
  }
}

String _owner(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(value, 'ownerId');
  }
  return normalized;
}

String _recordId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}
