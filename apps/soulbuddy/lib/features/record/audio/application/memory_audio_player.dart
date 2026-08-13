import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/audio_asset_store.dart';
import '../domain/memory_audio.dart';

enum MemoryAudioDriverStatus { stopped, playing, paused, completed }

abstract interface class MemoryAudioPlayerDriver {
  Stream<Duration> get positionChanges;
  Stream<Duration> get durationChanges;
  Stream<MemoryAudioDriverStatus> get statusChanges;

  Future<void> prepare(String assetId, AudioPlaybackSource source);
  Future<void> release(String assetId);
  Future<void> play(String assetId, AudioPlaybackSource source);
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
    this.preparedAssetLimit = 2,
  }) : _assetStore = assetStore,
       _driver = driver {
    if (preparedAssetLimit < 1) {
      throw ArgumentError.value(
        preparedAssetLimit,
        'preparedAssetLimit',
        'must be at least one',
      );
    }
    _subscriptions = [
      _driver.positionChanges.listen(_onPosition),
      _driver.durationChanges.listen(_onDuration),
      _driver.statusChanges.listen(_onDriverStatus),
    ];
  }

  final AudioAssetStore _assetStore;
  final MemoryAudioPlayerDriver _driver;
  final int preparedAssetLimit;
  final LinkedHashMap<String, AudioPlaybackSource> _preparedSources =
      LinkedHashMap();
  final Map<String, Future<bool>> _preparations = {};
  Future<void> _preparationTail = Future.value();
  late final List<StreamSubscription<Object?>> _subscriptions;
  MemoryAudioPlaybackState _state = const MemoryAudioPlaybackState();
  MemoryAudioPlaybackState get state => _state;
  bool _closed = false;
  bool _commandRunning = false;
  final Queue<_PendingAudioCommand> _pendingCommands = Queue();
  Future<void> _commandTail = Future.value();

  Future<bool> prepare(MemoryAudio audio) {
    if (_closed) return Future.value(false);
    if (_touchPrepared(audio.id)) return Future.value(true);
    return _preparations.putIfAbsent(audio.id, () => _prepare(audio));
  }

  Future<bool> _prepare(MemoryAudio audio) async {
    try {
      final source = await _assetStore.open(audio.storageKey);
      if (_closed || source == null) return false;
      var prepared = false;
      final operation = Future<void>.sync(() async {
        if (_closed) return;
        await _preparationTail;
        if (_touchPrepared(audio.id)) {
          prepared = true;
          return;
        }
        await _makePreparedRoom(audio.id);
        await _driver.prepare(audio.id, source);
        if (_closed) {
          await _driver.release(audio.id);
          return;
        }
        _preparedSources[audio.id] = source;
        prepared = true;
      });
      _preparationTail = operation.then<void>((_) {}).catchError((_) {});
      await operation;
      return prepared;
    } catch (_) {
      return false;
    } finally {
      _preparations.remove(audio.id);
    }
  }

  bool _touchPrepared(String assetId) {
    final source = _preparedSources.remove(assetId);
    if (source == null) return false;
    _preparedSources[assetId] = source;
    return true;
  }

  Future<void> _makePreparedRoom(String assetId) async {
    _preparedSources.remove(assetId);
    while (_preparedSources.length >= preparedAssetLimit) {
      final activeId = switch (_state.status) {
        MemoryAudioPlaybackStatus.loading ||
        MemoryAudioPlaybackStatus.playing ||
        MemoryAudioPlaybackStatus.paused => _state.assetId,
        _ => null,
      };
      final evictedId = _preparedSources.keys.firstWhere(
        (id) => id != activeId,
        orElse: () => _preparedSources.keys.first,
      );
      _preparedSources.remove(evictedId);
      await _driver.release(evictedId);
    }
  }

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
      if (!_preparedSources.containsKey(audio.id)) {
        await _preparations[audio.id];
      }
      final source =
          _preparedSources.remove(audio.id) ??
          await _assetStore.open(audio.storageKey);
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
      if (_preparedSources.length >= preparedAssetLimit) {
        await _makePreparedRoom(audio.id);
      }
      _preparedSources[audio.id] = source;
      await _driver.play(audio.id, source);
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
    _preparedSources.clear();
    _preparations.clear();
  }

  Future<void> _serialize(Future<void> Function() command) {
    final pending = _PendingAudioCommand(command);
    _pendingCommands.add(pending);
    _commandTail = pending.completer.future.then<void>(
      (_) {},
      onError: (_, _) {},
    );
    _drainCommands();
    return pending.completer.future;
  }

  void _drainCommands() {
    if (_commandRunning || _pendingCommands.isEmpty) return;
    _commandRunning = true;
    final pending = _pendingCommands.removeFirst();
    late final Future<void> result;
    try {
      result = pending.command();
    } catch (error, stackTrace) {
      result = Future.error(error, stackTrace);
    }
    result
        .then(
          (_) => pending.completer.complete(),
          onError: (Object error, StackTrace stackTrace) =>
              pending.completer.completeError(error, stackTrace),
        )
        .whenComplete(() {
          _commandRunning = false;
          _drainCommands();
        });
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

class _PendingAudioCommand {
  _PendingAudioCommand(this.command);

  final Future<void> Function() command;
  final Completer<void> completer = Completer<void>();
}
