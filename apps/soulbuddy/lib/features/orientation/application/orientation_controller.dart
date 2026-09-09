import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/orientation_progress_repository.dart';
import '../domain/orientation_course.dart';
import 'orientation_player.dart';

class OrientationController extends ChangeNotifier {
  OrientationController({
    required this.course,
    required this.transcript,
    required OrientationPlayer player,
    required OrientationProgressRepository repository,
  }) : _player = player,
       _repository = repository;

  static const speeds = OrientationPreferences.speeds;
  final OrientationCourse course;
  final OrientationTranscript transcript;
  final OrientationPlayer _player;
  final OrientationProgressRepository _repository;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _lastSavedPosition = Duration.zero;
  double _speed = 1;
  double _textScale = 1;
  bool _playing = false;
  bool _loading = true;
  bool _busy = false;
  bool _completed = false;
  bool _ready = false;
  bool _progressRestored = false;
  bool _preferencesRestored = false;
  bool _progressRestoreFailed = false;
  bool _preferencesRestoreFailed = false;
  bool _seeking = false;
  bool _atEnd = false;
  bool _isClosing = false;
  bool _disposed = false;
  String? _error;
  String? _persistenceWarning;
  Future<void> _actions = Future.value();
  Future<void> _writes = Future.value();
  Future<void>? _closing;

  Duration get position => _position;
  double get speed => _speed;
  double get textScale => _textScale;
  bool get playing => _playing;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get completed => _completed;
  String? get error => _error;
  String? get persistenceWarning {
    if (_progressRestoreFailed) {
      return 'Your listening progress could not be restored.';
    }
    if (_preferencesRestoreFailed) {
      return 'Your listening preferences could not be restored.';
    }
    return _persistenceWarning;
  }

  Future<void> initialize() => _run(() async {
    _loading = true;
    _error = null;
    _ready = false;
    _notify();
    if (!_progressRestored) {
      try {
        final progress = await _repository.load(course.id);
        _position = _bounded(progress.position);
        _completed = progress.completed;
        _progressRestored = true;
        _progressRestoreFailed = false;
        _lastSavedPosition = _position;
      } catch (_) {
        _progressRestoreFailed = true;
      }
    }
    if (!_preferencesRestored) {
      try {
        final preferences = await _repository.loadPreferences();
        _speed = preferences.speed;
        _textScale = preferences.textScale;
        _preferencesRestored = true;
        _preferencesRestoreFailed = false;
      } catch (_) {
        _preferencesRestoreFailed = true;
      }
    }
    if (_isClosing) return;
    if (_subscriptions.isEmpty) {
      _subscriptions.addAll([
        _player.positions.listen(_onPosition, onError: _onStreamError),
        _player.playing.listen(_onPlaying, onError: _onStreamError),
        _player.completions.listen(
          (_) => _onComplete(),
          onError: _onStreamError,
        ),
      ]);
    }
    await _player.prepare(course.audioAsset);
    if (_isClosing) return;
    await _player.setSpeed(_speed);
    if (_isClosing) return;
    // Some native engines resume when changing playback parameters.
    await _player.pause();
    if (_isClosing) return;
    if (_position > Duration.zero) await _seek(_position);
    _playing = false;
    _ready = true;
    _atEnd = _position >= course.duration;
  });

  Future<void> toggle() => _run(() async {
    if (!_ready) return;
    if (_playing) {
      await _pause();
    } else {
      if (_atEnd || _position >= course.duration) await _seek(Duration.zero);
      if (_isClosing) return;
      await _player.play();
      if (!_isClosing) _playing = true;
    }
  });

  Future<void> pause() => _run(_pause);

  Future<void> _pause() async {
    if (_ready) await _player.pause();
    _playing = false;
    await _persist();
  }

  Future<void> seek(Duration position) => _run(() async {
    if (!_ready) return;
    await _seek(_bounded(position));
    await _persist();
  });

  Future<void> _seek(Duration target) async {
    _seeking = true;
    try {
      await _player.seek(target);
      if (_isClosing) return;
      _position = target;
      _atEnd = false;
    } finally {
      _seeking = false;
    }
  }

