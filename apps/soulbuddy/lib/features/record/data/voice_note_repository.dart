import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

typedef VoiceNoteContext = ({String type, String id, String field});

class VoiceNoteLink {
  const VoiceNoteLink({required this.encounterId, required this.title});
  final String encounterId;
  final String title;
}

/// Links existing private audio memories to the activity where they were made.
/// No duplicate audio bytes, transcript, or second upload queue is introduced.
class VoiceNoteRepository {
  const VoiceNoteRepository({required this.database, required this.ownerId});
  final PowerSyncDatabase database;
  final String ownerId;

  Stream<List<VoiceNoteLink>> watch(VoiceNoteContext context) => database
      .watch(
        '''
        SELECT link.encounter_id, memory.title
        FROM voice_note_links AS link
        JOIN encounters AS memory ON memory.id = link.encounter_id
          AND memory.owner_id = link.owner_id
        WHERE link.owner_id = ? AND link.context_type = ?
          AND link.context_id = ? AND (link.field_key = ? OR ? = '*')
          AND memory.archived_at IS NULL
        ORDER BY link.created_at DESC, link.id DESC
        ''',
        parameters: [
          ownerId,
          context.type,
          context.id,
          context.field,
          context.field,
        ],
      )
      .map(
        (rows) => [
          for (final row in rows)
            VoiceNoteLink(
              encounterId: row['encounter_id'] as String,
              title: row['title'] as String,
            ),
        ],
      );

  Future<void> attach(VoiceNoteContext context, String encounterId) async {
    for (final value in [
      context.type,
      context.id,
      context.field,
      encounterId,
    ]) {
      if (value.trim().isEmpty || value.length > 160) {
        throw ArgumentError('Invalid recording context');
      }
    }
    await database.writeTransaction((tx) async {
      final memory = await tx.getOptional(
        '''
        SELECT memory.id FROM encounters AS memory
        JOIN memory_audio_assets AS audio ON audio.encounter_id = memory.id
          AND audio.owner_id = memory.owner_id
        WHERE memory.id = ? AND memory.owner_id = ?
          AND memory.archived_at IS NULL
        ''',
        [encounterId, ownerId],
      );
      if (memory == null) throw StateError('Recording is unavailable');
      final existing = await tx.getOptional(
        'SELECT id FROM voice_note_links WHERE owner_id = ? '
        'AND context_type = ? AND context_id = ? AND field_key = ? '
        'AND encounter_id = ?',
        [ownerId, context.type, context.id, context.field, encounterId],
      );
      if (existing != null) return;
      await tx.execute(
        'INSERT INTO voice_note_links '
        '(id, owner_id, context_type, context_id, field_key, encounter_id, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          const Uuid().v7(),
          ownerId,
          context.type,
          context.id,
          context.field,
          encounterId,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    });
  }

  Future<void> move({
    required String type,
    required String fromId,
    required String toId,
  }) => database.execute(
    'UPDATE voice_note_links SET context_id = ? '
    'WHERE owner_id = ? AND context_type = ? AND context_id = ?',
    [toId, ownerId, type, fromId],
  );
}
