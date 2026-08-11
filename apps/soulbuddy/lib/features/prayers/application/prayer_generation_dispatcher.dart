import 'package:uuid/uuid.dart';

import '../data/prayer_draft_api.dart';
import '../data/prayer_generation_repository.dart';
import '../domain/prayer_generation_request.dart';

class PrayerGenerationDispatcher {
  PrayerGenerationDispatcher({
    required this.repository,
    required this.api,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  static const retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  final PrayerGenerationRepository repository;
  final PrayerDraftApi api;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<void> dispatch(String requestId) async {
    final request = await repository.watch(requestId).first;
    if (request == null) return;
    final attemptId = _uuid.v7();
    final claimedAt = _now().toUtc();
    if (!await repository.claim(requestId, attemptId, claimedAt)) return;

    try {
      final draft = await api.generate(request, request.contexts, attemptId);
      await repository.storeDraft(requestId, attemptId, draft);
      try {
        await api.acknowledge(attemptId);
      } on PrayerDraftApiException {
        // The encrypted server replay expires independently. The local draft
        // is already durable and must remain available.
      }
    } on PrayerDraftSessionRequired {
      await repository.requireAttention(
        requestId,
        attemptId,
        'session_required',
      );
    } on PrayerDraftInvalidRequest {
      await repository.requireAttention(
        requestId,
        attemptId,
        'request_invalid',
      );
    } on PrayerDraftNeedsAttention {
      await repository.requireAttention(
        requestId,
        attemptId,
        'draft_needs_attention',
      );
    } on PrayerDraftRateLimited catch (error) {
      await _deferOrStop(
        request,
        attemptId,
        claimedAt,
        'rate_limited',
        minimumDelay: error.retryAfter,
      );
    } on PrayerDraftUnavailable {
      await _deferOrStop(
        request,
        attemptId,
        claimedAt,
        'temporarily_unavailable',
      );
    }
  }

  Future<void> dispatchPending() async {
    final requests = await repository.watchPending().first;
    for (final request in requests) {
      await dispatch(request.id);
    }
  }

  Future<void> _deferOrStop(
    PrayerGenerationRequest request,
    String attemptId,
    DateTime failedAt,
    String failureCode, {
    Duration? minimumDelay,
  }) async {
    final retryIndex = request.attemptCount;
    if (retryIndex >= retryDelays.length) {
      await repository.requireAttention(request.id, attemptId, failureCode);
      return;
    }
    final scheduled = retryDelays[retryIndex];
    final delay = minimumDelay != null && minimumDelay > scheduled
        ? minimumDelay
        : scheduled;
    await repository.defer(
      request.id,
      attemptId,
      nextAttemptAt: failedAt.add(delay),
      failureCode: failureCode,
    );
  }
}
