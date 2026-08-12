import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';

void main() {
  test('provides distinct complete light and dark themes', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
    expect(dark.colorScheme.surface, isNot(light.colorScheme.surface));
    expect(
      ThemeData.estimateBrightnessForColor(dark.colorScheme.onSurface),
      Brightness.light,
    );
    expect(dark.filledButtonTheme.style, isNotNull);
    expect(dark.navigationBarTheme.backgroundColor, isNotNull);
  });
}
