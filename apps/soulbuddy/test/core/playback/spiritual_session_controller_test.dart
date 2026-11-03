import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';

void main() {
  test('pauses resumes and completes one active session', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));

    await controller.pause();
    await controller.resume();
    controller.updateProgress(
      position: const Duration(seconds: 4),
      duration: const Duration(seconds: 10),
    );
    expect(controller.state.position, const Duration(seconds: 4));
    await controller.complete();

    expect(events, ['pause:one', 'resume:one', 'complete:one']);
    expect(controller.state.status, SpiritualSessionStatus.idle);
  });

  test('starting another session closes the active one', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));
    await controller.begin(_session('two', events));

    expect(events, ['close:one']);
    expect(controller.state.session?.id, 'two');
  });

  test('closes the previous owner before starting a shared player', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));

    await controller.begin(
      _session('two', events, onStart: () async => events.add('start:two')),
    );

    expect(events, ['close:one', 'start:two']);
    expect(controller.state.session?.id, 'two');
  });

  test('capture pauses listening without completing the practice', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));

    await controller.pauseForCapture();
    await controller.pauseForCapture();

    expect(events, ['pause:one']);
    expect(controller.state.status, SpiritualSessionStatus.paused);
  });

  test('capture closes without marking practice complete', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events, canPause: false));

    await controller.pauseForCapture();

    expect(events, ['close:one']);
    expect(controller.state.status, SpiritualSessionStatus.idle);
  });

  test('capture reservation blocks queued resume and new playback', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));
    await controller.pause();

    final queuedResume = controller.resume();
    final owner = Object();
    final acquired = controller.acquireCapture(owner);
    final blockedStart = controller.begin(
      _session('two', events, onStart: () async => events.add('start:two')),
    );
    await queuedResume;
    await acquired;
    await blockedStart;

    expect(controller.isCapturing, true);
    expect(controller.state.session?.id, 'one');
    expect(controller.state.status, SpiritualSessionStatus.paused);
    expect(events, ['pause:one']);
    controller.releaseCapture(owner);
    await controller.resume();
    expect(events, ['pause:one', 'resume:one']);
  });

  test('one capture owner cannot release another owner', () async {
    final controller = SpiritualSessionController();
    final first = Object();
    final second = Object();
    await controller.acquireCapture(first);
    await controller.acquireCapture(second);

    controller.releaseCapture(first);
    controller.releaseCapture(first);
    expect(controller.isCapturing, true);
    controller.releaseCapture(second);
    expect(controller.isCapturing, false);
    controller.dispose();
    controller.releaseCapture(second);
  });

  test('playback completion during pause cannot revive the session', () async {
    final paused = Completer<void>();
    final pausing = Completer<void>();
    final controller = SpiritualSessionController();
    await controller.begin(
      _session('one', [], onPause: () async {
        pausing.complete();
        await paused.future;
      }),
    );

    final operation = controller.pauseForCapture();
    await pausing.future;
    controller.finishPlayback('one');
    paused.complete();
    await operation;

    expect(controller.state.status, SpiritualSessionStatus.idle);
  });

  test('late progress and completion from an old owner are ignored', () async {
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', []));
    await controller.begin(_session('two', []));

    controller.updateProgress(
      sessionId: 'one',
      position: const Duration(seconds: 8),
      duration: const Duration(seconds: 10),
    );
    controller.finishPlayback('one');

    expect(controller.state.session?.id, 'two');
    expect(controller.state.position, Duration.zero);
  });

  test('disposing prevents queued playback commands', () async {
    final events = <String>[];
    final pausing = Completer<void>();
    final paused = Completer<void>();
    final controller = SpiritualSessionController();
    await controller.begin(
      _session('one', events, onPause: () async {
        pausing.complete();
        await paused.future;
      }),
    );

    final pause = controller.pause();
    await pausing.future;
    final resume = controller.resume();
    controller.dispose();
    paused.complete();
    await pause;
    await resume;
    await Future<void>.delayed(Duration.zero);

    expect(events, ['close:one']);
  });
}

SpiritualSession _session(
  String id,
  List<String> events, {
  bool canPause = true,
  Future<void> Function()? onStart,
  Future<void> Function()? onPause,
}) => SpiritualSession(
  id: id,
  kind: SpiritualSessionKind.memory,
  title: 'Session $id',
  route: '/remember/$id',
  canPause: canPause,
  onStart: onStart,
  onPause: onPause ?? () async => events.add('pause:$id'),
  onResume: () async => events.add('resume:$id'),
  onComplete: () async => events.add('complete:$id'),
  onClose: () async => events.add('close:$id'),
);
