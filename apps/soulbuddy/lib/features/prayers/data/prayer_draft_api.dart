import '../domain/prayer_generation_request.dart';

abstract interface class PrayerDraftApi {
  Future<PrayerGeneratedDraft> generate(
    PrayerGenerationRequest request,
    List<PrayerGenerationContext> contexts,
    String attemptId,
  );

  Future<void> acknowledge(String attemptId);
}

sealed class PrayerDraftApiException implements Exception {
  const PrayerDraftApiException(this.safeMessage);

  final String safeMessage;

  @override
  String toString() => safeMessage;
}

final class PrayerDraftSessionRequired extends PrayerDraftApiException {
  const PrayerDraftSessionRequired()
    : super('Sign in is required to prepare this prayer draft.');
}

final class PrayerDraftInvalidRequest extends PrayerDraftApiException {
  const PrayerDraftInvalidRequest()
    : super('This prayer request needs attention before it can be prepared.');
}

final class PrayerDraftRateLimited extends PrayerDraftApiException {
  const PrayerDraftRateLimited([this.retryAfter])
    : super('Prayer drafting is busy just now.');

  final Duration? retryAfter;
}

final class PrayerDraftUnavailable extends PrayerDraftApiException {
  const PrayerDraftUnavailable()
    : super('Prayer drafting is temporarily unavailable.');
}

final class PrayerDraftNeedsAttention extends PrayerDraftApiException {
  const PrayerDraftNeedsAttention()
    : super('This prayer draft needs attention before it can be shown.');
}
