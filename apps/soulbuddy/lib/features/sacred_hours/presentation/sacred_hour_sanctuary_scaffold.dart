import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/covenant_grace_tokens.dart';

/// The unobstructed visual frame used while a Sacred Hour is in progress.
class SacredHourSanctuaryScaffold extends StatelessWidget {
  const SacredHourSanctuaryScaffold({
    required this.child,
    required this.onExit,
    super.key,
  });

  final Widget child;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CovenantGraceColors>()!;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.65),
            radius: 1.3,
            colors: [colors.lightWash, colors.parchment, colors.limestoneLight],
            stops: const [0, .52, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  opacity: 1,
                  child: Semantics(
                    image: true,
                    label: 'Golden light and a figure ascending',
                    child: Image.asset(
                      'assets/images/sanctuary/sacred_hour_portal.webp',
                      key: const Key('sacred-hour-portal'),
                      width: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 220, height: 440),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'End Sacred Hour',
                  onPressed: onExit,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.parchment.withValues(alpha: 0),
                      colors.parchment.withValues(alpha: .96),
                      colors.parchment,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      76,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .72,
                      ),
                      child: SingleChildScrollView(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
