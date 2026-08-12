import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import 'app_feedback.dart';

class CompletionFeedback extends StatefulWidget {
  const CompletionFeedback({
    required this.cue,
    required this.animate,
    required this.semanticLabel,
    super.key,
  });

  final AppFeedbackVisualCue cue;
  final bool animate;
  final String semanticLabel;

  @override
  State<CompletionFeedback> createState() => _CompletionFeedbackState();
}

class _CompletionFeedbackState extends State<CompletionFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _showsMotes =>
      widget.cue == AppFeedbackVisualCue.lightMotes && widget.animate;
  bool get _showsRipple =>
      widget.cue == AppFeedbackVisualCue.completion && widget.animate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _showsMotes ? 850 : 260),
    );
    if (widget.animate && (_showsMotes || _showsRipple)) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: 88,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              if (_showsRipple)
                Transform.scale(
                  key: const Key('completion-feedback-ripple'),
                  scale: 0.6 + _controller.value * 0.55,
                  child: Opacity(
                    opacity: 1 - _controller.value,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x339A6B2F),
                      ),
                      child: SizedBox.square(dimension: 72),
                    ),
                  ),
                ),
              if (_showsMotes)
                SizedBox.square(
                  key: const Key('completion-feedback-motes'),
                  dimension: 88,
                  child: Stack(children: _motes(_controller.value)),
                ),
              Transform.scale(
                scale: widget.animate
                    ? Curves.easeOutBack.transform(_controller.value)
                    : 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceMuted,
                  ),
                  child: SizedBox.square(
                    key: Key('completion-feedback-check'),
                    dimension: 48,
                    child: Icon(Icons.check, color: AppColors.actionStrong),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _motes(double progress) {
    return List.generate(10, (index) {
      final angle = index * (2 * math.pi / 10) - math.pi / 2;
      final distance = 17 + progress * 22;
      final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);
      return Positioned(
        left: 42 + math.cos(angle) * distance,
        top: 42 + math.sin(angle) * distance,
        child: Opacity(
          opacity: opacity,
          child: SizedBox.square(
            key: ValueKey('completion-feedback-mote-$index'),
            dimension: index.isEven ? 4 : 3,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      );
    });
  }
}
