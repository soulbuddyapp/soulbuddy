import 'dart:async';

import 'package:flutter/foundation.dart';

import 'spiritual_session.dart';

class SpiritualSessionController extends ChangeNotifier {
  SpiritualSessionState _state = const SpiritualSessionState();
  SpiritualSessionState get state => _state;

  Future<void> _tail = Future.value();
  bool _disposed = false;
  final Set<Object> _captureOwners = Set<Object>.identity();

  bool get isCapturing => _captureOwners.isNotEmpty;

  Future<void> begin(SpiritualSession session) => _run(() async {
    if (isCapturing) return;
    final current = _state.session;
    if (current != null &&
        (current.id != session.id || session.onStart != null)) {
      await current.onClose();
    }
    if (_disposed || isCapturing) return;
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.playing,
      ),
    );
    await session.onStart?.call();
  });

  Future<void> pause() => _run(() async {
    final session = _state.session;
    if (session == null ||
        !session.canPause ||
        _state.status != SpiritualSessionStatus.playing) {
      return;
    }
    await session.onPause();
    if (!identical(_state.session, session)) return;
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.paused,
        position: _state.position,
        duration: _state.duration,
      ),
    );
  });

  Future<void> resume() => _run(() async {
    if (isCapturing) return;
    final session = _state.session;
    if (session == null ||
        !session.canPause ||
        _state.status != SpiritualSessionStatus.paused) {
      return;
    }
    await session.onResume();
    if (!identical(_state.session, session)) return;
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.playing,
        position: _state.position,
        duration: _state.duration,
      ),
    );
  });

  /// Quiets the active session without recording a prayer or completing a
  /// practice. A later return to listening always requires an explicit tap.
  Future<void> pauseForCapture() => _run(_pauseForCapture);

  /// Reserves the microphone before awaiting playback shutdown. Registering
  /// the owner immediately also blocks playback commands already queued.
  Future<void> acquireCapture(Object owner) {
    if (_disposed) {
      return Future.error(StateError('The audio session is closed.'));
    }
    if (_captureOwners.add(owner)) notifyListeners();
    return _run(() async {
      if (!_captureOwners.contains(owner)) return;
      try {
        await _pauseForCapture();
      } catch (_) {
        releaseCapture(owner);
        rethrow;
      }
    });
  }

  void releaseCapture(Object owner) {
    if (_captureOwners.remove(owner) && !_disposed) notifyListeners();
  }

  Future<void> _pauseForCapture() async {
    final session = _state.session;
    if (session == null) return;
    if (!session.canPause) {
      await session.onClose();
      if (identical(_state.session, session)) {
        _emit(const SpiritualSessionState());
      }
      return;
    }
    if (_state.status == SpiritualSessionStatus.paused) return;
    await session.onPause();
    if (!identical(_state.session, session)) return;
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.paused,
        position: _state.position,
        duration: _state.duration,
      ),
    );
  }

  Future<void> complete() => _run(() async {
    final session = _state.session;
    if (session == null) return;
    await session.onComplete();
    if (identical(_state.session, session)) {
      _emit(const SpiritualSessionState());
    }
  });

  Future<void> close() => _run(() async {
    final session = _state.session;
    if (session == null) return;
    await session.onClose();
    if (identical(_state.session, session)) {
      _emit(const SpiritualSessionState());
    }
  });

  void updateProgress({
    required Duration position,
    required Duration duration,
    String? sessionId,
    SpiritualSessionStatus? status,
  }) {
    final session = _state.session;
    if (_disposed ||
        session == null ||
        (sessionId != null && session.id != sessionId)) {
      return;
    }
    _emit(
      SpiritualSessionState(
        session: session,
        status: status ?? _state.status,
        position: position,
        duration: duration,
        error: _state.error,
      ),
    );
  }

  void finishPlayback(String sessionId) {
    if (_state.session?.id != sessionId) return;
    _emit(const SpiritualSessionState());
  }

  Future<void> _run(Future<void> Function() command) {
    if (_disposed) return Future.value();
    final operation = _tail
        .then((_) async {
          if (!_disposed) await command();
        })
        .catchError((Object error) {
          final session = _state.session;
          if (session != null) {
            _emit(
              SpiritualSessionState(
                session: session,
                status: SpiritualSessionStatus.error,
                position: _state.position,
                duration: _state.duration,
                error: 'Playback could not continue.',
              ),
            );
          }
          throw error;
        });
    _tail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  void _emit(SpiritualSessionState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _captureOwners.clear();
    unawaited(
      _tail
          .then<void>((_) async {
            await _state.session?.onClose();
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}
