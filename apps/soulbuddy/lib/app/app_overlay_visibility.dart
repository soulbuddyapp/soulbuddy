abstract final class AppOverlayVisibility {
  static bool hideReminderOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'goals';

  static bool hideGlobalOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'sacred-hours';
}
