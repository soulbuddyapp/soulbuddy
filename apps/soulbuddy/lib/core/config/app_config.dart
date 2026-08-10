abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('SOULBUDDY_API_URL');
  static const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');

  static bool get syncConfigured =>
      apiBaseUrl.isNotEmpty && powerSyncUrl.isNotEmpty;
}
