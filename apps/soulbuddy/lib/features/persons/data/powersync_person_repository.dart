import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/person_prayer_occurrence.dart';
import '../domain/prayer_person.dart';
import 'person_repository.dart';

class PowerSyncPersonRepository implements PersonRepository {
  PowerSyncPersonRepository({
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

  @override
  Stream<List<PrayerPerson>> watchActive() => database
      .watch(
        '''
        SELECT * FROM prayer_people
        WHERE owner_id = ? AND archived_at IS NULL
        ORDER BY name COLLATE NOCASE ASC, created_at ASC
        ''',
        parameters: [ownerId],
      )
      .map((rows) => List.unmodifiable(rows.map(PrayerPerson.fromRow)));

  @override
  Stream<List<PrayerPerson>> watchForReminders() => database
      .watch(
        '''
        SELECT * FROM prayer_people
        WHERE owner_id = ?
        ORDER BY updated_at ASC, id ASC
        ''',
        parameters: [ownerId],
      )
      .map((rows) => List.unmodifiable(rows.map(PrayerPerson.fromRow)));

  @override
  Stream<PrayerPerson?> watch(String id) => database
      .watch(
        'SELECT * FROM prayer_people WHERE id = ? AND owner_id = ? LIMIT 1',
        parameters: [id, ownerId],
      )
      .map((rows) => rows.isEmpty ? null : PrayerPerson.fromRow(rows.single));

  @override
  Stream<List<DuePersonPrayer>> watchDue(DateTime localDate) {
    final dateKey = personPrayerLocalDateKey(localDate);
    return database
        .watch(
          '''
          SELECT person.*,
            EXISTS(
              SELECT 1 FROM person_prayer_occurrences AS occurrence
              WHERE occurrence.owner_id = person.owner_id
                AND occurrence.person_id = person.id
                AND occurrence.occurrence_key = person.id || ':' || ?
            ) AS already_prayed
          FROM prayer_people AS person
          WHERE person.owner_id = ? AND person.archived_at IS NULL
          ORDER BY person.name COLLATE NOCASE ASC, person.created_at ASC
          ''',
          parameters: [dateKey, ownerId],
        )
        .map((rows) {
          final due = <DuePersonPrayer>[];
          for (final row in rows) {
            final person = PrayerPerson.fromRow(row);
            if (row['already_prayed'] == 1 ||
                !person.isScheduledOn(localDate)) {
              continue;
            }
            due.add(
              DuePersonPrayer(
                person: person,
                occurrenceKey: '${person.id}:$dateKey',
              ),
            );
          }
          return List.unmodifiable(due);
        });
  }

  @override
  Future<PrayerPerson> create(PrayerPersonDraft draft) async {
    final id = _uuid.v7();
    final timestamp = _now().toUtc().toIso8601String();
    final values = _normalizeDraft(draft);
    await database.execute(
      '''
      INSERT INTO prayer_people(
        id, owner_id, name, relationship, cadence, local_time, timezone,
        weekdays_mask, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [id, ownerId, ...values, timestamp, timestamp],
    );
    return (await watch(id).first)!;
  }

  @override
  Future<PrayerPerson> update(String id, PrayerPersonDraft draft) async {
    await _requireOwned(id);
    final timestamp = _now().toUtc().toIso8601String();
    final values = _normalizeDraft(draft);
    await database.execute(
      '''
      UPDATE prayer_people
      SET name = ?, relationship = ?, cadence = ?, local_time = ?,
          timezone = ?, weekdays_mask = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [...values, timestamp, id, ownerId],
    );
    return (await watch(id).first)!;
  }

  @override
  Future<void> archive(String id) async {
    await _requireOwned(id);
    final timestamp = _now().toUtc().toIso8601String();
    await database.execute(
      '''
      UPDATE prayer_people SET archived_at = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND archived_at IS NULL
      ''',
      [timestamp, timestamp, id, ownerId],
    );
  }

  @override
  Future<PersonPrayerOccurrence?> recordPrayer(
    String personId, {
    required DateTime localDate,
  }) async {
    await _requireOwned(personId);
    final dateKey = personPrayerLocalDateKey(localDate);
    final occurrenceKey = '$personId:$dateKey';
    final existing = await database.getOptional(
      '''
      SELECT id FROM person_prayer_occurrences
      WHERE owner_id = ? AND occurrence_key = ? LIMIT 1
      ''',
      [ownerId, occurrenceKey],
    );
    if (existing != null) return null;

    final occurrence = PersonPrayerOccurrence(
      id: _uuid.v7(),
      personId: personId,
      ownerId: ownerId,
      localDate: dateKey,
      occurrenceKey: occurrenceKey,
      prayedAt: _now().toUtc(),
      deviceId: deviceId.trim(),
    );
    await database.execute(
      '''
      INSERT INTO person_prayer_occurrences(
        id, person_id, owner_id, local_date, occurrence_key, prayed_at,
        device_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        occurrence.id,
        occurrence.personId,
        occurrence.ownerId,
        occurrence.localDate,
        occurrence.occurrenceKey,
        occurrence.prayedAt.toIso8601String(),
        occurrence.deviceId,
      ],
    );
    return occurrence;
  }

  List<Object?> _normalizeDraft(PrayerPersonDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty || name.length > 120) {
      throw ArgumentError.value(draft.name, 'name', 'must be 1-120 characters');
    }
    final relationship = draft.relationship?.trim();
    if (relationship != null && relationship.length > 80) {
      throw ArgumentError.value(
        draft.relationship,
        'relationship',
        'must be at most 80 characters',
      );
    }
    final localTime = draft.localTime?.trim();
    if (localTime != null &&
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(localTime)) {
      throw ArgumentError.value(draft.localTime, 'localTime', 'must be HH:mm');
    }
    if (draft.weekdaysMask < 0 || draft.weekdaysMask > 127) {
      throw ArgumentError.value(draft.weekdaysMask, 'weekdaysMask');
    }
    if (draft.cadence != PersonPrayerCadence.daily && draft.weekdaysMask == 0) {
      throw ArgumentError.value(
        draft.weekdaysMask,
        'weekdaysMask',
        'choose at least one day',
      );
    }
    return [
      name,
      relationship == null || relationship.isEmpty ? null : relationship,
      draft.cadence.wireValue,
      localTime == null || localTime.isEmpty ? null : localTime,
      draft.timezone?.trim(),
      draft.weekdaysMask,
    ];
  }

  Future<void> _requireOwned(String id) async {
    final row = await database.getOptional(
      'SELECT id FROM prayer_people WHERE id = ? AND owner_id = ? '
      'AND archived_at IS NULL',
      [id, ownerId],
    );
    if (row == null) throw StateError('Person is not available');
  }
}
