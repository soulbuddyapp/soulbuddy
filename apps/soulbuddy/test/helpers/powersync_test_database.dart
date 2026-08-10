import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path_helper;
import 'package:powersync/powersync.dart';
import 'package:soulbuddy/core/database/app_database.dart';

Future<AppDatabase> openTestDatabase(String databasePath) async {
  final packageConfig = File(
    path_helper.join('.dart_tool', 'package_config.json'),
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final powerSyncLibraries = packages.singleWhere(
    (package) => package['name'] == 'powersync_flutter_libs',
  );
  final rootUri = packageConfig.parent.uri.resolve(
    powerSyncLibraries['rootUri'] as String,
  );
  final packageRoot = Directory.fromUri(rootUri).path;
  final libraryPath = path_helper.join(
    packageRoot,
    'windows',
    'powersync_x64.dll',
  );

  return AppDatabase.open(
    path: databasePath,
    openFactory: _TestPowerSyncOpenFactory(
      path: databasePath,
      libraryPath: libraryPath,
    ),
  );
}

class _TestPowerSyncOpenFactory extends PowerSyncOpenFactory {
  _TestPowerSyncOpenFactory({required super.path, required this.libraryPath});

  final String libraryPath;

  @override
  String getLibraryForPlatform({String? path}) => libraryPath;
}
