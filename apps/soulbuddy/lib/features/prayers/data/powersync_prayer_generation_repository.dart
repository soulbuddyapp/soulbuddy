import 'package:powersync/powersync.dart';

import '../domain/library_prayer.dart';
import '../domain/prayer_generation_request.dart';
import '../domain/prayer_language.dart';
import 'prayer_generation_repository.dart';

class PowerSyncPrayerGenerationRepository
    implements PrayerGenerationRepository {
  const PowerSyncPrayerGenerationRepository({
    required this.database,
    required this.ownerId,
  });

  final PowerSyncDatabase database;
  final String ownerId;

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
  Stream<List<PrayerGenerationRequest>> watchPending() =>
      const Stream<List<PrayerGenerationRequest>>.empty();

  @override
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  }) async => throw _retired();

  @override
  Future<void> update(PrayerGenerationRequest request) async =>
      throw _retired();

  @override
  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  ) async => throw _retired();

  @override
  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  }) async => throw _retired();

  @override
  Future<bool> claim(String requestId, String attemptId, DateTime now) async =>
      throw _retired();

  @override
  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  ) async => throw _retired();

  @override
  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  }) async => throw _retired();

  @override
  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  ) async => throw _retired();

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
}

StateError _retired() => StateError(
  'Prayer generation is retired. Historical generation requests are read-only.',
);
