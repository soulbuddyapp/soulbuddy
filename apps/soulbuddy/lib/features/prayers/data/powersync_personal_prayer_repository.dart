import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/library_prayer.dart';
import '../domain/personal_prayer.dart';
import '../domain/prayer_generation_request.dart';
import 'personal_prayer_repository.dart';

class PowerSyncPersonalPrayerRepository implements PersonalPrayerRepository {
  PowerSyncPersonalPrayerRepository({
    required this.database,
    required this.ownerId,
    required this.deviceId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final String deviceId;
  final DateTime Function() _now;
  final Uuid _uuid;

  static const _projection = '''
    SELECT prayer.*, revision.body, revision.action
    FROM personal_prayers AS prayer
    JOIN personal_prayer_revisions AS revision
      ON revision.id = prayer.current_revision_id
     AND revision.prayer_id = prayer.id
     AND revision.owner_id = prayer.owner_id
  ''';

  @override
  Stream<List<PersonalPrayer>> watchAll() {
    return database
        .watch(
          '''
          $_projection
          WHERE prayer.owner_id = ? AND prayer.archived_at IS NULL
          ORDER BY prayer.updated_at DESC, prayer.id ASC
          ''',
          parameters: [ownerId],
        )
        .map((rows) => List.unmodifiable(rows.map(PersonalPrayer.fromRow)));
  }

  @override
  Stream<PersonalPrayer?> watch(String id) {
    return database
        .watch(
          '''
          $_projection
          WHERE prayer.id = ? AND prayer.owner_id = ?
          LIMIT 1
          ''',
          parameters: [id, ownerId],
        )
        .map(
          (rows) => rows.isEmpty ? null : PersonalPrayer.fromRow(rows.single),
        );
  }

  @override
  Future<PersonalPrayer> createOwnWords({
    required String title,
    required String body,
    String? action,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
    PrayerPurpose purpose = PrayerPurpose.daily,
  }) async {
    final normalizedTitle = _requiredText(title, 'title', 120);
    final normalizedBody = _requiredText(body, 'body', 4000);
    final normalizedAction = _optionalText(action, 'action', 1000);
    final normalizedDeviceId = _requiredText(deviceId, 'deviceId', 120);

    return database.writeTransaction((transaction) async {
      final prayerId = _uuid.v7();
      final revisionId = _uuid.v7();
      final timestamp = _now().toUtc().toIso8601String();
      await transaction.execute(
        '''
        INSERT INTO personal_prayers(
          id, owner_id, title, style, reach, grounding, purpose,
          current_revision_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          prayerId,
          ownerId,
          normalizedTitle,
          PrayerStyle.situational.wireValue,
          PrayerReach.personal.wireValue,
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
          id, prayer_id, owner_id, body, action, created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          prayerId,
          ownerId,
          normalizedBody,
          normalizedAction,
          timestamp,
          normalizedDeviceId,
        ],
      );

      return PersonalPrayer(
        id: prayerId,
        ownerId: ownerId,
        title: normalizedTitle,
        style: PrayerStyle.situational.wireValue,
        reach: PrayerReach.personal.wireValue,
        grounding: grounding,
        purpose: purpose,
        currentRevisionId: revisionId,
        body: normalizedBody,
        action: normalizedAction,
        createdAt: DateTime.parse(timestamp),
        updatedAt: DateTime.parse(timestamp),
      );
    });
  }

  @override
  Future<PersonalPrayer> accept({
    required String requestId,
    required String title,
    required String body,
    String? action,
  }) async {
    final normalizedTitle = _requiredText(title, 'title', 120);
    final normalizedBody = _requiredText(body, 'body', 4000);
    final normalizedAction = _optionalText(action, 'action', 1000);

    return database.writeTransaction((transaction) async {
      final request = await transaction.getOptional(
        '''
        SELECT * FROM prayer_generation_requests
        WHERE id = ? AND owner_id = ?
        LIMIT 1
        ''',
        [requestId, ownerId],
      );
      if (request == null ||
          request['status'] != PrayerGenerationStatus.ready.wireValue) {
        throw StateError('Prayer draft is not ready');
      }

      final legacyAcceptedPrayerId = request['accepted_prayer_id'] as String?;
      if (legacyAcceptedPrayerId != null) {
        final existing = await transaction.getOptional(
          '''
          $_projection
          WHERE prayer.id = ? AND prayer.owner_id = ?
          LIMIT 1
          ''',
          [legacyAcceptedPrayerId, ownerId],
        );
        if (existing == null) {
          throw StateError('Accepted prayer is unavailable');
        }
        return PersonalPrayer.fromRow(existing);
      }

      // New acceptance of a historical generated draft must not mutate the
      // retired request archive. Reusing the globally unique request id makes
      // acceptance idempotent without an accepted_prayer_id write-back.
      final existing = await transaction.getOptional(
        '''
        $_projection
        WHERE prayer.id = ? AND prayer.owner_id = ?
        LIMIT 1
        ''',
        [requestId, ownerId],
      );
      if (existing != null) {
        return PersonalPrayer.fromRow(existing);
      }

      final prayerId = requestId;
      final revisionId = _uuid.v7();
      final timestamp = _now().toUtc().toIso8601String();
      await transaction.execute(
        '''
        INSERT INTO personal_prayers(
          id, owner_id, title, style, reach, grounding, purpose,
          current_revision_id, created_at, updated_at, archived_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ''',
        [
          prayerId,
          ownerId,
          normalizedTitle,
          request['style'],
          request['reach'],
          request['grounding'],
          request['purpose'],
          revisionId,
          timestamp,
          timestamp,
        ],
      );
      await transaction.execute(
        '''
        INSERT INTO personal_prayer_revisions(
          id, prayer_id, owner_id, body, action, created_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          revisionId,
          prayerId,
          ownerId,
          normalizedBody,
          normalizedAction,
          timestamp,
          _requiredText(deviceId, 'deviceId', 120),
        ],
      );

      final contexts = await transaction.getAll(
        '''
        SELECT * FROM prayer_generation_contexts
        WHERE request_id = ?
        ORDER BY created_at ASC, id ASC
        ''',
        [requestId],
      );
      for (final context in contexts) {
        final type = PrayerContextType.fromWire(
          context['context_type'] as String,
        );
        await transaction.execute(
          '''
          INSERT INTO personal_prayer_links(
            id, prayer_id, owner_id, link_type, encounter_id, translation,
            book, chapter, first_verse, last_verse, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            _uuid.v7(),
            prayerId,
            ownerId,
            type.wireValue,
            type == PrayerContextType.encounter ? context['source_id'] : null,
            type == PrayerContextType.scripture ? context['translation'] : null,
            type == PrayerContextType.scripture ? context['book'] : null,
            type == PrayerContextType.scripture ? context['chapter'] : null,
            type == PrayerContextType.scripture ? context['first_verse'] : null,
            type == PrayerContextType.scripture ? context['last_verse'] : null,
            timestamp,
          ],
        );
      }

      return PersonalPrayer(
        id: prayerId,
        ownerId: ownerId,
        title: normalizedTitle,
        style: request['style'] as String,
        reach: request['reach'] as String,
        grounding: PrayerGrounding.fromWire(request['grounding'] as String),
        purpose: PrayerPurpose.fromWire(request['purpose'] as String),
        currentRevisionId: revisionId,
        body: normalizedBody,
        action: normalizedAction,
        createdAt: DateTime.parse(timestamp),
        updatedAt: DateTime.parse(timestamp),
      );
    });
  }
}

String _requiredText(String value, String name, int maximum) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must contain 1-$maximum characters',
    );
  }
  return normalized;
}

String? _optionalText(String? value, String name, int maximum) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must not exceed $maximum characters',
    );
  }
  return normalized;
}
