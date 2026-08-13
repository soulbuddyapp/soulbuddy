import '../domain/prayer_narration.dart';

abstract interface class PrayerNarrationRepository {
  Future<PrayerNarration> prepare({
    required String personalPrayerId,
    required String prayerRevisionId,
    required bool consent,
  });
}

class PrayerNarrationException implements Exception {
  const PrayerNarrationException(this.code);

  final String code;
}
