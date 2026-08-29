import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'SOULBUDDY_API_URL',
  );
  static String get apiBaseUrl => _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : (kReleaseMode ? 'https://sbuddy.elbiblio.com' : '');
  static const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');

  // New runtime prayer generation and request creation are retired product
  // capabilities. These constants stay available temporarily so historical
  // request readers can be removed in compatibility-safe tranches without a
  // configuration path that can turn generation back on.
  static const prayerGenerationEnabled = false;
  static const prayerRequestCreationEnabled = false;

  static const prayerDraftProvider = String.fromEnvironment(
    'SOULBUDDY_PRAYER_DRAFT_PROVIDER',
    defaultValue: 'deepseek',
  );
  static const prayerDraftDisclosureVersion = String.fromEnvironment(
    'SOULBUDDY_PRAYER_DRAFT_DISCLOSURE_VERSION',
    defaultValue: 'deepseek-1',
  );

  static bool get syncConfigured =>
      apiBaseUrl.isNotEmpty && powerSyncUrl.isNotEmpty;
}
