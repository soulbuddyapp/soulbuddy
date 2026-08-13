import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/today/domain/daily_practice_state.dart';
import '../design/covenant_grace_tokens.dart';

/// A quiet pair of natural slabs whose inscriptions reflect today's practices.
///
/// This widget presents factual daily activity only. It does not estimate
/// spiritual growth, award points, or compare one person with another.
class CovenantSlabs extends StatefulWidget {
  const CovenantSlabs({
    required this.state,
    this.animate = false,
    this.height = 112,
    super.key,
  });

  final DailyPracticeState state;
  final bool animate;
  final double height;

  @override
  State<CovenantSlabs> createState() => _CovenantSlabsState();
}

class _CovenantSlabsState extends State<CovenantSlabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(CovenantSlabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (setEquals(oldWidget.state.completed, widget.state.completed)) {
      return;
    }

    final motionDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.animate || motionDisabled) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.state.isValid, 'Completed practices must also be available.');
    final theme = Theme.of(context);
    final colors =
        theme.extension<CovenantGraceColors>() ??
        (theme.brightness == Brightness.dark
            ? CovenantGraceColors.dark
            : CovenantGraceColors.light);
    final status = _statusText(widget.state);

    return Semantics(
      container: true,
      label: _semanticsLabel(widget.state),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: widget.height,
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => CustomPaint(
                isComplex: true,
                painter: CovenantSlabsPainter(
                  state: widget.state,
                  colors: colors,
                  reveal: _reveal.value,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: colors.umber),
          ),
        ],
      ),
    );
  }
}

class CovenantSlabsPainter extends CustomPainter {
  const CovenantSlabsPainter({
    required this.state,
    required this.colors,
    required this.reveal,
  });

  final DailyPracticeState state;
  final CovenantGraceColors colors;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = reveal.clamp(0.0, 1.0);
    final leftSlab = _leftSlab(size);
    final rightSlab = _rightSlab(size);

    _paintWarmLight(canvas, size);
    _paintSlab(canvas, leftSlab, size);
    _paintSlab(canvas, rightSlab, size);

    _paintInscription(
      canvas,
      _prayerInscription(size),
      DailyPractice.pray,
      progress,
    );
    _paintInscription(
      canvas,
      _actionInscription(size),
      DailyPractice.act,
      progress,
    );
    _paintInscription(
      canvas,
      _remembranceInscription(size),
      DailyPractice.remember,
      progress,
    );
  }

  void _paintWarmLight(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              colors.lightWash.withValues(alpha: 0.58),
              colors.lightWash.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(size.width * 0.5, size.height * 0.48),
              width: size.width * 0.94,
              height: size.height * 1.5,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.92,
        height: size.height * 1.2,
      ),
      glowPaint,
    );
  }

  void _paintSlab(Canvas canvas, Path slab, Size size) {
    final shadow = slab.shift(Offset(0, size.height * 0.035));
    canvas.drawPath(
      shadow,
      Paint()..color = colors.umber.withValues(alpha: 0.13),
    );

    canvas.drawPath(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.limestoneLight, colors.limestone],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      slab,
      Paint()
        ..color = colors.umber.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _paintInscription(
    Canvas canvas,
    Path inscription,
    DailyPractice practice,
    double progress,
  ) {
    final available = state.available.contains(practice);
    final completed = state.completed.contains(practice);
    final bedPaint = Paint()
      ..color = colors.umber.withValues(alpha: available ? 0.44 : 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    canvas.drawPath(inscription, bedPaint);

    if (!completed) {
      return;
    }

    final glowPaint = Paint()
      ..color = colors.lightWash.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.square;
    final linePaint = Paint()
      ..color = colors.covenantGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.square;

    for (final metric in inscription.computeMetrics()) {
      final revealed = metric.extractPath(0, metric.length * progress);
      canvas
        ..drawPath(revealed, glowPaint)
        ..drawPath(revealed, linePaint);
    }
  }

  Path _leftSlab(Size size) => Path()
    ..moveTo(size.width * 0.055, size.height * 0.19)
    ..lineTo(size.width * 0.105, size.height * 0.055)
    ..lineTo(size.width * 0.405, size.height * 0.035)
    ..lineTo(size.width * 0.465, size.height * 0.15)
    ..lineTo(size.width * 0.445, size.height * 0.9)
    ..lineTo(size.width * 0.09, size.height * 0.95)
    ..lineTo(size.width * 0.04, size.height * 0.82)
    ..close();

  Path _rightSlab(Size size) => Path()
    ..moveTo(size.width * 0.535, size.height * 0.15)
    ..lineTo(size.width * 0.585, size.height * 0.04)
    ..lineTo(size.width * 0.9, size.height * 0.065)
    ..lineTo(size.width * 0.955, size.height * 0.19)
    ..lineTo(size.width * 0.935, size.height * 0.9)
    ..lineTo(size.width * 0.565, size.height * 0.955)
    ..lineTo(size.width * 0.515, size.height * 0.83)
    ..close();

  Path _prayerInscription(Size size) => Path()
    ..moveTo(size.width * 0.13, size.height * 0.31)
    ..lineTo(size.width * 0.37, size.height * 0.29)
    ..moveTo(size.width * 0.145, size.height * 0.41)
    ..lineTo(size.width * 0.35, size.height * 0.39);

  Path _actionInscription(Size size) => Path()
    ..moveTo(size.width * 0.13, size.height * 0.64)
    ..lineTo(size.width * 0.365, size.height * 0.66)
    ..moveTo(size.width * 0.15, size.height * 0.75)
    ..lineTo(size.width * 0.345, size.height * 0.77);

  Path _remembranceInscription(Size size) => Path()
    ..moveTo(size.width * 0.61, size.height * 0.37)
    ..lineTo(size.width * 0.865, size.height * 0.35)
    ..moveTo(size.width * 0.595, size.height * 0.5)
    ..lineTo(size.width * 0.88, size.height * 0.49)
    ..moveTo(size.width * 0.625, size.height * 0.63)
    ..lineTo(size.width * 0.85, size.height * 0.65);

  @override
  bool shouldRepaint(covariant CovenantSlabsPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.colors != colors ||
        oldDelegate.reveal != reveal;
  }
}

String _statusText(DailyPracticeState state) {
  if (state.availableCount == 0) {
    return 'No practices available today';
  }
  final noun = state.availableCount == 1 ? 'practice' : 'practices';
  return '${state.completedCount} of ${state.availableCount} $noun completed';
}

String _semanticsLabel(DailyPracticeState state) {
  final completed = DailyPractice.values
      .where(state.completed.contains)
      .map(_practiceName)
      .toList(growable: false);
  final available = DailyPractice.values
      .where(
        (practice) =>
            state.available.contains(practice) &&
            !state.completed.contains(practice),
      )
      .map(_practiceName)
      .toList(growable: false);

  final clauses = <String>[];
  if (completed.isNotEmpty) {
    clauses.add('${_joinNames(completed)} completed');
  }
  if (available.isNotEmpty) {
    clauses.add('${_joinNames(available)} available');
  }
  if (clauses.isEmpty) {
    return 'Today: no practices available';
  }
  return 'Today: ${clauses.join('; ')}';
}

String _practiceName(DailyPractice practice) => switch (practice) {
  DailyPractice.pray => 'prayer',
  DailyPractice.act => 'action',
  DailyPractice.remember => 'remembrance',
};

String _joinNames(List<String> names) => switch (names) {
  [] => '',
  [final only] => only,
  [final first, final second] => '$first and $second',
  _ => '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}',
};
