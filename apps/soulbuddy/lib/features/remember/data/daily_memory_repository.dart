import '../domain/daily_memory.dart';

abstract interface class DailyMemoryRepository {
  Stream<DailyMemory?> watchForDate(DateTime localDate);

  Future<DailyMemory?> ensureForDate(DateTime localDate);

  Future<DailyMemory?> chooseAnother(
    DateTime localDate, {
    required String expectedEncounterId,
  });

  Future<void> setStatus(
    DateTime localDate, {
    required String expectedEncounterId,
    required DailyMemoryStatus status,
  });
}
