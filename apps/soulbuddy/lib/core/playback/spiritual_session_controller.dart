import 'dart:async';

import 'package:flutter/foundation.dart';

import 'spiritual_session.dart';

class SpiritualSessionController extends ChangeNotifier {
  SpiritualSessionState _state = const SpiritualSessionState();
  SpiritualSessionState get state => _state;

  Future<void> _tail = Future.value();
  bool _disposed = false;

  Future<void> begin(SpiritualSession session) => _run(() async {
    final current = _state.session;
    if (current != null && current.id != session.id) {
      await current.onClose();
    }
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.playing,
      ),
    );
  });

  Future<void> pause() => _run(() async {
    final session = _state.session;
    if (session == null ||
        !session.canPause ||
        _state.status != SpiritualSessionStatus.playing) {
      return;
    }
    await session.onPause();
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
    final session = _state.session;
    if (session == null ||
        !session.canPause ||
        _state.status != SpiritualSessionStatus.paused) {
      return;
    }
    await session.onResume();
    _emit(
      SpiritualSessionState(
        session: session,
        status: SpiritualSessionStatus.playing,
        position: _state.position,
        duration: _state.duration,
      ),
    );
  });

  Future<void> complete() => _run(() async {
    final session = _state.session;
    if (session == null) return;
    await session.onComplete();
    _emit(const SpiritualSessionState());
  });

  Future<void> close() => _run(() async {
    final session = _state.session;
    if (session == null) return;
    await session.onClose();
    _emit(const SpiritualSessionState());
  });

  void updateProgress({
    required Duration position,
    required Duration duration,
  }) {
    final session = _state.session;
    if (_disposed || session == null) return;
    _emit(
      SpiritualSessionState(
        session: session,
        status: _state.status,
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
    final operation = _tail.then((_) => command()).catchError((Object error) {
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
    _disposed = true;
    super.dispose();
  }
}
