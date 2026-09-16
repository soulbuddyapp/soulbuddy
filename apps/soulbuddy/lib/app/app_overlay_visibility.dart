abstract final class AppOverlayVisibility {
  static bool hideGlobalOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'sacred-hours';
}
