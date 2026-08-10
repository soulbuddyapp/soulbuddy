import 'dart:async';

import 'package:soulbuddy/features/record/data/encounter_repository.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';

class InMemoryEncounterRepository implements EncounterRepository {
  InMemoryEncounterRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<Encounter> _items = [];
  final _changes = StreamController<List<Encounter>>.broadcast(sync: true);
  var _nextId = 1;

  @override
  Stream<List<Encounter>> watchAll() async* {
    yield List.unmodifiable(_items);
    yield* _changes.stream;
  }

  @override
  Future<Encounter> create(EncounterDraft draft) async {
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
    );
    _emit();
  }

  @override
  Future<void> archive(String encounterId) async {
    _items.removeWhere((item) => item.id == encounterId);
    _emit();
  }

  Future<void> close() => _changes.close();

  void _emit() => _changes.add(List.unmodifiable(_items));
}
