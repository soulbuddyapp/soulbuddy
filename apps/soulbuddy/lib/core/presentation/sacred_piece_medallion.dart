import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/sacred_piece.dart';

/// A small tactile marker that makes a spiritual experience recognizable.
class SacredPieceMedallion extends StatelessWidget {
  const SacredPieceMedallion({
    required this.piece,
    this.selected = false,
    this.decorative = false,
    this.size = AppSpacing.minimumTouchTarget,
    super.key,
  });

  final SacredPiece piece;
  final bool selected;
  final bool decorative;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final content = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: selected ? 0.18 : 0.06),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            selected ? piece.selectedIcon : piece.icon,
            color: iconColor,
            size: size * 0.46,
          ),
        ),
      ),
    );

    if (decorative) return ExcludeSemantics(child: content);
    return Semantics(label: piece.semanticLabel, child: content);
  }
}
