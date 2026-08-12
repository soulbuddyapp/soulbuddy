import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/living_vine_tokens.dart';

enum LivingVineVariant { leaf, blossom, fruit, memorial, intertwined }

/// A quiet, decorative expression of SoulBuddy's Living Vine language.
class LivingVine extends StatelessWidget {
  const LivingVine({
    required this.variant,
    this.animate = false,
    this.height = LivingVineTokens.height,
    super.key,
  });

  final LivingVineVariant variant;
  final bool animate;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<LivingVineColors>() ??
        (theme.brightness == Brightness.dark
            ? LivingVineColors.dark
            : LivingVineColors.light);
    final motionDisabled = MediaQuery.disableAnimationsOf(context);
    final duration = animate && !motionDisabled
        ? const Duration(milliseconds: 420)
        : Duration.zero;

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: duration == Duration.zero ? 1 : 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, reveal, _) => CustomPaint(
            painter: LivingVinePainter(
              variant: variant,
              colors: colors,
              reveal: reveal,
            ),
          ),
        ),
      ),
    );
  }
}

class LivingVinePainter extends CustomPainter {
  const LivingVinePainter({
    required this.variant,
    required this.colors,
    required this.reveal,
  });

  final LivingVineVariant variant;
  final LivingVineColors colors;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = reveal.clamp(0.0, 1.0);
    final branch = _branchPath(size, variant == LivingVineVariant.intertwined);
    _drawRevealedPath(
      canvas,
      branch,
      progress,
      Paint()
        ..color = colors.vine.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = LivingVineTokens.branchWidth
        ..strokeCap = StrokeCap.round,
    );
    _drawRevealedPath(
      canvas,
      branch,
      progress,
      Paint()
        ..color = colors.leafSoft.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = LivingVineTokens.branchHighlightWidth
        ..strokeCap = StrokeCap.round,
    );

    if (variant == LivingVineVariant.intertwined) {
      _drawRevealedPath(
        canvas,
        _branchPath(size, true, mirrored: true),
        progress,
        Paint()
          ..color = colors.leaf.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }

    if (progress < 0.36) return;
    final growth = ((progress - 0.36) / 0.64).clamp(0.0, 1.0);
    _drawLeaf(
      canvas,
      Offset(size.width * 0.27, size.height * 0.50),
      -0.72,
      growth,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * 0.53, size.height * 0.42),
      0.72,
      growth,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * 0.78, size.height * 0.54),
      -0.62,
      growth,
    );

    switch (variant) {
      case LivingVineVariant.leaf:
        _drawLeaf(
          canvas,
          Offset(size.width * 0.9, size.height * 0.38),
          0.45,
          growth,
        );
      case LivingVineVariant.blossom:
        _drawBlossom(
          canvas,
          Offset(size.width * 0.86, size.height * 0.35),
          growth,
        );
      case LivingVineVariant.fruit:
        _drawFruit(
          canvas,
          Offset(size.width * 0.86, size.height * 0.43),
          growth,
        );
      case LivingVineVariant.memorial:
        _drawMemorial(
          canvas,
          Offset(size.width * 0.86, size.height * 0.62),
          growth,
        );
      case LivingVineVariant.intertwined:
        _drawLeaf(
          canvas,
          Offset(size.width * 0.69, size.height * 0.28),
          0.4,
          growth,
        );
    }
  }

  Path _branchPath(Size size, bool intertwined, {bool mirrored = false}) {
    final path = Path();
    if (intertwined && mirrored) {
      path
        ..moveTo(0, size.height * 0.67)
        ..cubicTo(
          size.width * 0.25,
          size.height * 0.05,
          size.width * 0.52,
          size.height * 0.86,
          size.width,
          size.height * 0.31,
        );
      return path;
    }
    path
      ..moveTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.22,
        size.height * (intertwined ? 0.93 : 0.82),
        size.width * 0.48,
        size.height * 0.08,
        size.width,
        size.height * 0.46,
      );
    return path;
  }

  void _drawRevealedPath(
    Canvas canvas,
    Path path,
    double progress,
    Paint paint,
  ) {
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double angle, double growth) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    canvas.scale(growth, growth);
    final length = LivingVineTokens.leafLength;
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.45, -6, length, 0)
      ..quadraticBezierTo(length * 0.45, 6, 0, 0)
      ..close();
    canvas.drawPath(leaf, Paint()..color = colors.leaf.withValues(alpha: 0.82));
    canvas.drawLine(
      Offset.zero,
      Offset(length * 0.78, 0),
      Paint()
        ..color = colors.vine.withValues(alpha: 0.55)
        ..strokeWidth = 0.8,
    );
    canvas.restore();
  }

  void _drawBlossom(Canvas canvas, Offset origin, double growth) {
    final paint = Paint()..color = colors.blossom.withValues(alpha: 0.9);
    for (var index = 0; index < 5; index++) {
      final angle = index * math.pi * 2 / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: origin + Offset(math.cos(angle) * 5, math.sin(angle) * 5),
          width: 7 * growth,
          height: 10 * growth,
        ),
        paint,
      );
    }
    canvas.drawCircle(origin, 2.5 * growth, Paint()..color = colors.fruit);
  }

  void _drawFruit(Canvas canvas, Offset origin, double growth) {
    canvas.drawLine(
      origin.translate(0, -8),
      origin,
      Paint()
        ..color = colors.vine
        ..strokeWidth = 1.3,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: origin.translate(0, 5),
        width: 10 * growth,
        height: 14 * growth,
      ),
      Paint()..color = colors.fruit.withValues(alpha: 0.9),
    );
  }

  void _drawMemorial(Canvas canvas, Offset origin, double growth) {
    final paint = Paint()..color = colors.memorial.withValues(alpha: 0.76);
    for (var index = 0; index < 3; index++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: origin.translate(0, -index * 5.0),
            width: (19 - index * 3) * growth,
            height: 6 * growth,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LivingVinePainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.colors != colors ||
      oldDelegate.reveal != reveal;
}
