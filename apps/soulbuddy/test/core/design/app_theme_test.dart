import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/design/covenant_grace_tokens.dart';

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

  test('Covenant and Grace tokens are installed in both themes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.extension<CovenantGraceColors>();

      expect(colors, isNotNull);
      expect(colors!.limestone.computeLuminance(), isNot(equals(0)));
      expect(
        theme.textTheme.headlineMedium!.fontFamily,
        'Source Serif 4 Display',
      );
      expect(
        theme.textTheme.bodyLarge!.fontFamily,
        isNot('Source Serif 4 Display'),
      );
    }
  });
}
