import 'package:flutter/foundation.dart';

enum SpiritualSessionKind {
  memory,
  altar,
  prayer,
  person,
  sacredHour,
  meditation,
}

enum SpiritualSessionStatus { idle, playing, paused, completed, error }

@immutable
class SpiritualSession {
  const SpiritualSession({
    required this.id,
    required this.kind,
    required this.title,
    required this.route,
    required this.canPause,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onClose,
    this.onStart,
    this.completionLabel = 'Complete',
  });

  final String id;
  final SpiritualSessionKind kind;
  final String title;
  final String route;
  final bool canPause;
  final String completionLabel;
  /// Starts both playback layers after the previous session has closed.
  ///
  /// Playback owners should use this callback instead of starting audio before
  /// the session controller's `begin`, which may stop a shared player.
  final Future<void> Function()? onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onComplete;
  final Future<void> Function() onClose;
}

@immutable
class SpiritualSessionState {
  const SpiritualSessionState({
    this.session,
    this.status = SpiritualSessionStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  final SpiritualSession? session;
  final SpiritualSessionStatus status;
  final Duration position;
  final Duration duration;
  final String? error;

  double? get progress => duration > Duration.zero
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1)
      : null;
}
