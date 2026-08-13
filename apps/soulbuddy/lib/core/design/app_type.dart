import 'package:flutter/material.dart';

/// Semantic typography roles, using platform fonts for a fast first frame.
abstract final class AppType {
  static const displayFontFamily = 'Source Serif 4 Display';

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: displayFontFamily,
      fontSize: 36,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineMedium: TextStyle(
      fontFamily: displayFontFamily,
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontFamily: displayFontFamily,
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.55),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  );
}
