import 'package:flutter/material.dart';

import '../design/covenant_grace_tokens.dart';

/// A shallow carved separator used between a record's identity and its words.
class CovenantIncisedDivider extends StatelessWidget {
  const CovenantIncisedDivider({this.height = 18, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: CovenantMarkPainter.incised(_colors(context)),
      ),
    ),
  );
}

/// A small natural paired-slab mark reserved for promises before God.
class CovenantPairedSlabMark extends StatelessWidget {
  const CovenantPairedSlabMark({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 42,
      height: 30,
      child: CustomPaint(painter: CovenantMarkPainter.paired(_colors(context))),
    ),
  );
}

/// Three quiet illuminated inscriptions gathered into one place.
class GatheredInscriptionMark extends StatelessWidget {
  const GatheredInscriptionMark({this.height = 64, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Three illuminated inscriptions gathered in one place.',
    child: ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: CovenantMarkPainter.gathered(_colors(context)),
        ),
      ),
    ),
  );
}

enum CovenantMarkKind { incised, paired, gathered }

class CovenantMarkPainter extends CustomPainter {
  const CovenantMarkPainter._(this.kind, this.colors);

  const CovenantMarkPainter.incised(CovenantGraceColors colors)
    : this._(CovenantMarkKind.incised, colors);

  const CovenantMarkPainter.paired(CovenantGraceColors colors)
    : this._(CovenantMarkKind.paired, colors);

  const CovenantMarkPainter.gathered(CovenantGraceColors colors)
    : this._(CovenantMarkKind.gathered, colors);

  final CovenantMarkKind kind;
  final CovenantGraceColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case CovenantMarkKind.incised:
        _paintIncised(canvas, size);
      case CovenantMarkKind.paired:
        _paintPaired(canvas, size);
      case CovenantMarkKind.gathered:
        _paintGathered(canvas, size);
    }
  }

  void _paintIncised(Canvas canvas, Size size) {
    final y = size.height * 0.5;
    final path = Path()
      ..moveTo(size.width * 0.06, y + 1)
      ..lineTo(size.width * 0.31, y - 0.4)
      ..lineTo(size.width * 0.51, y + 0.7)
      ..lineTo(size.width * 0.72, y - 0.8)
      ..lineTo(size.width * 0.94, y);
    canvas.drawPath(
      path.shift(const Offset(0, 1.4)),
      Paint()
        ..color = colors.lightWash.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.umber.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _paintPaired(Canvas canvas, Size size) {
    final left = Path()
      ..moveTo(size.width * 0.08, size.height * 0.22)
      ..lineTo(size.width * 0.18, size.height * 0.08)
      ..lineTo(size.width * 0.43, size.height * 0.11)
      ..lineTo(size.width * 0.47, size.height * 0.84)
      ..lineTo(size.width * 0.12, size.height * 0.9)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.54, size.height * 0.15)
      ..lineTo(size.width * 0.62, size.height * 0.07)
      ..lineTo(size.width * 0.88, size.height * 0.13)
      ..lineTo(size.width * 0.92, size.height * 0.86)
      ..lineTo(size.width * 0.56, size.height * 0.91)
      ..close();
    final fill = Paint()..color = colors.limestone;
    final edge = Paint()
      ..color = colors.umber.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final slab in [left, right]) {
      canvas
        ..drawPath(slab, fill)
        ..drawPath(slab, edge);
    }
    final inscription = Paint()
      ..color = colors.covenantGold
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    canvas
      ..drawLine(
        Offset(size.width * 0.2, size.height * 0.45),
        Offset(size.width * 0.38, size.height * 0.43),
        inscription,
      )
      ..drawLine(
        Offset(size.width * 0.65, size.height * 0.48),
        Offset(size.width * 0.82, size.height * 0.46),
        inscription,
      );
  }

  void _paintGathered(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.51);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.74,
        height: size.height * 1.2,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                colors.lightWash.withValues(alpha: 0.72),
                colors.lightWash.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCenter(
                center: center,
                width: size.width * 0.75,
                height: size.height * 1.3,
              ),
            ),
    );

    final bed = Paint()
      ..color = colors.umber.withValues(alpha: 0.22)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = colors.covenantGold
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;
    final lines = <(Offset, Offset)>[
      (
        Offset(size.width * 0.25, size.height * 0.3),
        Offset(size.width * 0.69, size.height * 0.27),
      ),
      (
        Offset(size.width * 0.31, size.height * 0.5),
        Offset(size.width * 0.75, size.height * 0.51),
      ),
      (
        Offset(size.width * 0.24, size.height * 0.7),
        Offset(size.width * 0.68, size.height * 0.73),
      ),
    ];
    for (final line in lines) {
      canvas
        ..drawLine(line.$1, line.$2, bed)
        ..drawLine(line.$1, line.$2, light);
    }
  }

  @override
  bool shouldRepaint(covariant CovenantMarkPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.colors != colors;
}

CovenantGraceColors _colors(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<CovenantGraceColors>() ??
      (theme.brightness == Brightness.dark
          ? CovenantGraceColors.dark
          : CovenantGraceColors.light);
}
