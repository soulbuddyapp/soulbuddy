import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/covenant_grace_tokens.dart';
import '../../sacred_hours/presentation/sacred_hours_onboarding_page.dart';

typedef OnboardingAction = Future<void> Function();

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onBeginWithGoal,
    required this.onSkip,
    this.onKeepSacredHours,
    super.key,
  });

  final OnboardingAction onBeginWithGoal;
  final OnboardingAction onSkip;
  final Future<void> Function(SacredHoursOnboardingSelection selection)?
  onKeepSacredHours;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _scenes = [
    _OnboardingScene(
      title: 'Bring what matters',
      body:
          'Start with something you want help with. Prayer, Scripture, and the next faithful step can gather around it.',
    ),
    _OnboardingScene(
      title: 'Remember what God has done',
      body:
          'Keep encounters, promises, Scripture, people, and lessons close instead of letting them disappear into yesterday.',
    ),
    _OnboardingScene(
      title: 'Walk it today',
      body:
          'Keep only what deserves attention now. Return, act, pray, and remember without scores or shame.',
    ),
  ];

  final _pageController = PageController();
  var _page = 0;
  var _working = false;
  var _sacredHours = SacredHoursOnboardingSelection.defaults();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_working) return;
    if (_page < _scenes.length) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) {
        _pageController.jumpToPage(_page + 1);
      } else {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    await _run(() async {
      await widget.onKeepSacredHours?.call(_sacredHours);
      await widget.onBeginWithGoal();
    });
  }

  Future<void> _run(OnboardingAction action) async {
    setState(() => _working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        'SoulBuddy',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextButton(
                        key: const Key('onboarding-skip'),
                        onPressed: _working ? null : () => _run(widget.onSkip),
                        child: const Text('Go to Today'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      key: const Key('onboarding-pages'),
                      controller: _pageController,
                      itemCount: _scenes.length + 1,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (context, index) {
                        if (index == _scenes.length) {
                          return SacredHoursOnboardingPage(
                            selection: _sacredHours,
                            onChanged: (value) =>
                                setState(() => _sacredHours = value),
                          );
                        }
                        return _ScenePage(
                          scene: _scenes[index],
                          illuminatedMarks: index + 1,
                          index: index,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < _scenes.length + 1; index++)
                        AnimatedContainer(
                          key: Key('onboarding-dot-$index'),
                          duration: const Duration(milliseconds: 180),
                          width: index == _page ? 24 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    key: const Key('onboarding-primary'),
                    onPressed: _working ? null : _continue,
                    child: Text(
                      _working
                          ? 'Opening…'
                          : _page == _scenes.length
                          ? 'Keep these hours'
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePage extends StatelessWidget {
  const _ScenePage({
    required this.scene,
    required this.illuminatedMarks,
    required this.index,
  });

  final _OnboardingScene scene;
  final int illuminatedMarks;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Welcome scene ${index + 1} of 3: ${scene.title}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * 0.56,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                key: Key('onboarding-visual-$index'),
                height: 190,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WelcomeSlabsPainter(
                    colors:
                        theme.extension<CovenantGraceColors>() ??
                        CovenantGraceColors.light,
                    illuminatedMarks: illuminatedMarks,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                scene.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Text(
                  scene.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlabsPainter extends CustomPainter {
  const _WelcomeSlabsPainter({
    required this.colors,
    required this.illuminatedMarks,
  });

  final CovenantGraceColors colors;
  final int illuminatedMarks;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.lightWash.withValues(alpha: 0.72),
          colors.lightWash.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.52),
        width: size.width * 0.9,
        height: size.height * 1.08,
      ),
      glow,
    );

    final left = Path()
      ..moveTo(size.width * .17, size.height * .15)
      ..lineTo(size.width * .23, size.height * .06)
      ..lineTo(size.width * .47, size.height * .08)
      ..lineTo(size.width * .49, size.height * .88)
      ..lineTo(size.width * .2, size.height * .92)
      ..lineTo(size.width * .15, size.height * .82)
      ..close();
    final right = Path()
      ..moveTo(size.width * .53, size.height * .09)
      ..lineTo(size.width * .77, size.height * .06)
      ..lineTo(size.width * .84, size.height * .16)
      ..lineTo(size.width * .82, size.height * .84)
      ..lineTo(size.width * .77, size.height * .92)
      ..lineTo(size.width * .51, size.height * .88)
      ..close();

    for (final slab in [left, right]) {
      canvas.drawPath(
        slab.shift(Offset(0, size.height * .025)),
        Paint()..color = colors.umber.withValues(alpha: .13),
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
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = colors.umber.withValues(alpha: .33),
      );
    }

    final marks = [
      (Offset(size.width * .25, size.height * .36), size.width * .17),
      (Offset(size.width * .25, size.height * .61), size.width * .17),
      (Offset(size.width * .59, size.height * .48), size.width * .17),
    ];
    for (var index = 0; index < marks.length; index++) {
      final (start, length) = marks[index];
      final active = index < illuminatedMarks;
      canvas.drawLine(
        start,
        Offset(start.dx + length, start.dy),
        Paint()
          ..strokeCap = StrokeCap.square
          ..strokeWidth = active ? 3 : 2
          ..color = active
              ? colors.covenantGold
              : colors.umber.withValues(alpha: .25),
      );
      if (active) {
        canvas.drawCircle(
          Offset(start.dx + length / 2, start.dy),
          8,
          Paint()..color = colors.lightWash.withValues(alpha: .28),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeSlabsPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.illuminatedMarks != illuminatedMarks;
  }
}

class _OnboardingScene {
  const _OnboardingScene({required this.title, required this.body});

  final String title;
  final String body;
}
