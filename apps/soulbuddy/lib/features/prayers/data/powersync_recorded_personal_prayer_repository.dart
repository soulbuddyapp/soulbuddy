import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/data/memory_soundscape_preferences.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/domain/memory_soundscape.dart';
import '../domain/library_prayer.dart';
import '../domain/personal_prayer.dart';
import '../domain/voice_tablet.dart';
import 'recorded_personal_prayer_repository.dart';

class PowerSyncRecordedPersonalPrayerRepository
    implements RecordedPersonalPrayerRepository {
  PowerSyncRecordedPersonalPrayerRepository({
    required this.database,
    required String ownerId,
    required String deviceId,
    required this.assetStore,
    this.soundscapePreferences,
    DateTime Function()? now,
    Uuid? uuid,
  }) : ownerId = _requiredText(ownerId, 'ownerId', 120),
       deviceId = _requiredText(deviceId, 'deviceId', 120),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final AudioAssetStore assetStore;
  final MemorySoundscapePreferences? soundscapePreferences;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Future<PersonalPrayer> create({
    required String title,
    required RecordedAudioDraft audio,
    PrayerPurpose purpose = PrayerPurpose.daily,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
  }) async {
    final normalizedTitle = _requiredText(title, 'title', 120);
    final prayerId = _uuid.v7();
    final revisionId = _uuid.v7();
    final tabletId = _uuid.v7();
    final audioId = _uuid.v7();
    final createdAt = _now().toUtc();
    final timestamp = createdAt.toIso8601String();

    // commitTemporary copies the draft. A rejected transaction can delete this
    // copy while leaving the original recording available for a retry.
    final committed = await assetStore.commitTemporary(
      TemporaryAudio(key: audio.temporaryKey, locator: audio.temporaryKey),
      assetId: audioId,
      mimeType: audio.mimeType,
    );

    try {
      final attachment = VoiceTabletAudio(
        id: audioId,
        kind: VoiceTabletAudioKind.fullPrayer,
        storageKey: committed.storageKey,
        mimeType: audio.mimeType,
        duration: audio.duration,
        byteSize: committed.byteSize,
        waveform: audio.waveform,
        createdAt: createdAt,
      );
      await database.writeTransaction((transaction) async {
        await transaction.execute(
          '''
          INSERT INTO personal_prayers(
            id, owner_id, title, style, reach, grounding, purpose,
            current_revision_id, created_at, updated_at, archived_at
          ) VALUES (?, ?, ?, 'situational', 'personal', ?, ?, ?, ?, ?, NULL)
          ''',
          [
            prayerId,
            ownerId,
            normalizedTitle,
            grounding.wireValue,
            purpose.wireValue,
            revisionId,
            timestamp,
            timestamp,
          ],
        );
        await transaction.execute(
          '''
          INSERT INTO personal_prayer_revisions(
            id, prayer_id, owner_id, body, content_format, action,
            created_at, device_id
          ) VALUES (?, ?, ?, '', 'audio', NULL, ?, ?)
          ''',
          [revisionId, prayerId, ownerId, timestamp, deviceId],
        );
        await transaction.execute(
          '''
          INSERT INTO voice_tablets(
            id, owner_id, source_type, personal_prayer_id, library_prayer_id,
            prayer_revision_id, title, full_audio_id, refrain_audio_id,
            recording_device_id, created_at, updated_at, archived_at
          ) VALUES (?, ?, 'personal_prayer', ?, NULL, ?, ?, ?, NULL, ?, ?, ?, NULL)
          ''',
          [
            tabletId,
            ownerId,
            prayerId,
            revisionId,
            normalizedTitle,
            audioId,
            deviceId,
            timestamp,
            timestamp,
          ],
        );
        await transaction.execute(
          '''
          INSERT INTO voice_tablet_audio_assets(
            id, owner_id, voice_tablet_id, audio_kind, storage_key, mime_type,
            duration_ms, byte_size, waveform_json, created_at
          ) VALUES (?, ?, ?, 'full_prayer', ?, ?, ?, ?, ?, ?)
          ''',
          [
            attachment.id,
            ownerId,
            tabletId,
            attachment.storageKey,
            attachment.mimeType,
            attachment.duration.inMilliseconds,
            attachment.byteSize,
            jsonEncode(attachment.waveform),
            timestamp,
          ],
        );
      });
    } catch (error, stackTrace) {
      try {
        await assetStore.delete(committed.storageKey);
      } catch (_) {
        // Startup private-audio cleanup retries orphan deletion.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    // Neither best-effort cleanup nor a sound preference may turn a successful
    // save into a retry that creates a duplicate prayer.
    try {
      await assetStore.discardTemporary(audio.temporaryKey);
    } catch (_) {
      // The durable, referenced audio is already saved.
    }
    try {
      await soundscapePreferences?.save(
        audioId,
        MemorySoundscapeSettings(
          soundscape: audio.soundscape,
          volume: audio.soundscapeVolume,
        ),
      );
    } catch (_) {
      // Playback still works; the background can be chosen again in the player.
    }
    return PersonalPrayer(
      id: prayerId,
      ownerId: ownerId,
      title: normalizedTitle,
      style: 'situational',
      reach: 'personal',
      grounding: grounding,
      purpose: purpose,
      currentRevisionId: revisionId,
      contentFormat: PersonalPrayerContentFormat.audio,
      body: '',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }
}

String _requiredText(String value, String name, int maximum) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.runes.length > maximum ||
      normalized.contains('\u0000')) {
    throw ArgumentError.value(value, name);
  }
  return normalized;
}
