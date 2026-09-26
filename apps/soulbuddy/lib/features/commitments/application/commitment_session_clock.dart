/// Monotonic foreground time. Wall-clock changes and background time cannot
/// complete a meditation, and narration is separate from the timed silence.
class CommitmentSessionClock {
  CommitmentSessionClock({required this.planned, Duration Function()? elapsed})
    : assert(planned > Duration.zero),
      _elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter;

  final Duration planned;
  final Duration Function() _elapsed;
  Duration _accumulated = Duration.zero;
  Duration? _started;

  bool get running => _started != null && !completed;
  Duration get actual {
    final value =
        _accumulated +
        (_started == null ? Duration.zero : _elapsed() - _started!);
    return value > planned ? planned : value;
  }

  Duration get remaining => planned - actual;
  bool get completed => actual >= planned;
  void start() {
    if (_started == null && !completed) _started = _elapsed();
  }

  void pause() {
    _accumulated = actual;
    _started = null;
  }
}

extension on Stopwatch {
  Duration elapsedGetter() => elapsed;
}
