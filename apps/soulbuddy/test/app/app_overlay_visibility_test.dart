import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app_overlay_visibility.dart';

void main() {
  test('only Sacred Hour routes suppress global overlays', () {
    for (final route in [
      '/sacred-hours/hour-1?occurrence=hour-1@now',
      '/sacred-hours/hour-2',
    ]) {
      expect(AppOverlayVisibility.hideGlobalOverlays(Uri.parse(route)), isTrue);
    }
    for (final route in [
      '/',
      '/today',
      '/prayers/saved/prayer-1',
      '/sacred-hours-settings',
    ]) {
      expect(
        AppOverlayVisibility.hideGlobalOverlays(Uri.parse(route)),
        isFalse,
      );
    }
  });
}
