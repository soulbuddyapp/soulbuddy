import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

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
