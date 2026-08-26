import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/library_prayer.dart';
import '../domain/prayer_generation_request.dart';
import '../domain/prayer_language.dart';
import 'prayer_generation_repository.dart';

class PowerSyncPrayerGenerationRepository
    implements PrayerGenerationRepository {
  PowerSyncPrayerGenerationRepository({
    required this.database,
    required this.ownerId,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final DateTime Function() _now;
  final Uuid _uuid;

  static const _watchProjection = '''
    SELECT request.*,
      context.id AS joined_context_id,
      context.context_type AS joined_context_type,
      context.source_id AS joined_context_source_id,
      context.display_label AS joined_context_display_label,
      context.excerpt_snapshot AS joined_context_excerpt_snapshot,
      context.translation AS joined_context_translation,
      context.book AS joined_context_book,
      context.chapter AS joined_context_chapter,
      context.first_verse AS joined_context_first_verse,
      context.last_verse AS joined_context_last_verse
    FROM prayer_generation_requests AS request
    LEFT JOIN prayer_generation_contexts AS context
      ON context.request_id = request.id
  ''';

  @override
  Stream<PrayerGenerationRequest?> watch(String id) {
    return database
        .watch(
          '''
          $_watchProjection
          WHERE request.id = ? AND request.owner_id = ?
          ORDER BY context.created_at ASC, context.id ASC
          ''',
          parameters: [id, ownerId],
        )
        .map((rows) {
          final requests = _decodeWatchedRequests(rows);
          return requests.isEmpty ? null : requests.single;
        });
  }

  @override
  Stream<List<PrayerGenerationRequest>> watchPending() {
    return database
        .watch(
          '''
          $_watchProjection
          WHERE request.owner_id = ?
            AND request.status IN ('queued', 'generating')
          ORDER BY request.created_at ASC, request.id ASC,
            context.created_at ASC, context.id ASC
          ''',
          parameters: [ownerId],
        )
        .map(_decodeWatchedRequests);
  }

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  }) async {
    final normalizedText = _validatedRequestText(requestText);
    final id = _uuid.v7();
    final timestamp = _now().toUtc();
    final encodedTimestamp = timestamp.toIso8601String();
    await database.execute(
      '''
      INSERT INTO prayer_generation_requests(
        id, owner_id, style, reach, grounding, language_preference, purpose, request_text,
        beneficiary_choice, surrender_choice, responsibility_choice,
        alignment_choice, status, draft_title, draft_body, draft_action,
        generated_title, generated_body, generated_action, prompt_version,
        provider_disclosure_version, consented_provider,
        consented_disclosure_version, active_attempt_id, attempt_started_at,
        next_attempt_at, attempt_count, last_attempt_at, failure_code,
        created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0,
        NULL, NULL, ?, ?
      )
      ''',
      [
        id,
        ownerId,
        style.wireValue,
        reach.wireValue,
        grounding.wireValue,
        (languagePreference ??
                (grounding == PrayerGrounding.catholic
                    ? PrayerLanguagePreference.catholic
                    : PrayerLanguagePreference.christian))
            .wireValue,
        purpose.wireValue,
        normalizedText,
        PrayerGenerationStatus.editing.wireValue,
        encodedTimestamp,
        encodedTimestamp,
      ],
    );
    return (await _load(id))!;
  }

  @override
  Future<void> update(PrayerGenerationRequest request) async {
    final normalizedText = _validatedRequestText(request.requestText);
    await database.execute(
      '''
      UPDATE prayer_generation_requests
      SET style = ?, reach = ?, grounding = ?, language_preference = ?, purpose = ?, request_text = ?,
          beneficiary_choice = ?, surrender_choice = ?,
          responsibility_choice = ?, alignment_choice = ?, draft_title = ?,
          draft_body = ?, draft_action = ?, updated_at = ?
      WHERE id = ? AND owner_id = ?
      ''',
      [
        request.style.wireValue,
        request.reach.wireValue,
        request.grounding.wireValue,
        request.languagePreference.wireValue,
        request.purpose.wireValue,
        normalizedText,
        _trimmedOrNull(request.beneficiaryChoice),
        _trimmedOrNull(request.surrenderChoice),
        _trimmedOrNull(request.responsibilityChoice),
        _trimmedOrNull(request.alignmentChoice),
        _trimmedOrNull(request.draftTitle),
        _trimmedOrNull(request.draftBody),
        _trimmedOrNull(request.draftAction),
        _now().toUtc().toIso8601String(),
        request.id,
        ownerId,
      ],
    );
  }

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) async {
    final normalizedContexts = contexts.map(_validateContext).toList();
    await database.writeTransaction((transaction) async {
      final parent = await transaction.getOptional(
        '''
        SELECT id FROM prayer_generation_requests
        WHERE id = ? AND owner_id = ?
        ''',
        [requestId, ownerId],
      );
      if (parent == null) {
        return;
      }
      await transaction.execute(
        'DELETE FROM prayer_generation_contexts WHERE request_id = ?',
        [requestId],
      );
      final timestamp = _now().toUtc().toIso8601String();
      for (final context in normalizedContexts) {
        await transaction.execute(
          '''
          INSERT INTO prayer_generation_contexts(
            id, request_id, context_type, source_id, display_label,
            excerpt_snapshot, translation, book, chapter, first_verse,
            last_verse, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            _uuid.v7(),
            requestId,
            context.type.wireValue,
            context.sourceId,
            context.displayLabel,
            context.excerptSnapshot,
            context.translation,
            context.book,
            context.chapter,
            context.firstVerse,
            context.lastVerse,
            timestamp,
          ],
        );
      }
      await transaction.execute(
        '''
        UPDATE prayer_generation_requests SET updated_at = ?
        WHERE id = ? AND owner_id = ?
        ''',
        [timestamp, requestId, ownerId],
      );
    });
  }

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async {
    final normalizedProvider = _requiredValue(provider, 'provider');
    final normalizedDisclosure = _requiredValue(
      disclosureVersion,
      'disclosureVersion',
    );
    await database.execute(
      '''
      UPDATE prayer_generation_requests
      SET status = ?, provider_disclosure_version = ?,
          consented_provider = ?, consented_disclosure_version = ?,
          active_attempt_id = NULL, attempt_started_at = NULL,
          next_attempt_at = NULL, failure_code = NULL, updated_at = ?
      WHERE id = ? AND owner_id = ? AND status IN (?, ?, ?)
      ''',
      [
        PrayerGenerationStatus.queued.wireValue,
        normalizedDisclosure,
        normalizedProvider,
        normalizedDisclosure,
        _now().toUtc().toIso8601String(),
        requestId,
        ownerId,
        PrayerGenerationStatus.editing.wireValue,
        PrayerGenerationStatus.ready.wireValue,
        PrayerGenerationStatus.needsAttention.wireValue,
      ],
    );
  }

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async {
    final normalizedAttemptId = _requiredValue(attemptId, 'attemptId');
    final claimedAt = now.toUtc();
    final expiredBefore = claimedAt.subtract(const Duration(seconds: 20));
    return database.writeTransaction((transaction) async {
      final eligible = await transaction.getOptional(
        '''
        SELECT id FROM prayer_generation_requests
        WHERE id = ? AND owner_id = ? AND (
          (status = ? AND (next_attempt_at IS NULL OR next_attempt_at <= ?))
          OR
          (status = ? AND attempt_started_at <= ?)
        )
        ''',
        [
          requestId,
          ownerId,
          PrayerGenerationStatus.queued.wireValue,
          claimedAt.toIso8601String(),
          PrayerGenerationStatus.generating.wireValue,
          expiredBefore.toIso8601String(),
        ],
      );
      if (eligible == null) {
        return false;
      }
      await transaction.execute(
        '''
        UPDATE prayer_generation_requests
        SET status = ?, active_attempt_id = ?, attempt_started_at = ?,
            next_attempt_at = NULL, attempt_count = attempt_count + 1,
            last_attempt_at = ?, failure_code = NULL, updated_at = ?
        WHERE id = ? AND owner_id = ? AND (
          (status = ? AND (next_attempt_at IS NULL OR next_attempt_at <= ?))
          OR
          (status = ? AND attempt_started_at <= ?)
        )
        ''',
        [
          PrayerGenerationStatus.generating.wireValue,
          normalizedAttemptId,
          claimedAt.toIso8601String(),
          claimedAt.toIso8601String(),
          claimedAt.toIso8601String(),
          requestId,
          ownerId,
          PrayerGenerationStatus.queued.wireValue,
          claimedAt.toIso8601String(),
          PrayerGenerationStatus.generating.wireValue,
          expiredBefore.toIso8601String(),
        ],
      );
      return true;
    });
  }

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async {
    await database.execute(
      '''
      UPDATE prayer_generation_requests
      SET status = ?, draft_title = ?, draft_body = ?, draft_action = ?,
          generated_title = ?, generated_body = ?, generated_action = ?,
          prompt_version = ?, active_attempt_id = NULL,
          attempt_started_at = NULL, next_attempt_at = NULL,
          failure_code = NULL, updated_at = ?
      WHERE id = ? AND owner_id = ? AND status = ?
        AND active_attempt_id = ?
      ''',
      [
        PrayerGenerationStatus.ready.wireValue,
        _requiredValue(draft.title, 'draft.title'),
        _requiredValue(draft.body, 'draft.body'),
        _trimmedOrNull(draft.action),
        _requiredValue(draft.title, 'draft.title'),
        _requiredValue(draft.body, 'draft.body'),
        _trimmedOrNull(draft.action),
        _requiredValue(draft.promptVersion, 'draft.promptVersion'),
        _now().toUtc().toIso8601String(),
        requestId,
        ownerId,
        PrayerGenerationStatus.generating.wireValue,
        attemptId,
      ],
    );
  }

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async {
    await database.execute(
      '''
      UPDATE prayer_generation_requests
      SET status = ?, active_attempt_id = NULL, attempt_started_at = NULL,
          next_attempt_at = ?, failure_code = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND status = ?
        AND active_attempt_id = ?
      ''',
      [
        PrayerGenerationStatus.queued.wireValue,
        nextAttemptAt.toUtc().toIso8601String(),
        _trimmedOrNull(failureCode),
        _now().toUtc().toIso8601String(),
        requestId,
        ownerId,
        PrayerGenerationStatus.generating.wireValue,
        attemptId,
      ],
    );
  }

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async {
    await database.execute(
      '''
      UPDATE prayer_generation_requests
      SET status = ?, active_attempt_id = NULL, attempt_started_at = NULL,
          next_attempt_at = NULL, failure_code = ?, updated_at = ?
      WHERE id = ? AND owner_id = ? AND status = ?
        AND active_attempt_id = ?
      ''',
      [
        PrayerGenerationStatus.needsAttention.wireValue,
        _requiredValue(failureCode, 'failureCode'),
        _now().toUtc().toIso8601String(),
        requestId,
        ownerId,
        PrayerGenerationStatus.generating.wireValue,
        attemptId,
      ],
    );
  }

  Future<PrayerGenerationRequest?> _load(String id) async {
    final row = await database.getOptional(
      '''
      SELECT * FROM prayer_generation_requests
      WHERE id = ? AND owner_id = ?
      LIMIT 1
      ''',
      [id, ownerId],
    );
    if (row == null) {
      return null;
    }
    final contextRows = await database.getAll(
      '''
      SELECT * FROM prayer_generation_contexts
      WHERE request_id = ?
      ORDER BY created_at ASC, id ASC
      ''',
      [id],
    );
    return PrayerGenerationRequest.fromRow(
      row,
      contexts: contextRows
          .map(PrayerGenerationContext.fromRow)
          .toList(growable: false),
    );
  }

  List<PrayerGenerationRequest> _decodeWatchedRequests(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final requestRows = <String, Map<String, dynamic>>{};
    final contexts = <String, List<PrayerGenerationContext>>{};
    for (final row in rows) {
      final requestId = row['id'] as String;
      requestRows.putIfAbsent(requestId, () => row);
      final contextId = row['joined_context_id'] as String?;
      if (contextId == null) continue;
      contexts
          .putIfAbsent(requestId, () => [])
          .add(
            PrayerGenerationContext.fromRow({
              'context_type': row['joined_context_type'],
              'source_id': row['joined_context_source_id'],
              'display_label': row['joined_context_display_label'],
              'excerpt_snapshot': row['joined_context_excerpt_snapshot'],
              'translation': row['joined_context_translation'],
              'book': row['joined_context_book'],
              'chapter': row['joined_context_chapter'],
              'first_verse': row['joined_context_first_verse'],
              'last_verse': row['joined_context_last_verse'],
            }),
          );
    }
    return List.unmodifiable([
      for (final entry in requestRows.entries)
        PrayerGenerationRequest.fromRow(
          entry.value,
          contexts: List.unmodifiable(contexts[entry.key] ?? const []),
        ),
    ]);
  }

  String _validatedRequestText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'requestText', 'must not be empty');
    }
    if (normalized.runes.length > 500) {
      throw ArgumentError.value(
        value,
        'requestText',
        'must not exceed 500 Unicode characters',
      );
    }
    return normalized;
  }

  PrayerGenerationContext _validateContext(PrayerGenerationContext context) {
    _requiredValue(context.sourceId, 'context.sourceId');
    _requiredValue(context.displayLabel, 'context.displayLabel');
    _requiredValue(context.excerptSnapshot, 'context.excerptSnapshot');
    if (context.type == PrayerContextType.scripture) {
      _requiredValue(context.translation ?? '', 'context.translation');
      _requiredValue(context.book ?? '', 'context.book');
      if (context.chapter == null ||
          context.firstVerse == null ||
          context.lastVerse == null ||
          context.chapter! < 1 ||
          context.firstVerse! < 1 ||
          context.lastVerse! < context.firstVerse!) {
        throw ArgumentError.value(context, 'context', 'invalid verse range');
      }
    }
    return context;
  }
}

String _requiredValue(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

String? _trimmedOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
