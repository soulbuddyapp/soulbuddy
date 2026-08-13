import 'package:flutter/material.dart';

/// Raw color primitives. Product UI should consume [AppColors] instead.
abstract final class AppPalette {
  static const warm50 = Color(0xFFF7F1E5);
  static const white = Color(0xFFFFFFFF);
  static const sage50 = Color(0xFFF2F5F2);
  static const forest950 = Color(0xFF1C2620);
  static const forest600 = Color(0xFF59645E);
  static const forest700 = Color(0xFF285943);
  static const forest850 = Color(0xFF174334);
  static const ochre700 = Color(0xFF9A6B2F);
  static const berry700 = Color(0xFF7B4B45);
  static const blossom300 = Color(0xFFD9A8A0);
  static const stone500 = Color(0xFF8B8375);
  static const sage200 = Color(0xFFDDE3DE);
  static const red700 = Color(0xFFB3261E);
  static const warm950 = Color(0xFF171B18);
  static const forest900 = Color(0xFF17211B);
  static const forest800 = Color(0xFF223129);
  static const sage100 = Color(0xFFE8EEE9);
  static const sage300 = Color(0xFFAEBBB2);
  static const sage700 = Color(0xFF415248);
  static const ochre300 = Color(0xFFD7B77F);
  static const berry300 = Color(0xFFD8A29A);
  static const blossom200 = Color(0xFFE7C3BD);
  static const stone300 = Color(0xFFBDB4A5);
  static const red300 = Color(0xFFFFB4AB);
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

  static const darkCanvas = AppPalette.warm950;
  static const darkSurface = AppPalette.forest900;
  static const darkSurfaceMuted = AppPalette.forest800;
  static const darkInk = AppPalette.sage100;
  static const darkInkMuted = AppPalette.sage300;
  static const darkAction = Color(0xFF8AC9A7);
  static const darkActionStrong = Color(0xFFB5E4C9);
  static const darkAccent = AppPalette.ochre300;
  static const darkOutline = AppPalette.sage700;
  static const darkDanger = AppPalette.red300;
}
