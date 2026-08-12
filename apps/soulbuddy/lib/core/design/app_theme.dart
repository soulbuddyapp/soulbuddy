import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_type.dart';

/// Component-level mappings built only from SoulBuddy semantic tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(
    const ColorScheme.light(
      primary: AppColors.action,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.surfaceMuted,
      onPrimaryContainer: AppColors.actionStrong,
      secondary: AppColors.accent,
      onSecondary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      error: AppColors.danger,
      onError: AppColors.surface,
      outline: AppColors.outline,
    ),
    canvas: AppColors.canvas,
    surfaceMuted: AppColors.surfaceMuted,
    inkMuted: AppColors.inkMuted,
  );

  static ThemeData dark() => _build(
    const ColorScheme.dark(
      primary: AppColors.darkAction,
      onPrimary: AppColors.darkCanvas,
      primaryContainer: AppColors.darkSurfaceMuted,
      onPrimaryContainer: AppColors.darkActionStrong,
      secondary: AppColors.darkAccent,
      onSecondary: AppColors.darkCanvas,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      onSurfaceVariant: AppColors.darkInkMuted,
      error: AppColors.darkDanger,
      onError: AppColors.darkCanvas,
      outline: AppColors.darkOutline,
    ),
    canvas: AppColors.darkCanvas,
    surfaceMuted: AppColors.darkSurfaceMuted,
    inkMuted: AppColors.darkInkMuted,
  );

  static ThemeData _build(
    ColorScheme colorScheme, {
    required Color canvas,
    required Color surfaceMuted,
    required Color inkMuted,
  }) {
    const radius = BorderRadius.all(
      Radius.circular(AppSpacing.componentRadius),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: AppType.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: surfaceMuted,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : inkMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppType.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : inkMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: surfaceMuted,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: inkMuted),
        selectedLabelTextStyle: AppType.textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
        unselectedLabelTextStyle: AppType.textTheme.labelMedium?.copyWith(
          color: inkMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTouchTarget,
            AppSpacing.minimumTouchTarget,
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: radius),
          elevation: 0,
          textStyle: AppType.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTouchTarget,
            AppSpacing.minimumTouchTarget,
          ),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: AppType.textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      focusColor: colorScheme.primary.withValues(alpha: 0.14),
    );
  }
}
