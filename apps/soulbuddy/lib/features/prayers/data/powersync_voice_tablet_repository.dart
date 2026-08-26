import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import '../domain/voice_tablet.dart';
import 'voice_tablet_repository.dart';

class PowerSyncVoiceTabletRepository implements VoiceTabletRepository {
  PowerSyncVoiceTabletRepository({
    required this.database,
    required String ownerId,
    required String deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : ownerId = _identifier(ownerId, 'ownerId'),
       deviceId = _identifier(deviceId, 'deviceId'),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<VoiceTablet?> watch(String id) {
    final tabletId = _identifier(id, 'id');
    return database
        .watch(_selectSql('tablet.id = ?'), parameters: [ownerId, tabletId])
        .map(_singleTablet);
  }

  @override
  Stream<VoiceTablet?> watchForSource(VoiceTabletSource source) {
    final sourceColumn = source.type == VoiceTabletSourceType.personalPrayer
        ? 'tablet.personal_prayer_id'
        : 'tablet.library_prayer_id';
    final revisionClause = source.type == VoiceTabletSourceType.personalPrayer
        ? ' AND tablet.prayer_revision_id = ?'
        : '';
    final parameters = <Object?>[
      ownerId,
      source.type.wireValue,
      source.prayerId,
      if (source.revisionId case final revisionId?) revisionId,
    ];
    return database
        .watch(
          _selectSql(
            'tablet.source_type = ? AND $sourceColumn = ?$revisionClause',
          ),
          parameters: parameters,
        )
        .map(_singleTablet);
  }

  @override
  Future<VoiceTablet> create(VoiceTabletCreateRequest request) async {
    final createdAt = _now().toUtc();
    final tabletId = _uuid.v7();
    final title = _title(request.title);

    await database.writeTransaction((transaction) async {
      if (!await _sourceExists(transaction, request.source)) {
        throw StateError('The prayer is not available for this Voice Tablet.');
      }

      await transaction.execute(
        '''
        INSERT INTO voice_tablets(
          id, owner_id, source_type, personal_prayer_id, library_prayer_id,
          prayer_revision_id, title, full_audio_id, refrain_audio_id,
          recording_device_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          tabletId,
          ownerId,
          request.source.type.wireValue,
          request.source.type == VoiceTabletSourceType.personalPrayer
              ? request.source.prayerId
              : null,
          request.source.type == VoiceTabletSourceType.libraryPrayer
              ? request.source.prayerId
              : null,
          request.source.revisionId,
          title,
          request.fullRecording.id,
          request.refrain?.id,
          deviceId,
          createdAt.toIso8601String(),
          createdAt.toIso8601String(),
        ],
      );
      await _insertAudio(
        transaction,
        tabletId: tabletId,
        attachment: request.fullRecording,
        createdAt: createdAt,
      );
      if (request.refrain case final refrain?) {
        await _insertAudio(
          transaction,
          tabletId: tabletId,
          attachment: refrain,
          createdAt: createdAt,
        );
      }
    });

    final saved = await watch(tabletId).first;
    if (saved == null) {
      throw StateError('The Voice Tablet could not be opened after saving.');
    }
    return saved;
  }

  @override
  Future<VoiceTabletReplacement> replaceAudio(
    String tabletId,
    VoiceTabletAudioAttachment replacement,
  ) async {
    final normalizedTabletId = _identifier(tabletId, 'tabletId');
    final updatedAt = _now().toUtc();
    final currentColumn = replacement.kind == VoiceTabletAudioKind.fullPrayer
        ? 'full_audio_id'
        : 'refrain_audio_id';
    late String replacedStorageKey;

    await database.writeTransaction((transaction) async {
      final existing = await transaction.getOptional(
        '''
        SELECT asset.id, asset.storage_key
        FROM voice_tablets AS tablet
        JOIN voice_tablet_audio_assets AS asset
          ON asset.id = tablet.$currentColumn
         AND asset.owner_id = tablet.owner_id
         AND asset.voice_tablet_id = tablet.id
         AND asset.audio_kind = ?
        WHERE tablet.id = ?
          AND tablet.owner_id = ?
          AND tablet.archived_at IS NULL
        LIMIT 1
        ''',
        [replacement.kind.wireValue, normalizedTabletId, ownerId],
      );
      if (existing == null) {
        throw StateError('The Voice Tablet audio is not available to replace.');
      }

      await _insertAudio(
        transaction,
        tabletId: normalizedTabletId,
        attachment: replacement,
        createdAt: updatedAt,
      );
      await transaction.execute(
        '''
        UPDATE voice_tablets
        SET $currentColumn = ?, updated_at = ?
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        ''',
        [
          replacement.id,
          updatedAt.toIso8601String(),
          normalizedTabletId,
          ownerId,
        ],
      );
      await transaction.execute(
        'DELETE FROM voice_tablet_audio_assets WHERE id = ? AND owner_id = ?',
        [existing['id'], ownerId],
      );
      replacedStorageKey = existing['storage_key'] as String;
    });

    final saved = await watch(normalizedTabletId).first;
    if (saved == null) {
      throw StateError(
        'The Voice Tablet could not be opened after replacing audio.',
      );
    }
    return VoiceTabletReplacement(
      tablet: saved,
      replacedStorageKey: replacedStorageKey,
    );
  }

  @override
  Future<Set<String>> archive(String tabletId) async {
    final normalizedTabletId = _identifier(tabletId, 'tabletId');
    final archivedAt = _now().toUtc().toIso8601String();
    final keys = <String>{};
    await database.writeTransaction((transaction) async {
      final tablet = await transaction.getOptional(
        '''
        SELECT id FROM voice_tablets
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        LIMIT 1
        ''',
        [normalizedTabletId, ownerId],
      );
      if (tablet == null) {
        throw StateError('The Voice Tablet is not available to archive.');
      }
      final assets = await transaction.getAll(
        '''
        SELECT storage_key FROM voice_tablet_audio_assets
        WHERE voice_tablet_id = ? AND owner_id = ?
        ''',
        [normalizedTabletId, ownerId],
      );
      keys.addAll(assets.map((row) => row['storage_key'] as String));
      await transaction.execute(
        '''
        UPDATE voice_tablets
        SET archived_at = ?, updated_at = ?
        WHERE id = ? AND owner_id = ? AND archived_at IS NULL
        ''',
        [archivedAt, archivedAt, normalizedTabletId, ownerId],
      );
      await transaction.execute(
        '''
        DELETE FROM voice_tablet_audio_assets
        WHERE voice_tablet_id = ? AND owner_id = ?
        ''',
        [normalizedTabletId, ownerId],
      );
    });
    return keys;
  }

  @override
  Future<Set<String>> ownedStorageKeys() async {
    final rows = await database.getAll(
      'SELECT storage_key FROM voice_tablet_audio_assets WHERE owner_id = ?',
      [ownerId],
    );
    return rows.map((row) => row['storage_key'] as String).toSet();
  }

  Future<bool> _sourceExists(
    SqliteWriteContext transaction,
    VoiceTabletSource source,
  ) async {
    if (source.type == VoiceTabletSourceType.personalPrayer) {
      final row = await transaction.getOptional(
        '''
        SELECT prayer.id
        FROM personal_prayers AS prayer
        JOIN personal_prayer_revisions AS revision
          ON revision.id = prayer.current_revision_id
         AND revision.prayer_id = prayer.id
         AND revision.owner_id = prayer.owner_id
        WHERE prayer.id = ?
          AND prayer.owner_id = ?
          AND prayer.current_revision_id = ?
          AND prayer.archived_at IS NULL
        LIMIT 1
        ''',
        [source.prayerId, ownerId, source.revisionId],
      );
      return row != null;
    }
    final row = await transaction.getOptional(
      '''
      SELECT id FROM library_prayers
      WHERE id = ? AND published_at IS NOT NULL AND archived_at IS NULL
      LIMIT 1
      ''',
      [source.prayerId],
    );
    return row != null;
  }

  Future<void> _insertAudio(
    SqliteWriteContext transaction, {
    required String tabletId,
    required VoiceTabletAudioAttachment attachment,
    required DateTime createdAt,
  }) => transaction.execute(
    '''
    INSERT INTO voice_tablet_audio_assets(
      id, owner_id, voice_tablet_id, audio_kind, storage_key, mime_type,
      duration_ms, byte_size, waveform_json, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      attachment.id,
      ownerId,
      tabletId,
      attachment.kind.wireValue,
      attachment.committed.storageKey,
      attachment.draft.mimeType,
      attachment.draft.duration.inMilliseconds,
      attachment.committed.byteSize,
      jsonEncode(attachment.draft.waveform),
      createdAt.toIso8601String(),
    ],
  );

  String _selectSql(String predicate) =>
      '''
    SELECT
      tablet.*,
      full.id AS full_id,
      full.storage_key AS full_storage_key,
      full.mime_type AS full_mime_type,
      full.duration_ms AS full_duration_ms,
      full.byte_size AS full_byte_size,
      full.waveform_json AS full_waveform_json,
      full.created_at AS full_created_at,
      refrain.id AS refrain_id,
      refrain.storage_key AS refrain_storage_key,
      refrain.mime_type AS refrain_mime_type,
      refrain.duration_ms AS refrain_duration_ms,
      refrain.byte_size AS refrain_byte_size,
      refrain.waveform_json AS refrain_waveform_json,
      refrain.created_at AS refrain_created_at
    FROM voice_tablets AS tablet
    LEFT JOIN voice_tablet_audio_assets AS full
      ON full.id = tablet.full_audio_id
     AND full.owner_id = tablet.owner_id
     AND full.voice_tablet_id = tablet.id
     AND full.audio_kind = 'full_prayer'
    LEFT JOIN voice_tablet_audio_assets AS refrain
      ON refrain.id = tablet.refrain_audio_id
     AND refrain.owner_id = tablet.owner_id
     AND refrain.voice_tablet_id = tablet.id
     AND refrain.audio_kind = 'refrain'
    WHERE tablet.owner_id = ? AND $predicate
      AND tablet.archived_at IS NULL
    ORDER BY tablet.updated_at DESC, tablet.id ASC
    LIMIT 1
  ''';

  VoiceTablet? _singleTablet(List<Map<String, dynamic>> rows) =>
      rows.isEmpty ? null : _fromRow(rows.single);

  VoiceTablet _fromRow(Map<String, dynamic> row) {
    final type = VoiceTabletSourceType.fromWire(row['source_type'] as String);
    return VoiceTablet(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      source: type == VoiceTabletSourceType.personalPrayer
          ? VoiceTabletSource.personal(
              prayerId: row['personal_prayer_id'] as String,
              revisionId: row['prayer_revision_id'] as String,
            )
          : VoiceTabletSource.library(
              prayerId: row['library_prayer_id'] as String,
            ),
      title: row['title'] as String,
      fullAudio: _audioFromRow(row, VoiceTabletAudioKind.fullPrayer),
      refrainAudio: _audioFromRow(row, VoiceTabletAudioKind.refrain),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
    );
  }

  VoiceTabletAudio? _audioFromRow(
    Map<String, dynamic> row,
    VoiceTabletAudioKind kind,
  ) {
    final prefix = kind == VoiceTabletAudioKind.fullPrayer ? 'full' : 'refrain';
    final id = row['${prefix}_id'] as String?;
    if (id == null) return null;
    final decoded = jsonDecode(row['${prefix}_waveform_json'] as String);
    if (decoded is! List) {
      throw const FormatException('Invalid Voice Tablet waveform');
    }
    return VoiceTabletAudio(
      id: id,
      kind: kind,
      storageKey: row['${prefix}_storage_key'] as String,
      mimeType: row['${prefix}_mime_type'] as String,
      duration: Duration(milliseconds: row['${prefix}_duration_ms'] as int),
      byteSize: row['${prefix}_byte_size'] as int,
      waveform: decoded.map((value) => (value as num).toDouble()).toList(),
      createdAt: DateTime.parse(row['${prefix}_created_at'] as String),
    );
  }
}

String _identifier(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}

String _title(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > 120 ||
      normalized.contains('\u0000')) {
    throw ArgumentError.value(value, 'title');
  }
  return normalized;
}
