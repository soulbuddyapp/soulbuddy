import '../../prayers/domain/prayer_narration.dart';

abstract interface class CommitmentPersonalPrayerNarrationCacheRepository {
  Future<PrayerNarration?> load({
    required String commitmentId,
    required String deviceId,
    String? personalPrayerId,
    String? revisionId,
  });
  Future<void> save({
    required String commitmentId,
    required String personalPrayerId,
    required String deviceId,
    required PrayerNarration narration,
    required bool consent,
  });
  Future<void> clear({required String commitmentId, required String deviceId});
}
