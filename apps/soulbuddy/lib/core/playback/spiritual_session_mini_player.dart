import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/sacred_piece.dart';
import '../design/covenant_grace_tokens.dart';
import '../presentation/sacred_piece_medallion.dart';
import '../presentation/sacred_surface.dart';
import '../presentation/sanctuary_artwork.dart';
import 'spiritual_session.dart';
import 'spiritual_session_providers.dart';

class SpiritualSessionMiniPlayer extends ConsumerWidget {
  const SpiritualSessionMiniPlayer({required this.onOpen, super.key});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(spiritualSessionControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final session = state.session;
        if (session == null || controller.isCapturing) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final piece = _piece(session.kind);
        final colors =
            theme.extension<CovenantGraceColors>() ??
            (theme.brightness == Brightness.dark
                ? CovenantGraceColors.dark
                : CovenantGraceColors.light);
        return SacredSurface(
          key: const Key('spiritual-session-mini-player'),
          marble: true,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  KeyedSubtree(
                    key: const Key('spiritual-session-artwork'),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            session.kind == SpiritualSessionKind.prayer
                                ? SanctuaryArt.prayer
                                : session.kind ==
                                      SpiritualSessionKind.meditation
                                ? SanctuaryArt.scripture
                                : SanctuaryArt.renewal,
                            width: 48,
                            height: 52,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: SacredPieceMedallion(
                            key: Key('spiritual-session-piece-${piece.name}'),
                            piece: piece,
                            selected: true,
                            decorative: true,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => onOpen(session.route),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          if (state.error case final error?)
                            Text(
                              error,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            )
                          else
                            LinearProgressIndicator(
                              key: const Key('spiritual-session-progress'),
                              value: state.progress ?? 0,
                              minHeight: 3,
                              color: colors.covenantGold,
                              backgroundColor: scheme.outlineVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (session.canPause &&
                      state.status != SpiritualSessionStatus.error)
                    IconButton(
                      key: Key(
                        state.status == SpiritualSessionStatus.paused
                            ? 'spiritual-session-resume'
                            : 'spiritual-session-pause',
                      ),
                      tooltip: state.status == SpiritualSessionStatus.paused
                          ? 'Resume'
                          : 'Pause',
                      onPressed: () => unawaited(
                        (state.status == SpiritualSessionStatus.paused
                                ? controller.resume()
                                : controller.pause())
                            .catchError((Object _) {}),
                      ),
                      color: scheme.onSurface,
                      icon: Icon(
                        state.status == SpiritualSessionStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                      ),
                    ),
                  if (session.showCompletion)
                    IconButton(
                      key: const Key('spiritual-session-complete'),
                      tooltip: session.completionLabel,
                      onPressed: () => unawaited(
                        controller.complete().catchError((Object _) {}),
                      ),
                      color: scheme.onSurface,
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                  IconButton(
                    key: const Key('spiritual-session-close'),
                    tooltip: 'Close player',
                    onPressed: () =>
                        unawaited(controller.close().catchError((Object _) {})),
                    color: scheme.onSurface,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

SacredPiece _piece(SpiritualSessionKind kind) => switch (kind) {
  SpiritualSessionKind.memory => SacredPiece.remember,
  SpiritualSessionKind.altar => SacredPiece.altar,
  SpiritualSessionKind.prayer => SacredPiece.prayer,
  SpiritualSessionKind.person => SacredPiece.person,
  SpiritualSessionKind.sacredHour => SacredPiece.sacredHour,
  SpiritualSessionKind.meditation => SacredPiece.meditation,
};
