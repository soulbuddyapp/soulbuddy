import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/covenant_grace_tokens.dart';

class FirstPrayerChoicePage extends StatelessWidget {
  const FirstPrayerChoicePage({
    required this.question,
    required this.choices,
    required this.onChoose,
    super.key,
  });

  final String question;
  final List<String> choices;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: question,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FirstPrayerGuideMark(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(question, style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final choice in choices) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: OutlinedButton(
                      onPressed: () => onChoose(choice),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(choice),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstPrayerGuideMark extends StatelessWidget {
  const FirstPrayerGuideMark({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('first-prayer-guide-mark'),
    width: 76,
    height: 48,
    child: CustomPaint(
      painter: _FirstPrayerGuideMarkPainter(
        Theme.of(context).extension<CovenantGraceColors>() ??
            CovenantGraceColors.light,
      ),
    ),
  );
}

class _FirstPrayerGuideMarkPainter extends CustomPainter {
  const _FirstPrayerGuideMarkPainter(this.colors);

  final CovenantGraceColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = colors.umber.withValues(alpha: .12);
    final stone = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.limestoneLight, colors.limestone],
      ).createShader(Offset.zero & size);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.umber.withValues(alpha: .28);

    final left = Path()
      ..moveTo(7, 8)
      ..lineTo(13, 3)
      ..lineTo(35, 4)
      ..lineTo(36, 42)
      ..lineTo(10, 45)
      ..lineTo(5, 39)
      ..close();
    final right = Path()
      ..moveTo(40, 5)
      ..lineTo(63, 3)
      ..lineTo(70, 9)
      ..lineTo(68, 39)
      ..lineTo(63, 44)
      ..lineTo(39, 42)
      ..close();
    for (final slab in [left, right]) {
      canvas.drawPath(slab.shift(const Offset(0, 2)), shadow);
      canvas.drawPath(slab, stone);
      canvas.drawPath(slab, edge);
    }
    final incision = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 2
      ..color = colors.covenantGold;
    canvas.drawLine(const Offset(15, 20), const Offset(30, 20), incision);
    canvas.drawLine(const Offset(46, 28), const Offset(62, 28), incision);
  }

  @override
  bool shouldRepaint(covariant _FirstPrayerGuideMarkPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
