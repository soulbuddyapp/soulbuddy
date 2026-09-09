import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        if (session == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Card(
          key: const Key('spiritual-session-mini-player'),
          elevation: 8,
          color: scheme.inverseSurface,
          margin: EdgeInsets.zero,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(_icon(session.kind), color: scheme.onInverseSurface),
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
                              ?.copyWith(color: scheme.onInverseSurface),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: state.progress ?? 0,
                          minHeight: 3,
                          backgroundColor: scheme.onInverseSurface.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (session.canPause)
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
                      state.status == SpiritualSessionStatus.paused
                          ? controller.resume()
                          : controller.pause(),
                    ),
                    color: scheme.onInverseSurface,
                    icon: Icon(
                      state.status == SpiritualSessionStatus.paused
                          ? Icons.play_arrow
                          : Icons.pause,
                    ),
                  ),
                IconButton(
                  key: const Key('spiritual-session-complete'),
                  tooltip: session.completionLabel,
                  onPressed: () => unawaited(controller.complete()),
                  color: scheme.onInverseSurface,
                  icon: const Icon(Icons.check_circle_outline),
                ),
                IconButton(
                  key: const Key('spiritual-session-close'),
                  tooltip: 'Close player',
                  onPressed: () => unawaited(controller.close()),
                  color: scheme.onInverseSurface,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

IconData _icon(SpiritualSessionKind kind) => switch (kind) {
  SpiritualSessionKind.memory ||
  SpiritualSessionKind.altar => Icons.mic_outlined,
  SpiritualSessionKind.prayer ||
  SpiritualSessionKind.person => Icons.front_hand_outlined,
  SpiritualSessionKind.sacredHour => Icons.notifications_active_outlined,
  SpiritualSessionKind.meditation => Icons.self_improvement,
};
