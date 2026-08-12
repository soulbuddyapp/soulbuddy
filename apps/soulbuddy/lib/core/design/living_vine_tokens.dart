import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic botanical colors for SoulBuddy's Living Vine visual language.
@immutable
class LivingVineColors extends ThemeExtension<LivingVineColors> {
  const LivingVineColors({
    required this.vine,
    required this.leaf,
    required this.leafSoft,
    required this.blossom,
    required this.fruit,
    required this.memorial,
    required this.botanicalWash,
  });

  static const light = LivingVineColors(
    vine: AppPalette.forest850,
    leaf: AppPalette.forest700,
    leafSoft: AppPalette.sage300,
    blossom: AppPalette.blossom300,
    fruit: AppPalette.berry700,
    memorial: AppPalette.stone500,
    botanicalWash: AppPalette.sage50,
  );

  static const dark = LivingVineColors(
    vine: AppColors.darkActionStrong,
    leaf: AppColors.darkAction,
    leafSoft: AppPalette.sage700,
    blossom: AppPalette.blossom200,
    fruit: AppPalette.berry300,
    memorial: AppPalette.stone300,
    botanicalWash: AppPalette.forest800,
  );

  final Color vine;
  final Color leaf;
  final Color leafSoft;
  final Color blossom;
  final Color fruit;
  final Color memorial;
  final Color botanicalWash;

  @override
  LivingVineColors copyWith({
    Color? vine,
    Color? leaf,
    Color? leafSoft,
    Color? blossom,
    Color? fruit,
    Color? memorial,
    Color? botanicalWash,
  }) => LivingVineColors(
    vine: vine ?? this.vine,
    leaf: leaf ?? this.leaf,
    leafSoft: leafSoft ?? this.leafSoft,
    blossom: blossom ?? this.blossom,
    fruit: fruit ?? this.fruit,
    memorial: memorial ?? this.memorial,
    botanicalWash: botanicalWash ?? this.botanicalWash,
  );

  @override
  LivingVineColors lerp(covariant LivingVineColors? other, double t) {
    if (other == null) return this;
    return LivingVineColors(
      vine: Color.lerp(vine, other.vine, t)!,
      leaf: Color.lerp(leaf, other.leaf, t)!,
      leafSoft: Color.lerp(leafSoft, other.leafSoft, t)!,
      blossom: Color.lerp(blossom, other.blossom, t)!,
      fruit: Color.lerp(fruit, other.fruit, t)!,
      memorial: Color.lerp(memorial, other.memorial, t)!,
      botanicalWash: Color.lerp(botanicalWash, other.botanicalWash, t)!,
    );
  }
}

/// Component measurements shared by every Living Vine composition.
abstract final class LivingVineTokens {
  static const height = 56.0;
  static const branchWidth = 3.0;
  static const branchHighlightWidth = 1.0;
  static const leafLength = 13.0;
}
