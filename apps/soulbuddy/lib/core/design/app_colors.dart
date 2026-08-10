import 'package:flutter/material.dart';

/// Raw color primitives. Product UI should consume [AppColors] instead.
abstract final class AppPalette {
  static const warm50 = Color(0xFFFBFAF7);
  static const white = Color(0xFFFFFFFF);
  static const sage50 = Color(0xFFF2F5F2);
  static const forest950 = Color(0xFF1C2620);
  static const forest600 = Color(0xFF59645E);
  static const forest700 = Color(0xFF285943);
  static const forest850 = Color(0xFF174334);
  static const ochre700 = Color(0xFF9A6B2F);
  static const sage200 = Color(0xFFDDE3DE);
  static const red700 = Color(0xFFB3261E);
}

/// Semantic color roles used throughout SoulBuddy.
abstract final class AppColors {
  static const canvas = AppPalette.warm50;
  static const surface = AppPalette.white;
  static const surfaceMuted = AppPalette.sage50;
  static const ink = AppPalette.forest950;
  static const inkMuted = AppPalette.forest600;
  static const action = AppPalette.forest700;
  static const actionStrong = AppPalette.forest850;
  static const accent = AppPalette.ochre700;
  static const outline = AppPalette.sage200;
  static const danger = AppPalette.red700;
}
