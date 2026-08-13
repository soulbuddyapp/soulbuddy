import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/audio_asset_store.dart';
import '../domain/memory_audio.dart';

enum MemoryAudioDriverStatus { stopped, playing, paused, completed }

abstract interface class MemoryAudioPlayerDriver {
  Stream<Duration> get positionChanges;
  Stream<Duration> get durationChanges;
  Stream<MemoryAudioDriverStatus> get statusChanges;

  Future<void> play(AudioPlaybackSource source);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

enum MemoryAudioPlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

@immutable
class MemoryAudioPlaybackState {
  const MemoryAudioPlaybackState({
    this.assetId,
    this.status = MemoryAudioPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  final String? assetId;
  final MemoryAudioPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? error;
}

class MemoryAudioPlaybackCoordinator extends ChangeNotifier {
  MemoryAudioPlaybackCoordinator({
    required AudioAssetStore assetStore,
    required MemoryAudioPlayerDriver driver,
  }) : _assetStore = assetStore,
       _driver = driver {
    _subscriptions = [
      _driver.positionChanges.listen(_onPosition),
      _driver.durationChanges.listen(_onDuration),
      _driver.statusChanges.listen(_onDriverStatus),
    ];
  }

  final AudioAssetStore _assetStore;
  final MemoryAudioPlayerDriver _driver;
  late final List<StreamSubscription<Object?>> _subscriptions;
  MemoryAudioPlaybackState _state = const MemoryAudioPlaybackState();
  MemoryAudioPlaybackState get state => _state;
  bool _closed = false;
  Future<void> _commandTail = Future.value();

  Future<void> play(MemoryAudio audio) => _serialize(() async {
    if (_closed) return;
    if (_state.assetId == audio.id &&
        _state.status == MemoryAudioPlaybackStatus.paused) {
      await _driver.resume();
      _emit(
        MemoryAudioPlaybackState(
          assetId: audio.id,
          status: MemoryAudioPlaybackStatus.playing,
          position: _state.position,
          duration: _state.duration,
        ),
      );
      return;
    }
    if (_state.assetId != null) await _driver.stop();
    _emit(
      MemoryAudioPlaybackState(
        assetId: audio.id,
        status: MemoryAudioPlaybackStatus.loading,
        duration: audio.duration,
      ),
    );
    try {
      final source = await _assetStore.open(audio.storageKey);
      if (source == null) {
        _emit(
          MemoryAudioPlaybackState(
            assetId: audio.id,
            status: MemoryAudioPlaybackStatus.error,
            duration: audio.duration,
            error: 'This audio is not available on this device.',
          ),
        );
        return;
      }
      await _driver.play(source);
      _emit(
        MemoryAudioPlaybackState(
          assetId: audio.id,
          status: MemoryAudioPlaybackStatus.playing,
          duration: audio.duration,
        ),
      );
    } catch (_) {
      _emit(
        MemoryAudioPlaybackState(
          assetId: audio.id,
          status: MemoryAudioPlaybackStatus.error,
          duration: audio.duration,
          error: 'This audio could not be played just now.',
        ),
      );
    }
  });

  Future<void> pause() => _serialize(() async {
    if (_state.status != MemoryAudioPlaybackStatus.playing) return;
    await _driver.pause();
    _emit(
      MemoryAudioPlaybackState(
        assetId: _state.assetId,
        status: MemoryAudioPlaybackStatus.paused,
        position: _state.position,
        duration: _state.duration,
      ),
    );
  });

  Future<void> seek(Duration position) => _serialize(() async {
    if (_state.assetId == null) return;
    final bounded = position < Duration.zero
        ? Duration.zero
        : position > _state.duration
        ? _state.duration
        : position;
    await _driver.seek(bounded);
    _emit(
      MemoryAudioPlaybackState(
        assetId: _state.assetId,
        status: _state.status,
        position: bounded,
        duration: _state.duration,
        error: _state.error,
      ),
    );
  });

  Future<void> stop() => _serialize(() async {
    if (_state.assetId != null) await _driver.stop();
    _emit(const MemoryAudioPlaybackState());
  });

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _commandTail.catchError((Object _) {});
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _driver.stop();
    } catch (_) {
      // Disposal still releases the platform player.
    }
    await _driver.dispose();
  }

  Future<void> _serialize(Future<void> Function() command) {
    final result = _commandTail.then(
      (_) => command(),
      onError: (_) => command(),
    );
    _commandTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void _onPosition(Duration value) {
    if (_closed || _state.assetId == null) return;
    _emit(
      MemoryAudioPlaybackState(
        assetId: _state.assetId,
        status: _state.status,
        position: value > _state.duration ? _state.duration : value,
        duration: _state.duration,
        error: _state.error,
      ),
    );
  }

  void _onDuration(Duration value) {
    if (_closed || _state.assetId == null || value <= Duration.zero) return;
    _emit(
      MemoryAudioPlaybackState(
        assetId: _state.assetId,
        status: _state.status,
        position: _state.position,
        duration: value,
        error: _state.error,
      ),
    );
  }

  void _onDriverStatus(MemoryAudioDriverStatus value) {
    if (_closed || _state.assetId == null) return;
    final status = switch (value) {
      MemoryAudioDriverStatus.playing => MemoryAudioPlaybackStatus.playing,
      MemoryAudioDriverStatus.paused => MemoryAudioPlaybackStatus.paused,
      MemoryAudioDriverStatus.completed => MemoryAudioPlaybackStatus.completed,
      MemoryAudioDriverStatus.stopped => MemoryAudioPlaybackStatus.idle,
    };
    _emit(
      MemoryAudioPlaybackState(
        assetId: _state.assetId,
        status: status,
        position: value == MemoryAudioDriverStatus.completed
            ? _state.duration
            : _state.position,
        duration: _state.duration,
      ),
    );
  }

  void _emit(MemoryAudioPlaybackState value) {
    if (_closed) return;
    _state = value;
    notifyListeners();
  }
}
