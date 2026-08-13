import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/audioplayers_memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';

void main() {
  test('release detaches a player before asynchronous teardown', () async {
    final first = _FakeAudioPlayer()..blockCancellation = true;
    final second = _FakeAudioPlayer();
    final players = <_FakeAudioPlayer>[first, second];
    final driver = AudioplayersMemoryAudioPlayerDriver(
      playerFactory: () => players.removeAt(0),
    );
    addTearDown(driver.dispose);
    const source = FileAudioPlaybackSource('memory.m4a');

    await driver.prepare('audio-1', source);
    final releasing = driver.release('audio-1');
    await first.cancellationStarted.future;
    await driver.play('audio-1', source);

    expect(first.resumeCalls, 0);
    expect(second.resumeCalls, 1);
    first.allowCancellation();
    await releasing;
  });
}

class _FakeAudioPlayer implements AudioPlayer {
  final cancellationStarted = Completer<void>();
  final _allowCancellation = Completer<void>();
  var blockCancellation = false;
  var resumeCalls = 0;

  void allowCancellation() => _allowCancellation.complete();

  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();

  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();

  @override
  Stream<PlayerState> get onPlayerStateChanged =>
      Stream<PlayerState>.multi((controller) {
        controller.onCancel = () async {
          if (!cancellationStarted.isCompleted) {
            cancellationStarted.complete();
          }
          if (blockCancellation) await _allowCancellation.future;
        };
      });

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setSource(Source source) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
