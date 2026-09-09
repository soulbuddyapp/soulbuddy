import 'package:flutter/material.dart';

import '../../../core/design/covenant_grace_tokens.dart';

/// A factual visual path through the eight orientation Nuggets.
class OrientationPath extends StatelessWidget {
  const OrientationPath({
    required this.completedCount,
    this.total = 8,
    super.key,
  });

  final int completedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors =
        theme.extension<CovenantGraceColors>() ??
        (theme.brightness == Brightness.dark
            ? CovenantGraceColors.dark
            : CovenantGraceColors.light);
    final completed = completedCount.clamp(0, total);
    final current = completed == total ? null : completed;
    return Semantics(
      label: '$completed of $total Nuggets complete',
      child: ExcludeSemantics(
        child: Row(
          key: const Key('orientation-path'),
          children: [
            for (var index = 0; index < total; index++) ...[
              Container(
                key: Key('orientation-path-marker-$index'),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < completed
                      ? scheme.primary
                      : index == current
                      ? colors.lightWash
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: index == current
                        ? colors.covenantGold
                        : scheme.outlineVariant,
                    width: index == current ? 2 : 1,
                  ),
                  boxShadow: index == current
                      ? [
                          BoxShadow(
                            color: colors.covenantGold.withValues(alpha: 0.28),
                            blurRadius: 10,
                          ),
                        ]
                      : const [],
                ),
                child: Icon(
                  index < completed ? Icons.check : Icons.circle,
                  size: index < completed ? 15 : 8,
                  color: index < completed
                      ? scheme.onPrimary
                      : index == current
                      ? colors.covenantGold
                      : scheme.onSurfaceVariant,
                ),
              ),
              if (index != total - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < completed
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
