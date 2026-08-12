import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/feedback/app_feedback_preferences.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test('starts PowerSync when a backend connector is supplied', () async {
    final directory = await Directory.systemTemp.createTemp(
      'soulbuddy-connect-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final connector = _CredentialProbeConnector();
    final database = await openTestDatabase(
      '${directory.path}/soulbuddy.db',
      connector: connector,
    );
    addTearDown(database.close);

    for (
      var attempt = 0;
      attempt < 20 && connector.fetchCount == 0;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(connector.fetchCount, greaterThan(0));
  });

  test('persists device-local feedback preferences after reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'soulbuddy-feedback-preferences-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/soulbuddy.db';
    final firstDatabase = await openTestDatabase(path);
    final firstRepository = PowerSyncAppFeedbackPreferencesRepository(
      firstDatabase.powersync,
    );

    expect(
      await firstRepository.watch().first,
      AppFeedbackPreferences.defaults,
    );

    await firstRepository.save(
      AppFeedbackPreferences.defaults.copyWith(
        hapticsEnabled: false,
        soundsEnabled: false,
        reducedMotion: true,
      ),
    );
    expect(
      await firstRepository.watch().first,
      const AppFeedbackPreferences(
        hapticsEnabled: false,
        soundsEnabled: false,
        reducedMotion: true,
      ),
    );
    expect(await firstDatabase.powersync.getNextCrudTransaction(), isNull);
    await firstDatabase.close();

    final reopenedDatabase = await openTestDatabase(path);
    addTearDown(reopenedDatabase.close);
    final reopenedRepository = PowerSyncAppFeedbackPreferencesRepository(
      reopenedDatabase.powersync,
    );

    expect(
      await reopenedRepository.watch().first,
      const AppFeedbackPreferences(
        hapticsEnabled: false,
        soundsEnabled: false,
        reducedMotion: true,
      ),
    );
  });

  test('updates one feedback preference without resetting others', () async {
    final directory = await Directory.systemTemp.createTemp(
      'soulbuddy-feedback-preferences-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = await openTestDatabase('${directory.path}/soulbuddy.db');
    addTearDown(database.close);
    final repository = PowerSyncAppFeedbackPreferencesRepository(
      database.powersync,
    );

    await repository.save(
      const AppFeedbackPreferences(
        hapticsEnabled: false,
        soundsEnabled: true,
        reducedMotion: true,
      ),
    );
    await repository.setSoundsEnabled(false);

    expect(
      await repository.watch().first,
      const AppFeedbackPreferences(
        hapticsEnabled: false,
        soundsEnabled: false,
        reducedMotion: true,
      ),
    );
  });
}

class _CredentialProbeConnector extends PowerSyncBackendConnector {
  var fetchCount = 0;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    fetchCount++;
    return null;
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {}
}
