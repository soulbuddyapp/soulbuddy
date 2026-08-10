import 'package:powersync/powersync.dart';

import 'app_schema.dart';

class AppDatabase {
  AppDatabase._(this.powersync);

  final PowerSyncDatabase powersync;

  static Future<AppDatabase> open({
    required String path,
    PowerSyncOpenFactory? openFactory,
  }) async {
    final database = openFactory == null
        ? PowerSyncDatabase(schema: appSchema, path: path)
        : PowerSyncDatabase.withFactory(openFactory, schema: appSchema);
    await database.initialize();
    return AppDatabase._(database);
  }

  Future<void> close() => powersync.close();
}
