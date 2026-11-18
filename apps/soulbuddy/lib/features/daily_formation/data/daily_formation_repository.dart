import 'dart:convert';

import '../domain/formation_progress.dart';
import '../domain/formation_profile.dart';

class DailyFormationRepository {
  DailyFormationRepository({required this.read, required this.write});

  static const storageKey = 'daily-formation.progress.v2';
  static const profileStorageKey = 'daily-formation.profile.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  Future<FormationProgress> load() async {
    try {
      final raw = await read(storageKey);
      if (raw == null) return const FormationProgress.initial();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const FormationProgress.initial();
      return FormationProgress.fromJson(decoded);
    } catch (_) {
      return const FormationProgress.initial();
    }
  }

  Future<FormationProgress> _loadForUpdate() async {
    final raw = await read(storageKey);
    if (raw == null) return const FormationProgress.initial();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid formation progress');
    }
    return FormationProgress.fromJson(decoded);
  }

  Future<void> select({required int day, required String videoId}) async {
    final current = await _loadForUpdate();
    if (current.currentDay != day) return;
    await _save(current.select(videoId));
  }

  Future<void> complete(FormationCompletion completion) async {
    final current = await _loadForUpdate();
    if (completion.day > current.currentDay) return;
    await _save(current.addCompletion(completion));
  }

  Future<FormationProfile> loadProfile() async {
    try {
      final raw = await read(profileStorageKey);
      if (raw == null) return const FormationProfile.initial();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const FormationProfile.initial();
      return FormationProfile.fromJson(decoded);
    } catch (_) {
      return const FormationProfile.initial();
    }
  }

  Future<void> saveProfile(FormationProfile profile) =>
      write(profileStorageKey, jsonEncode(profile.toJson()));

  Future<void> _save(FormationProgress progress) =>
      write(storageKey, jsonEncode(progress.toJson()));
}
