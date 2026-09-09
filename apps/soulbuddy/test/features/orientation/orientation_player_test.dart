import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';

void main() {
  test('preparation uses a bundled source and speech audio focus', () async {
    final native = FakeNativePlayer();
    final player = AudioplayersOrientationPlayer(player: native);
    await player.prepare('assets/audio/welcome.mp3');
    expect((native.source as AssetSource).path, 'audio/welcome.mp3');
    expect(native.context!.android.contentType, AndroidContentType.speech);
    expect(native.context!.android.audioFocus, AndroidAudioFocus.gain);
    expect(native.releaseMode, ReleaseMode.stop);
    expect(native.resumeCalls, 0);
    await player.close();
    await player.close();
    expect(native.stopCalls, 1);
    expect(native.disposeCalls, 1);
  });

  test(
    'media queries started before a seek cannot emit stale highlights',
    () async {
      final native = FakeNativePlayer();
      final player = AudioplayersOrientationPlayer(player: native);
      final positions = <Duration>[];
      final subscription = player.positions.listen(positions.add);
      native.positionGate = Completer<Duration>();
      final staleQuery = native.updater!.update();
      await player.seek(const Duration(seconds: 3));
      native.positionGate!.complete(const Duration(seconds: 20));
      await staleQuery;
      await Future<void>.delayed(Duration.zero);
      expect(positions, isEmpty);
      native.positionGate = null;
      await native.updater!.update();
      await Future<void>.delayed(Duration.zero);
      expect(positions, [const Duration(seconds: 3)]);
      await subscription.cancel();
      await player.close();
    },
  );

  test(
    'disposing during a pending media query does not emit to a closed stream',
    () async {
      final native = FakeNativePlayer();
      final player = AudioplayersOrientationPlayer(player: native);
      native.positionGate = Completer<Duration>();
      final query = native.updater!.update();
      await player.close();
      native.positionGate!.complete(const Duration(seconds: 20));
      await expectLater(query, completes);
    },
  );
}

class FakeNativePlayer implements AudioPlayer {
  PositionUpdater? updater;
  Completer<Duration>? positionGate;
  Duration position = Duration.zero;
  AudioContext? context;
  @override
  Source? source;
  @override
  ReleaseMode releaseMode = ReleaseMode.release;
  int stopCalls = 0;
  int disposeCalls = 0;
  int resumeCalls = 0;
  @override
  set positionUpdater(PositionUpdater? value) {
    updater = value;
  }

  @override
  Stream<Duration> get onPositionChanged => updater!.positionStream;
  @override
  Future<Duration?> getCurrentPosition() async =>
      positionGate == null ? position : await positionGate!.future;
  @override
  Future<void> setPlayerMode(PlayerMode mode) async {}
  @override
  Future<void> setAudioContext(AudioContext value) async {
    context = value;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode value) async {
    releaseMode = value;
  }

  @override
  Future<void> setSource(Source value) async {
    source = value;
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await updater?.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
