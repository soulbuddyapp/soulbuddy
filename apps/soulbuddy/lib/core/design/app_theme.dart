import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_type.dart';

/// Component-level mappings built only from SoulBuddy semantic tokens.
abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
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
    );
    const radius = BorderRadius.all(
      Radius.circular(AppSpacing.componentRadius),
    );
    const inputBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      textTheme: AppType.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.surfaceMuted,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.action
                : AppColors.inkMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppType.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.actionStrong
                : AppColors.inkMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.surfaceMuted,
        selectedIconTheme: const IconThemeData(color: AppColors.action),
        unselectedIconTheme: const IconThemeData(color: AppColors.inkMuted),
        selectedLabelTextStyle: AppType.textTheme.labelMedium?.copyWith(
          color: AppColors.actionStrong,
        ),
        unselectedLabelTextStyle: AppType.textTheme.labelMedium?.copyWith(
          color: AppColors.inkMuted,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        constraints: BoxConstraints(minHeight: 56),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.action, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTouchTarget,
            AppSpacing.minimumTouchTarget,
          ),
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.surface,
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
          foregroundColor: AppColors.actionStrong,
          side: const BorderSide(color: AppColors.outline),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: AppType.textTheme.labelLarge,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      focusColor: AppColors.action.withValues(alpha: 0.14),
    );
  }
}
