import 'package:powersync/powersync.dart';

import '../../features/goals/data/goal_schema.dart';
import 'app_schema.dart';

final appRuntimeSchema = Schema([...appSchema.tables, ...goalTables]);

class AppDatabase {
  AppDatabase._(this.powersync);

  final PowerSyncDatabase powersync;

  static Future<AppDatabase> open({
    required String path,
    PowerSyncBackendConnector? connector,
    PowerSyncOpenFactory? openFactory,
  }) async {
    final database = openFactory == null
        ? PowerSyncDatabase(schema: appRuntimeSchema, path: path)
        : PowerSyncDatabase.withFactory(openFactory, schema: appRuntimeSchema);
    await database.initialize();
    if (connector != null) {
      await database.connect(connector: connector);
    }
    return AppDatabase._(database);
  }

  Future<void> close() => powersync.close();
}
