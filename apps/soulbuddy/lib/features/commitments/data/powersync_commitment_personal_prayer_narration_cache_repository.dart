import 'dart:convert';
import 'dart:typed_data';
import 'package:powersync/powersync.dart';
import '../../prayers/data/prayer_narration_repository.dart';
import '../../prayers/domain/prayer_narration.dart';
import 'commitment_personal_prayer_narration_cache_repository.dart';

class PowerSyncCommitmentPersonalPrayerNarrationCacheRepository
    implements CommitmentPersonalPrayerNarrationCacheRepository {
  PowerSyncCommitmentPersonalPrayerNarrationCacheRepository({
    required this.database,
    required this.ownerId,
  });
  final PowerSyncDatabase database;
  final String ownerId;
  @override
  Future<PrayerNarration?> load({
    required String commitmentId,
    required String deviceId,
    String? personalPrayerId,
    String? revisionId,
  }) async {
    final rows = await database.getAll(
      '''SELECT cache.* FROM commitment_personal_prayer_narration_cache cache JOIN personal_prayers prayer ON prayer.id=cache.prayer_id AND prayer.owner_id=cache.owner_id AND prayer.current_revision_id=cache.revision_id AND prayer.archived_at IS NULL WHERE cache.owner_id=? AND cache.commitment_id=? AND cache.device_id=? AND cache.consented=1 ORDER BY cache.created_at DESC''',
      [ownerId, commitmentId, deviceId],
    );
    for (final row in rows) {
      if ((personalPrayerId != null && row['prayer_id'] != personalPrayerId) ||
          (revisionId != null && row['revision_id'] != revisionId) ||
          row['content_type'] != 'audio/mpeg') {
        continue;
      }
      try {
        final bytes = base64Decode(row['audio_base64'] as String);
        if (bytes.isEmpty) continue;
        return PrayerNarration(
          revisionId: row['revision_id'] as String,
          contentType: 'audio/mpeg',
          bytes: Uint8List.fromList(bytes),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<void> save({
    required String commitmentId,
    required String personalPrayerId,
    required String deviceId,
    required PrayerNarration narration,
    required bool consent,
  }) async {
    if (!consent ||
        narration.bytes.isEmpty ||
        narration.contentType != 'audio/mpeg') {
      throw const PrayerNarrationException('narration_unavailable');
    }
    await database.writeTransaction((tx) async {
      final prayer = await tx.getOptional(
        'SELECT id FROM personal_prayers WHERE id=? AND owner_id=? AND current_revision_id=? AND archived_at IS NULL',
        [personalPrayerId, ownerId, narration.revisionId],
      );
      if (prayer == null) {
        throw const PrayerNarrationException('narration_unavailable');
      }
      await tx.execute(
        'DELETE FROM commitment_personal_prayer_narration_cache WHERE owner_id=? AND commitment_id=? AND device_id=?',
        [ownerId, commitmentId, deviceId],
      );
      await tx.execute(
        '''INSERT INTO commitment_personal_prayer_narration_cache(id,owner_id,commitment_id,prayer_id,revision_id,device_id,audio_base64,content_type,consented,created_at) VALUES(?,?,?,?,?,?,?,?,1,?)''',
        [
          '$ownerId:$commitmentId:$deviceId:$personalPrayerId:${narration.revisionId}',
          ownerId,
          commitmentId,
          personalPrayerId,
          narration.revisionId,
          deviceId,
          base64Encode(narration.bytes),
          narration.contentType,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    });
  }

  @override
  Future<void> clear({
    required String commitmentId,
    required String deviceId,
  }) async {
    await database.execute(
      'DELETE FROM commitment_personal_prayer_narration_cache WHERE owner_id=? AND commitment_id=? AND device_id=?',
      [ownerId, commitmentId, deviceId],
    );
  }
}
