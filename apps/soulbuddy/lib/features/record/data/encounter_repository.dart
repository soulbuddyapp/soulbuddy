import '../domain/encounter.dart';
import '../domain/encounter_draft.dart';

abstract interface class EncounterRepository {
  Stream<List<Encounter>> watchAll();

  Future<Encounter> create(EncounterDraft draft);

  Future<void> markAsAltar(String encounterId, {required bool value});

  Future<void> archive(String encounterId);

  Stream<List<MemoryReflection>> watchReflections(String encounterId);

  Future<MemoryReflection> addReflection(
    String encounterId, {
    required String body,
    required String localDate,
  });
}
