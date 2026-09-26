abstract final class AppOverlayVisibility {
  static bool hideReminderOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty &&
      (uri.pathSegments.first == 'goals' ||
          uri.pathSegments.first == 'prayers');

  static bool hideGlobalOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty &&
      (uri.pathSegments.first == 'sacred-hours' ||
          uri.pathSegments.first == 'commitments' ||
          uri.path.startsWith('/welcome/commitment'));
}
