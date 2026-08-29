import '../domain/prayer_generation_request.dart';

abstract interface class PrayerGenerationRepository {
  Stream<PrayerGenerationRequest?> watch(String id);
}
