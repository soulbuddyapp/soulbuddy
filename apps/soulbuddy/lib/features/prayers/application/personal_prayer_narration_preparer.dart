import '../data/prayer_narration_repository.dart';
import '../domain/prayer_narration.dart';

/// The external narration boundary accepts only a saved prayer and immutable
/// revision. It cannot accept Commitment answers, declarations or session text.
class PersonalPrayerNarrationPreparer {
  const PersonalPrayerNarrationPreparer({
    required this.repository,
    required this.uploadPrerequisite,
  });
  final PrayerNarrationRepository repository;
  final Future<void> Function({
    required String personalPrayerId,
    required String revisionId,
  })
  uploadPrerequisite;
  Future<PrayerNarration> prepare({
    required String personalPrayerId,
    required String prayerRevisionId,
    required bool consent,
  }) async {
    if (!consent) throw const PrayerNarrationException('consent_required');
    try {
      await uploadPrerequisite(
        personalPrayerId: personalPrayerId,
        revisionId: prayerRevisionId,
      );
      final narration = await repository.prepare(
        personalPrayerId: personalPrayerId,
        prayerRevisionId: prayerRevisionId,
        consent: true,
      );
      if (narration.revisionId != prayerRevisionId ||
          narration.contentType != 'audio/mpeg' ||
          narration.bytes.isEmpty) {
        throw const PrayerNarrationException('narration_unavailable');
      }
      return narration;
    } catch (_) {
      throw const PrayerNarrationException('narration_unavailable');
    }
  }
}
