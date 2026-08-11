abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('SOULBUDDY_API_URL');
  static const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');
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
