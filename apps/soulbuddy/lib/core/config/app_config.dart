import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'SOULBUDDY_API_URL',
  );
  static String get apiBaseUrl => _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : (kReleaseMode ? 'https://sbuddy.elbiblio.com' : '');
  static const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');

  /// Whether a saved record can reach the Laravel boundary.
  ///
  /// Writes are ordinary authenticated posts to Laravel and need nothing from a
  /// sync service, so this gate stands alone. Gating it on the sync service too
  /// would silently discard every write on any build without one.
  static bool get uploadConfigured => apiBaseUrl.isNotEmpty;

  /// Whether a sync service can serve records down to this device.
  static bool get downloadConfigured => powerSyncUrl.isNotEmpty;

  /// The compile-time values this build is missing, if any.
  ///
  /// A build without these keeps working and silently disables every
  /// server-backed capability: saved records never upload, and activity is
  /// never recorded. Naming the missing value is the only way that is noticed.
  static List<String> missingConfiguration() => [
    if (apiBaseUrl.isEmpty) 'SOULBUDDY_API_URL',
    if (powerSyncUrl.isEmpty) 'SOULBUDDY_POWERSYNC_URL',
  ];
}
