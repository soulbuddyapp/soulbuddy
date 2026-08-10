import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_colors.dart';
import 'package:soulbuddy/core/design/app_spacing.dart';
import 'package:soulbuddy/core/design/app_theme.dart';

void main() {
  test('uses a four-point primitive spacing scale', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 16);
    expect(AppSpacing.lg, 24);
    expect(AppSpacing.xl, 32);
  });

  test('maps semantic colors into component theme values', () {
    final ThemeData theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppColors.action);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(theme.navigationBarTheme.height, 72);
    expect(theme.inputDecorationTheme.filled, isTrue);
  });
}
