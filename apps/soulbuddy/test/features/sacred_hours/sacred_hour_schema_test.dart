import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/database/app_schema.dart';

import '../../helpers/powersync_test_database.dart';

void main() {
  test('runtime schema opens all Sacred Hour tables and indexes', () async {
    final directory = await Directory.systemTemp.createTemp('sacred-schema-');
    final database = await openTestDatabase('${directory.path}/app.db');
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    for (final table in const [
      'sacred_hours',
      'sacred_hour_occurrences',
      'sacred_hour_devices',
    ]) {
      expect(
        await database.powersync.getAll('SELECT id FROM $table LIMIT 1'),
        isEmpty,
      );
    }

    final indexes = appSchema.tables
        .where((table) => table.name.startsWith('sacred_hour'))
        .expand((table) => table.indexes)
        .map((index) => index.name);
    expect(
      indexes,
      containsAll(<String>[
        'sacred_hours_owner_time',
        'sacred_hour_occurrences_owner_due',
        'sacred_hour_devices_due',
      ]),
    );
  });
}
