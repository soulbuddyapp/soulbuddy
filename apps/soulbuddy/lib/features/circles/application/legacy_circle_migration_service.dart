import '../../record/data/encounter_repository.dart';
import '../../record/domain/encounter.dart';
import '../../record/domain/encounter_draft.dart';
import '../data/legacy_circle_migration_repository.dart';
import '../domain/legacy_circle.dart';

class LegacyCircleMigrationService {
  const LegacyCircleMigrationService({
    required this.legacyRepository,
    required this.encounterRepository,
  });

  final LegacyCircleMigrationRepository legacyRepository;
  final EncounterRepository encounterRepository;

  Future<Encounter?> keepAsPrivateRecord(String circleId) async {
    final archive = await legacyRepository.read(circleId);
    if (archive == null) return null;
    final encounter = await encounterRepository.create(
      EncounterDraft(
        title: 'Circle: ${archive.summary.name}',
        body: formatForCopy(archive),
        occurredOn: _dateKey(_latestDate(archive)),
        isAltar: false,
        memoryType: MemoryType.encounter,
        sensitive: true,
        recallEnabled: false,
      ),
    );
    await legacyRepository.discard(circleId);
    return encounter;
  }

  Future<String?> copyText(String circleId) async {
    final archive = await legacyRepository.read(circleId);
    return archive == null ? null : formatForCopy(archive);
  }

  String formatForCopy(LegacyCircleArchive archive) {
    final buffer = StringBuffer('Circle: ${archive.summary.name}');
    if (archive.messages.isEmpty) {
      return buffer.toString();
    }
    for (final message in archive.messages) {
      buffer
        ..write('\n\n')
        ..write(_dateKey(message.createdAt))
        ..write('\n')
        ..write(message.body);
    }
    return buffer.toString();
  }

  DateTime _latestDate(LegacyCircleArchive archive) =>
      archive.messages.isEmpty
      ? archive.summary.updatedAt
      : archive.messages.last.createdAt;
}

String _dateKey(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
