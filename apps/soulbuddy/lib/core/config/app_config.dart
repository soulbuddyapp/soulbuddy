import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'SOULBUDDY_API_URL',
  );
  static String get apiBaseUrl => _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : (kReleaseMode ? 'https://sbuddy.elbiblio.com' : '');
  static const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');

  static bool get syncConfigured =>
      apiBaseUrl.isNotEmpty && powerSyncUrl.isNotEmpty;
}
