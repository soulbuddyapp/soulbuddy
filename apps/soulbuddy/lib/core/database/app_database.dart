import 'package:powersync/powersync.dart';

import '../../features/editorial/data/editorial_schema.dart';
import '../../features/goals/data/goal_schema.dart';
import '../../features/persons/data/person_schema.dart';
import 'app_schema.dart';

final appRuntimeSchema = Schema([
  ...appSchema.tables,
  ...goalTables,
  ...personTables,
  ...editorialTables,
]);

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
