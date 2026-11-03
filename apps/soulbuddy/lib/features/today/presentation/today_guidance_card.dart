import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/sacred_piece.dart';
import '../../../core/presentation/sacred_piece_medallion.dart';
import '../domain/today_guidance.dart';

class TodayGuidanceCard extends StatelessWidget {
  const TodayGuidanceCard({
    super.key,
    required this.guidance,
    required this.onOpen,
    this.actionControl,
  });

  final TodayGuidanceCardValue guidance;
  final VoidCallback onOpen;
  final Widget? actionControl;

  @override
  Widget build(BuildContext context) {
    final piece = pieceForTodayGuidance(guidance.key);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Card(
        key: Key('today-guidance-${guidance.key.name}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SacredPieceMedallion(
                key: Key('today-guidance-piece-${piece.name}'),
                piece: piece,
                decorative: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guidance.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(guidance.body),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child:
                          actionControl ??
                          TextButton(
                            key: const Key('today-guidance-action'),
                            onPressed: onOpen,
                            child: Text(guidance.actionLabel),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

SacredPiece pieceForTodayGuidance(TodayGuidanceKey key) => switch (key) {
  TodayGuidanceKey.duePrayer ||
  TodayGuidanceKey.beginPrayer => SacredPiece.prayer,
  TodayGuidanceKey.dueAltar => SacredPiece.altar,
  TodayGuidanceKey.dueAction || TodayGuidanceKey.startGoal => SacredPiece.goal,
  TodayGuidanceKey.dueRemembrance ||
  TodayGuidanceKey.keepMemory => SacredPiece.remember,
  TodayGuidanceKey.circleAccountability => SacredPiece.circle,
  TodayGuidanceKey.duePerson ||
  TodayGuidanceKey.rememberPerson => SacredPiece.person,
  TodayGuidanceKey.remainClose ||
  TodayGuidanceKey.quietReturn => SacredPiece.today,
};
