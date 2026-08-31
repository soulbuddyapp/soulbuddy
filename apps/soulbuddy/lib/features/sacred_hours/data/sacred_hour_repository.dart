import '../domain/sacred_hour.dart';

abstract interface class SacredHourRepository {
  Stream<List<SacredHour>> watchAll();
  Stream<List<SacredHour>> watchActive();
  Stream<SacredHour?> watch(String id);
  Stream<SacredHour?> watchCurrentOrNext(DateTime nowUtc);
  Stream<List<SacredHourDelivery>> watchDeliveries();
  Future<List<SacredHour>> ensureDefaults({required String timezone});
  Future<SacredHour> save(SacredHourDraft draft, {String? id});
  Future<void> setEnabled(String id, bool enabled);
  Future<void> archive(String id);
  Future<void> updateDeviceDelivery(String id, SacredHourDeviceDraft draft);
  Future<void> markOccurrence(
    String id,
    DateTime dueAt,
    SacredHourOccurrenceStatus status,
  );
}
