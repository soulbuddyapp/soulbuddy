import 'dart:convert';

import '../domain/goal_meditation_plan.dart';

class GoalMeditationRepository {
  GoalMeditationRepository({required this.read, required this.write});

  static const plansKey = 'goal.meditation.plans.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  Future<void> _pending = Future.value();

  Future<List<GoalMeditationPlan>> loadPlans() async {
    await _pending;
    return _readPlans();
  }

  Future<List<GoalMeditationPlan>> _readPlans() async {
    final raw = await read(plansKey);
    if (raw == null) return const [];
    try {
      return List.unmodifiable(
        (jsonDecode(raw) as List).map(
          (item) => GoalMeditationPlan.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );
    } on Object {
      return const [];
    }
  }

  Future<GoalMeditationPlan?> loadPlan(String goalId) async {
    final plans = await loadPlans();
    for (final plan in plans) {
      if (plan.goalId == goalId) return plan;
    }
    return null;
  }

  Future<void> savePlan(GoalMeditationPlan plan) => _queue(() async {
    final plans = (await _readPlans())
        .where((item) => item.goalId != plan.goalId)
        .toList();
    plans.add(plan);
    await write(
      plansKey,
      jsonEncode(plans.map((item) => item.toJson()).toList()),
    );
  });

  Future<void> deletePlan(String goalId) => _queue(() async {
    final plans = (await _readPlans())
        .where((item) => item.goalId != goalId)
        .toList();
    await write(
      plansKey,
      jsonEncode(plans.map((item) => item.toJson()).toList()),
    );
  });

  String _entriesKey(String goalId) => 'goal.meditation.entries.v1.$goalId';
  String _draftKey(String goalId) => 'goal.meditation.draft.v1.$goalId';
  String _scriptureResponseKey(String goalId) =>
      'goal.meditation.scripture_response.v1.$goalId';

  Future<String?> loadScriptureResponseKey(String goalId) async {
    await _pending;
    final value = await read(_scriptureResponseKey(goalId));
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveScriptureResponseKey(String goalId, String key) =>
      _queue(() => write(_scriptureResponseKey(goalId), key));

  Future<String?> loadDraft(String goalId) async {
    await _pending;
    final draft = await read(_draftKey(goalId));
    return draft == null || draft.isEmpty ? null : draft;
  }

  Future<void> saveDraft(String goalId, String text) =>
      _queue(() => write(_draftKey(goalId), text));

  Future<void> clearDraft(String goalId) => saveDraft(goalId, '');

  Future<List<GoalMeditationEntry>> loadEntries(String goalId) async {
    await _pending;
    return _readEntries(goalId);
  }

  Future<List<GoalMeditationEntry>> _readEntries(String goalId) async {
    final raw = await read(_entriesKey(goalId));
    if (raw == null) return const [];
    try {
      return List.unmodifiable(
        (jsonDecode(raw) as List).map(
          (item) => GoalMeditationEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );
    } on Object {
      return const [];
    }
  }

  Future<void> addEntry(GoalMeditationEntry entry) => _queue(() async {
    final entries = await _readEntries(entry.goalId);
    await write(
      _entriesKey(entry.goalId),
      jsonEncode([...entries.map((item) => item.toJson()), entry.toJson()]),
    );
  });

  Future<void> _queue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.catchError((Object _) {});
    return result;
  }
}
