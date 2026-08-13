import 'dart:async';

import 'package:soulbuddy/features/record/data/encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

class InMemoryEncounterRepository implements EncounterRepository {
  InMemoryEncounterRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<Encounter> _items = [];
  final Map<String, List<MemoryReflection>> _reflections = {};
  final _changes = StreamController<List<Encounter>>.broadcast(sync: true);
  var _nextId = 1;
  EncounterDraft? lastDraft;

  @override
  Stream<List<Encounter>> watchAll() async* {
    yield List.unmodifiable(_items);
    yield* _changes.stream;
  }

  @override
  Future<Encounter> create(EncounterDraft draft) async {
    lastDraft = draft;
    final now = _now().toUtc();
    final id = 'encounter-${_nextId++}';
    final encounter = Encounter(
      id: id,
      ownerId: 'test-owner',
      title: draft.title.trim(),
      body: draft.body.trim(),
      occurredOn: draft.occurredOn,
      isAltar: draft.isAltar,
      createdAt: now,
      updatedAt: now,
      currentRevisionId: 'revision-$id',
      syncState: EncounterSyncState.pending,
      memoryType: draft.memoryType,
      sensitive: draft.sensitive,
      recallEnabled: draft.recallEnabled,
      recallPaused: draft.recallPaused,
      recallIntervalDays: draft.recallIntervalDays,
    );
    _items.insert(0, encounter);
    _emit();
    return encounter;
  }

  @override
  Future<void> markAsAltar(String encounterId, {required bool value}) async {
    final index = _items.indexWhere((item) => item.id == encounterId);
    if (index == -1) return;
    final current = _items[index];
    _items[index] = Encounter(
      id: current.id,
      ownerId: current.ownerId,
      title: current.title,
      body: current.body,
      occurredOn: current.occurredOn,
      isAltar: value,
      createdAt: current.createdAt,
      updatedAt: _now().toUtc(),
      currentRevisionId: current.currentRevisionId,
      syncState: current.syncState,
      memoryType: current.memoryType,
      sensitive: current.sensitive,
      recallEnabled: current.recallEnabled,
      recallPaused: current.recallPaused,
      recallIntervalDays: current.recallIntervalDays,
    );
    _emit();
  }

  @override
  Future<void> archive(String encounterId) async {
    _items.removeWhere((item) => item.id == encounterId);
    _emit();
  }

  @override
  Stream<List<MemoryReflection>> watchReflections(String encounterId) =>
      Stream.value(List.unmodifiable(_reflections[encounterId] ?? const []));

  @override
  Future<MemoryReflection> addReflection(
    String encounterId, {
    required String body,
    required String localDate,
  }) async {
    final reflection = MemoryReflection(
      id: 'reflection-${_nextId++}',
      encounterId: encounterId,
      ownerId: 'test-owner',
      body: body.trim(),
      localDate: localDate,
      createdAt: _now().toUtc(),
      deviceId: 'test-device',
    );
    _reflections.putIfAbsent(encounterId, () => []).insert(0, reflection);
    return reflection;
  }

  Future<void> close() => _changes.close();

  void _emit() => _changes.add(List.unmodifiable(_items));
}
