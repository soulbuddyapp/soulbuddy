import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/covenant_grace_tokens.dart';

/// An ivory focal surface with a quiet light field and optional marble veins.
class SacredSurface extends StatelessWidget {
  const SacredSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.marble = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool marble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors =
        theme.extension<CovenantGraceColors>() ??
        (theme.brightness == Brightness.dark
            ? CovenantGraceColors.dark
            : CovenantGraceColors.light);
    const radius = BorderRadius.all(
      Radius.circular(AppSpacing.componentRadius),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.lightWash.withValues(alpha: 0.28),
              scheme.surface,
            ),
            scheme.surface,
            Color.alphaBlend(
              colors.limestoneLight.withValues(alpha: 0.22),
              scheme.surface,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.brightness == Brightness.light
              ? const Color(0xFFFFFBF2)
              : colors.limestoneLight.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.umber.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(3, 8),
          ),
          BoxShadow(
            color: colors.covenantGold.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (marble)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const Key('sacred-surface-marble'),
                    painter: _MarbleVeins(
                      color: colors.umber.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _MarbleVeins extends CustomPainter {
  const _MarbleVeins({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final primary = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.22)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.08,
        size.width * 0.48,
        size.height * 0.42,
        size.width * 1.05,
        size.height * 0.18,
      );
    final secondary = Path()
      ..moveTo(size.width * 0.10, size.height * 1.04)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.76,
        size.width * 0.68,
        size.height * 0.98,
        size.width * 0.96,
        size.height * 0.68,
      );
    canvas.drawPath(primary, paint);
    canvas.drawPath(secondary, paint..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant _MarbleVeins oldDelegate) =>
      oldDelegate.color != color;
}
