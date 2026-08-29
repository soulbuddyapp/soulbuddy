import '../domain/legacy_circle.dart';

abstract interface class LegacyCircleMigrationRepository {
  Future<List<LegacyCircleSummary>> list();

  Future<LegacyCircleArchive?> read(String circleId);

  Future<void> discard(String circleId);
}
