import 'dart:convert';

import '../domain/formation_reading.dart';

class FormationProgress {
  const FormationProgress(this.completedIds);

  final Set<String> completedIds;

  FormationReading next(List<FormationReading> readings) => readings.firstWhere(
    (reading) => !completedIds.contains(reading.id),
    orElse: () => readings.first,
  );
}

class FormationProgressRepository {
  FormationProgressRepository({required this.read, required this.write});

  static const storageKey = 'formation.readings.progress.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  Future<FormationProgress> load() async {
    try {
      final value = jsonDecode(await read(storageKey) ?? '[]');
      if (value is! List) return const FormationProgress({});
      return FormationProgress(value.whereType<String>().toSet());
    } catch (_) {
      return const FormationProgress({});
    }
  }

  Future<void> complete(String id) async {
    final current = await load();
    await write(storageKey, jsonEncode({...current.completedIds, id}.toList()));
  }
}
