import '../domain/altar_ritual.dart';

abstract interface class AltarRitualRepository {
  Stream<AltarRitual?> watchForTarget(AltarTarget target);
  Stream<DueAltarRitual?> watchNextForDate(DateTime localDate, {DateTime? now});
  Stream<List<AltarReminderDelivery>> watchReminderDeliveries();
  Future<AltarRitual> save(AltarRitualDraft draft);
  Future<void> setPaused(String ritualId, bool paused);
  Future<void> snooze(String ritualId, DateTime until);
  Future<DateTime?> advance(String ritualId, {required DateTime afterUtc});
  Future<void> archive(String ritualId);
}
