import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/circles/application/legacy_circle_migration_service.dart';
import 'package:soulbuddy/features/circles/data/legacy_circle_migration_repository.dart';
import 'package:soulbuddy/features/circles/domain/legacy_circle.dart';
import 'package:soulbuddy/features/record/data/encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

void main() {
  test('failed Record creation never deletes legacy Circle messages', () async {
    final legacy = _FakeLegacyRepository(_archive());
    final encounters = _FakeEncounterRepository(failCreate: true);
    final service = LegacyCircleMigrationService(
      legacyRepository: legacy,
      encounterRepository: encounters,
    );

    await expectLater(
      service.keepAsPrivateRecord('legacy-circle-1'),
      throwsA(isA<StateError>()),
    );

    expect(legacy.discardCount, 0);
    expect(legacy.archive, isNotNull);
  });

  test('Copy returns a complete export without mutating legacy data', () async {
    final legacy = _FakeLegacyRepository(_archive());
    final service = LegacyCircleMigrationService(
      legacyRepository: legacy,
      encounterRepository: _FakeEncounterRepository(),
    );

    final text = await service.copyText('legacy-circle-1');

    expect(text, startsWith('Circle: Old accountability'));
    expect(text, contains('2026-08-12\nPlease pray for wisdom.'));
    expect(text, contains('I will check in tomorrow.'));
    expect(legacy.discardCount, 0);
    expect(legacy.archive, isNotNull);
  });

  test('successful Keep creates a sensitive non-recalled Record then discards once', () async {
    final legacy = _FakeLegacyRepository(_archive());
    final encounters = _FakeEncounterRepository();
    final service = LegacyCircleMigrationService(
      legacyRepository: legacy,
      encounterRepository: encounters,
    );

    final record = await service.keepAsPrivateRecord('legacy-circle-1');

    expect(record?.id, 'record-1');
    expect(encounters.lastDraft?.sensitive, isTrue);
    expect(encounters.lastDraft?.recallEnabled, isFalse);
    expect(encounters.lastDraft?.body, contains('Please pray for wisdom.'));
    expect(legacy.discardCount, 1);
    expect(legacy.archive, isNull);
  });
}

LegacyCircleArchive _archive() => LegacyCircleArchive(
  summary: LegacyCircleSummary(
    id: 'legacy-circle-1',
    name: 'Old accountability',
    messageCount: 2,
    updatedAt: DateTime.utc(2026, 8, 12, 8, 2),
  ),
  messages: [
    LegacyCircleMessage(
      id: 'message-1',
      body: 'Please pray for wisdom.',
      createdAt: DateTime.utc(2026, 8, 12, 8, 1),
    ),
    LegacyCircleMessage(
      id: 'message-2',
      body: 'I will check in tomorrow.',
      createdAt: DateTime.utc(2026, 8, 12, 8, 2),
    ),
  ],
);

class _FakeLegacyRepository implements LegacyCircleMigrationRepository {
  _FakeLegacyRepository(this.archive);

  LegacyCircleArchive? archive;
  var discardCount = 0;

  @override
  Future<void> discard(String circleId) async {
    if (archive?.summary.id != circleId) return;
    discardCount += 1;
    archive = null;
  }

  @override
  Future<List<LegacyCircleSummary>> list() async =>
      archive == null ? const [] : [archive!.summary];

  @override
  Future<LegacyCircleArchive?> read(String circleId) async =>
      archive?.summary.id == circleId ? archive : null;
}

class _FakeEncounterRepository implements EncounterRepository {
  _FakeEncounterRepository({this.failCreate = false});

  final bool failCreate;
  EncounterDraft? lastDraft;

  @override
  Future<Encounter> create(EncounterDraft draft) async {
    lastDraft = draft;
    if (failCreate) throw StateError('record unavailable');
    return Encounter(
      id: 'record-1',
      ownerId: 'owner-1',
      title: draft.title,
      body: draft.body,
      occurredOn: draft.occurredOn,
      isAltar: draft.isAltar,
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
      currentRevisionId: 'revision-1',
      syncState: EncounterSyncState.pending,
      memoryType: draft.memoryType,
      sensitive: draft.sensitive,
      recallEnabled: draft.recallEnabled,
      recallPaused: draft.recallPaused,
      recallIntervalDays: draft.recallIntervalDays,
    );
  }

  @override
  Future<MemoryReflection> addReflection(
    String encounterId, {
    required String body,
    required String localDate,
  }) => throw UnimplementedError();

  @override
  Future<void> archive(String encounterId) async {}

  @override
  Future<void> markAsAltar(String encounterId, {required bool value}) async {}

  @override
  Stream<List<Encounter>> watchAll() => const Stream.empty();

  @override
  Stream<List<MemoryReflection>> watchReflections(String encounterId) =>
      const Stream.empty();
}
