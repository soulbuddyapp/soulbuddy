import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/covenant_grace_tokens.dart';
import '../../sacred_hours/presentation/sacred_hours_onboarding_page.dart';

typedef OnboardingAction = Future<void> Function();
typedef OnboardingSensoryAction =
    Future<void> Function(OnboardingSensoryCue cue);

enum OnboardingSensoryCue { step, sacredHours, completed }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onBeginWithGoal,
    required this.onSkip,
    this.onKeepSacredHours,
    this.onSensoryCue,
    this.reduceMotion = false,
    super.key,
  });

  final OnboardingAction onBeginWithGoal;
  final OnboardingAction onSkip;
  final Future<void> Function(SacredHoursOnboardingSelection selection)?
  onKeepSacredHours;
  final OnboardingSensoryAction? onSensoryCue;
  final bool reduceMotion;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _scenes = [
    _OnboardingScene(
      title: 'Come as you are',
      body:
          'SoulBuddy helps you begin a daily communion with God—personal, simple, and yours.',
    ),
    _OnboardingScene(
      title: 'Remember His deeds',
      body:
          'Keep encounters, promises, Scripture, people, and lessons where you can return to them.',
    ),
    _OnboardingScene(
      title: 'Build a faithful rhythm',
      body: 'Bring what matters. Pray. Act. Remember what God has done.',
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
      final reduceMotion =
          widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
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
      await _emitCue(OnboardingSensoryCue.completed);
      await widget.onBeginWithGoal();
    });
  }

  Future<void> _emitCue(OnboardingSensoryCue cue) async {
    try {
      await widget.onSensoryCue?.call(cue);
    } on Object {
      // Sensory feedback must never interrupt the person's path.
    }
  }

  void _onPageChanged(int page) {
    final previous = _page;
    setState(() => _page = page);
    if (page <= previous) return;
    unawaited(
      _emitCue(
        page == _scenes.length
            ? OnboardingSensoryCue.sacredHours
            : OnboardingSensoryCue.step,
      ),
    );
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
                      onPageChanged: _onPageChanged,
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
                          active: _page == index,
                          reduceMotion:
                              widget.reduceMotion ||
                              MediaQuery.disableAnimationsOf(context),
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
                          : _page == 0
                          ? 'Begin'
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
    required this.active,
    required this.reduceMotion,
  });

  final _OnboardingScene scene;
  final int illuminatedMarks;
  final int index;
  final bool active;
  final bool reduceMotion;

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
                height: 210,
                width: double.infinity,
                child: _AnimatedWelcomeVisual(
                  index: index,
                  active: active,
                  reduceMotion: reduceMotion,
                  illuminatedMarks: illuminatedMarks,
                  colors:
                      theme.extension<CovenantGraceColors>() ??
                      CovenantGraceColors.light,
                ),
              ),
              if (index == 2) ...[
                const SizedBox(height: AppSpacing.sm),
                const _FaithfulRhythm(),
              ],
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

class _AnimatedWelcomeVisual extends StatefulWidget {
  const _AnimatedWelcomeVisual({
    required this.index,
    required this.active,
    required this.reduceMotion,
    required this.illuminatedMarks,
    required this.colors,
  });

  final int index;
  final bool active;
  final bool reduceMotion;
  final int illuminatedMarks;
  final CovenantGraceColors colors;

  @override
  State<_AnimatedWelcomeVisual> createState() => _AnimatedWelcomeVisualState();
}

