import 'package:powersync/powersync.dart';

class AppFeedbackPreferences {
  const AppFeedbackPreferences({
    required this.hapticsEnabled,
    required this.soundsEnabled,
    required this.reducedMotion,
  });

  static const defaults = AppFeedbackPreferences(
    hapticsEnabled: true,
    soundsEnabled: true,
    reducedMotion: false,
  );

  final bool hapticsEnabled;
  final bool soundsEnabled;
  final bool reducedMotion;

  AppFeedbackPreferences copyWith({
    bool? hapticsEnabled,
    bool? soundsEnabled,
    bool? reducedMotion,
  }) => AppFeedbackPreferences(
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  @override
  bool operator ==(Object other) =>
      other is AppFeedbackPreferences &&
      other.hapticsEnabled == hapticsEnabled &&
      other.soundsEnabled == soundsEnabled &&
      other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(hapticsEnabled, soundsEnabled, reducedMotion);
}

abstract interface class AppFeedbackPreferencesRepository {
  Stream<AppFeedbackPreferences> watch();

  Future<void> save(AppFeedbackPreferences preferences);

  Future<void> setHapticsEnabled(bool value);

  Future<void> setSoundsEnabled(bool value);

  Future<void> setReducedMotion(bool value);
}

class PowerSyncAppFeedbackPreferencesRepository
    implements AppFeedbackPreferencesRepository {
  const PowerSyncAppFeedbackPreferencesRepository(this._database);

  final PowerSyncDatabase _database;

  @override
  Stream<AppFeedbackPreferences> watch() => _database
      .watch('''
        SELECT id, bool_value
        FROM app_preferences
        WHERE id IN (?, ?, ?)
        ''', parameters: _keys)
      .map(_preferencesFromRows);

  @override
  Future<void> save(AppFeedbackPreferences preferences) =>
      _database.writeTransaction((transaction) async {
        Future<void> setValue(String key, bool value) async {
          final existing = await transaction.getOptional(
            'SELECT id FROM app_preferences WHERE id = ?',
            [key],
          );
          if (existing == null) {
            await transaction.execute(
              'INSERT INTO app_preferences(id, bool_value) VALUES (?, ?)',
              [key, value ? 1 : 0],
            );
            return;
          }
          await transaction.execute(
            'UPDATE app_preferences SET bool_value = ? WHERE id = ?',
            [value ? 1 : 0, key],
          );
        }

        await setValue(_hapticsKey, preferences.hapticsEnabled);
        await setValue(_soundsKey, preferences.soundsEnabled);
        await setValue(_reducedMotionKey, preferences.reducedMotion);
      });

  @override
  Future<void> setHapticsEnabled(bool value) =>
      _updatePreference((current) => current.copyWith(hapticsEnabled: value));

  @override
  Future<void> setSoundsEnabled(bool value) =>
      _updatePreference((current) => current.copyWith(soundsEnabled: value));

  @override
  Future<void> setReducedMotion(bool value) =>
      _updatePreference((current) => current.copyWith(reducedMotion: value));

  Future<void> _updatePreference(
    AppFeedbackPreferences Function(AppFeedbackPreferences) update,
  ) async {
    final current = await watch().first;
    await save(update(current));
  }
}

const _hapticsKey = 'haptics_enabled';
const _soundsKey = 'sounds_enabled';
const _reducedMotionKey = 'reduced_motion';
const _keys = [_hapticsKey, _soundsKey, _reducedMotionKey];

AppFeedbackPreferences _preferencesFromRows(List<Map<String, dynamic>> rows) {
  final values = <String, bool>{
    for (final row in rows)
      row['id'] as String: (row['bool_value'] as int) == 1,
  };
  return AppFeedbackPreferences(
    hapticsEnabled: values[_hapticsKey] ?? true,
    soundsEnabled: values[_soundsKey] ?? true,
    reducedMotion: values[_reducedMotionKey] ?? false,
  );
}
