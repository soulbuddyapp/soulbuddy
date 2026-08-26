import '../domain/library_prayer.dart';
import '../domain/prayer_generation_request.dart';
import '../domain/prayer_language.dart';

abstract interface class PrayerGenerationRepository {
  Stream<PrayerGenerationRequest?> watch(String id);
  Stream<List<PrayerGenerationRequest>> watchPending();

  Future<PrayerGenerationRequest> create({
    required PrayerStyle style,
    required PrayerReach reach,
    required PrayerGrounding grounding,
    required PrayerPurpose purpose,
    PrayerLanguagePreference? languagePreference,
    required String requestText,
  });

  Future<void> update(PrayerGenerationRequest request);

  Future<void> replaceContexts(
    String requestId,
    List<PrayerGenerationContext> contexts,
  );

  Future<void> queue(
    String requestId, {
    required String provider,
    required String disclosureVersion,
  });

  Future<bool> claim(String requestId, String attemptId, DateTime now);

  Future<void> storeDraft(
    String requestId,
    String attemptId,
    PrayerGeneratedDraft draft,
  );

  Future<void> defer(
    String requestId,
    String attemptId, {
    required DateTime nextAttemptAt,
    String? failureCode,
  });

  Future<void> requireAttention(
    String requestId,
    String attemptId,
    String failureCode,
  );
}
