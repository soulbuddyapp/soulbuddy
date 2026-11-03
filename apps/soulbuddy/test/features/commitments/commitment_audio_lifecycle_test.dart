import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_audio.dart';

void main() {
  test(
    'pause during preparation cannot play late; explicit resume restarts safely',
    () async {
      final native = _Native();
      final audio = CommitmentAudio(player: native);
      final starting = audio.playPath(
        'audio/sacred_hours/sacred_still_bell.wav',
      );
      await native.preparing.future;
      final pausing = audio.pause();
      native.ready.complete();
      await Future.wait([starting, pausing]);
      expect(native.playCalls, 0);
      await audio.resume();
      expect(native.playCalls, 1);
      expect(audio.playing, isTrue);
      await audio.pause();
      await audio.resume();
      expect(
        native.resumeCalls,
        1,
        reason: 'A loaded bell has no caption asset but must resume.',
      );
      audio.dispose();
    },
  );
  test(
    'exit during preparation cancels late audio and discards resume',
    () async {
      final native = _Native();
      final audio = CommitmentAudio(player: native);
      final starting = audio.playPath(
        'audio/sacred_hours/sacred_still_bell.wav',
      );
      await native.preparing.future;
      final stopping = audio.stopForRecording();
      native.ready.complete();
      await Future.wait([starting, stopping]);
      await audio.resume();
      expect(native.playCalls, 0);
      expect(audio.playing, isFalse);
      audio.dispose();
    },
  );

  test('recording handoff waits for native instruction audio to stop', () async {
    final native = _Native()..stopping = Completer<void>();
    final audio = CommitmentAudio(player: native);
    var canRecord = false;
    final stopping = audio.stopForRecording().then((_) => canRecord = true);
    await Future<void>.delayed(Duration.zero);
    expect(canRecord, isFalse);
    native.stopping!.complete();
    await stopping;
    expect(canRecord, isTrue);
    audio.dispose();
  });

  test('failed instruction stop blocks recording and remains retryable', () async {
    final native = _Native()..stopError = StateError('output unavailable');
    final audio = CommitmentAudio(player: native);
    await expectLater(audio.stopForRecording(), throwsStateError);
    expect(audio.unavailable, isTrue);
    native.stopError = null;
    await audio.stopForRecording();
    audio.dispose();
  });
}

class _Native implements AudioPlayer {
  final preparing = Completer<void>();
  final ready = Completer<void>();
  Completer<void>? stopping;
  Object? stopError;
  int playCalls = 0, resumeCalls = 0;
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  Future<void> stop() async {
    if (stopError case final error?) throw error;
    await stopping?.future;
  }
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    if (!preparing.isCompleted) preparing.complete();
    await ready.future;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