  Future<void> setSpeed(double speed) => _run(() async {
    if (!speed.isFinite || !speeds.contains(speed)) return;
    if (_ready) {
      final wasPlaying = _playing;
      await _player.setSpeed(speed);
      if (!wasPlaying) {
        await _player.pause();
        _playing = false;
      }
    }
    _speed = speed;
    await _persistPreferences();
  });

  Future<void> setTextScale(double textScale) => _run(() async {
    if (!textScale.isFinite) return;
    _textScale = textScale.clamp(.85, 1.6);
    await _persistPreferences();
  });

  Future<void> startAgain() => _run(() async {
    if (!_ready) return;
    await _player.pause();
    _playing = false;
    await _seek(Duration.zero);
    await _persist();
  });

  Future<void> saveProgress() =>
      _isClosing ? (_closing ?? Future.value()) : _persist();

  void _onPosition(Duration value) {
    if (_isClosing || !_ready || _seeking || _atEnd) return;
    final position = _bounded(value);
    // The adapter invalidates pre-seek queries. A valid post-seek sample can
    // arrive late or reflect a native clamp, so reconcile to the media clock.
    _position = position;
    _notify();
    if ((_position - _lastSavedPosition).inMilliseconds.abs() >= 5000) {
      _lastSavedPosition = _position;
      unawaited(_persist());
    }
  }

  void _onPlaying(bool value) {
    if (_isClosing || !_ready) return;
    final wasPlaying = _playing;
    _playing = value;
    _notify();
    if (wasPlaying && !value) unawaited(_persist());
  }

  void _onComplete() {
    if (_isClosing || !_ready || _seeking) return;
    _completed = true;
    _playing = false;
    _atEnd = true;
    _position = course.duration;
    _notify();
    unawaited(_persist());
  }

  void _onStreamError(Object error, [StackTrace? stack]) {
    if (_isClosing) return;
    _error = 'Audio is unavailable. You can keep reading or retry.';
    _ready = false;
    _playing = false;
    _notify();
    unawaited(_player.pause().catchError((Object _) {}));
    unawaited(_persist());
  }

  Duration _bounded(Duration position) => Duration(
    milliseconds: position.inMilliseconds.clamp(
      0,
      course.duration.inMilliseconds,
    ),
  );

  Future<void> _persist() {
    // The route may close before its first initialization microtask. Never
    // overwrite an unread device record with the controller's initial zero.
    if (!_progressRestored) return Future.value();
    final snapshot = OrientationProgress(
      position: _position,
      completed: _completed,
    );
    return _write(() => _repository.save(course.id, snapshot));
  }

  Future<void> _persistPreferences() {
    if (!_preferencesRestored) return Future.value();
    final snapshot = OrientationPreferences(
      speed: _speed,
      textScale: _textScale,
    );
    return _write(() => _repository.savePreferences(snapshot));
  }

  Future<void> _write(Future<void> Function() operation) {
    final next = _writes.then((_) async {
      try {
        await operation();
        _persistenceWarning = null;
      } catch (_) {
        _persistenceWarning =
            'Your listening progress could not be saved on this device.';
      }
      _notify();
    });
    _writes = next;
    return next;
  }

  Future<void> _run(Future<void> Function() action) {
    if (_isClosing) return Future.value();
    final next = _actions.then((_) async {
      if (_isClosing) return;
      _busy = true;
      _notify();
      try {
        await action();
      } catch (_) {
        _error = 'Audio is unavailable. You can keep reading or retry.';
        _ready = false;
        _playing = false;
        try {
          await _player.pause();
        } catch (_) {}
      } finally {
        _loading = false;
        _busy = false;
        _notify();
      }
    });
    _actions = next;
    return next;
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _isClosing = true;
    return _closing = _close();
  }

  Future<void> _close() async {
    await _actions;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    try {
      await _player.pause();
    } catch (_) {}
    _playing = false;
    await _persist();
    try {
      await _player.close();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed && !_isClosing) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