class _AnimatedWelcomeVisualState extends State<_AnimatedWelcomeVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
    _syncAnimation(initial: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedWelcomeVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion ||
        (widget.active && !oldWidget.active)) {
      _syncAnimation();
    }
  }

  void _syncAnimation({bool initial = false}) {
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else if (widget.active) {
      _controller.forward(from: 0);
    } else if (!initial) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualKey = Key(
      widget.reduceMotion
          ? 'onboarding-visual-static-${widget.index}'
          : 'onboarding-visual-motion-${widget.index}',
    );
    return Semantics(
      label: 'A natural covenant slab lighting the daily rhythm',
      child: RepaintBoundary(
        key: visualKey,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _WelcomeSlabsPainter(
              colors: widget.colors,
              illuminatedMarks: widget.illuminatedMarks,
              progress: Curves.easeOutCubic.transform(_controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaithfulRhythm extends StatelessWidget {
  const _FaithfulRhythm();

  static const _steps = [
    (Icons.favorite_border, 'Bring'),
    (Icons.front_hand_outlined, 'Pray'),
    (Icons.directions_walk_outlined, 'Act'),
    (Icons.bookmark_outline, 'Remember'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Daily rhythm: Bring, Pray, Act, Remember',
      child: Row(
        children: [
          for (final (icon, label) in _steps)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 21, color: theme.colorScheme.primary),
                  const SizedBox(height: 3),
                  Text(label, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeSlabsPainter extends CustomPainter {
  const _WelcomeSlabsPainter({
    required this.colors,
    required this.illuminatedMarks,
    required this.progress,
  });

  final CovenantGraceColors colors;
  final int illuminatedMarks;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = progress.clamp(0.0, 1.0);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.lightWash.withValues(alpha: 0.72 * reveal),
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

    final slab = Path()
      ..moveTo(size.width * .27, size.height * .15)
      ..lineTo(size.width * .31, size.height * .08)
      ..lineTo(size.width * .47, size.height * .06)
      ..lineTo(size.width * .56, size.height * .09)
      ..lineTo(size.width * .72, size.height * .08)
      ..lineTo(size.width * .77, size.height * .17)
      ..lineTo(size.width * .75, size.height * .78)
      ..lineTo(size.width * .69, size.height * .86)
      ..lineTo(size.width * .53, size.height * .88)
      ..lineTo(size.width * .43, size.height * .85)
      ..lineTo(size.width * .29, size.height * .87)
      ..lineTo(size.width * .24, size.height * .78)
      ..lineTo(size.width * .25, size.height * .28)
      ..close();

    canvas.drawPath(
      slab.shift(Offset(0, size.height * .032 * reveal)),
      Paint()..color = colors.umber.withValues(alpha: .15 * reveal),
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
        ..strokeWidth = 1.2
        ..color = colors.umber.withValues(alpha: .34),
    );

    for (final y in [.24, .38, .72]) {
      canvas.drawLine(
        Offset(size.width * .30, size.height * y),
        Offset(size.width * .70, size.height * (y - .015)),
        Paint()
          ..strokeWidth = .7
          ..color = colors.umber.withValues(alpha: .09 * reveal),
      );
    }

    final marks = [
      (Offset(size.width * .34, size.height * .31), size.width * .32),
      (Offset(size.width * .34, size.height * .43), size.width * .27),
      (Offset(size.width * .34, size.height * .55), size.width * .31),
      (Offset(size.width * .34, size.height * .67), size.width * .24),
    ];
    for (var index = 0; index < marks.length; index++) {
      final (start, length) = marks[index];
      final active = index < illuminatedMarks;
      final markReveal = ((reveal - index * .1) / .55).clamp(0.0, 1.0);
      canvas.drawLine(
        start,
        Offset(start.dx + length, start.dy),
        Paint()
          ..strokeCap = StrokeCap.square
          ..strokeWidth = 2
          ..color = colors.umber.withValues(alpha: .22),
      );
      if (!active || markReveal == 0) continue;
      canvas.drawLine(
        start,
        Offset(start.dx + length * markReveal, start.dy),
        Paint()
          ..strokeCap = StrokeCap.square
          ..strokeWidth = 3
          ..color = colors.covenantGold,
      );
      canvas.drawCircle(
        Offset(start.dx + length * markReveal, start.dy),
        7 * markReveal,
        Paint()..color = colors.lightWash.withValues(alpha: .24 * markReveal),
      );
    }

    final waveEnvelope = math.sin(math.pi * reveal).abs();
    for (var index = 0; index < 9; index++) {
      final x = size.width * .39 + index * size.width * .028;
      final amplitude = (4 + 9 * math.sin(index * 1.35).abs()) * waveEnvelope;
      canvas.drawLine(
        Offset(x, size.height * .79 - amplitude / 2),
        Offset(x, size.height * .79 + amplitude / 2),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = colors.covenantGold.withValues(alpha: .55 * waveEnvelope),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeSlabsPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.illuminatedMarks != illuminatedMarks ||
        oldDelegate.progress != progress;
  }
}

class _OnboardingScene {
  const _OnboardingScene({required this.title, required this.body});

  final String title;
  final String body;
}
