import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

void main() {
  test('reports unavailable once, not per tap', () async {
    final recognizer = _FakeRecognizer(available: false);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);

    expect(await controller.ensureAvailable(), isFalse);
    expect(await controller.ensureAvailable(), isFalse);
    expect(recognizer.initializeCalls, 1);
    expect(controller.notice, speechUnavailableNotice);
  });

  test('stays available without a notice', () async {
    final controller = SpeechCaptureController(
      recognizer: _FakeRecognizer(available: true),
    );
    addTearDown(controller.dispose);

    expect(await controller.ensureAvailable(), isTrue);
    expect(controller.notice, isNull);
  });

  test('overlapping calls resolve availability once', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);

    final answers = await Future.wait([
      controller.ensureAvailable(),
      controller.ensureAvailable(),
    ]);

    expect(answers, [true, true]);
    expect(
      recognizer.initializeCalls,
      1,
      reason: 'a second initialisation would take the callbacks with it',
    );
  });

  test('listening is declared before the platform reports anything', () async {
    final recognizer = _FakeRecognizer(available: true)
      ..listenGate = Completer<void>();
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();

    final started = controller.listen(onWords: (_) {});
    await pumpEventQueue();

    expect(
      controller.isListening,
      isTrue,
      reason: 'the platform has reported nothing yet',
    );
    expect(
      recognizer.reportedListening,
      isFalse,
      reason: 'so this cannot have been read back from the platform',
    );

    recognizer.listenGate!.complete();

    expect(await started, isTrue);
  });

  test('delivers words while listening', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    final heard = <String>[];
    await controller.listen(onWords: heard.add);
    recognizer.reportListening(true);

    recognizer.emit('the morning');
    recognizer.emit('the morning light');

    expect(heard, ['the morning', 'the morning light']);
  });

  test('a second tap does not open a second session', () async {
    final recognizer = _FakeRecognizer(available: true)
      ..listenGate = Completer<void>();
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();

    final first = controller.listen(onWords: (_) {});
    final second = controller.listen(onWords: (_) {});
    recognizer.listenGate!.complete();

    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(recognizer.listenCalls, 1);
  });

  test(
    'stopping clears listening even when the recogniser is silent',
    () async {
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
      addTearDown(controller.dispose);
      await controller.ensureAvailable();
      await controller.listen(onWords: (_) {});

      await controller.stop();

      expect(controller.isListening, isFalse);
      expect(recognizer.stopCalls, 1);
    },
  );

  test('a stop that fails still ends the session here', () async {
    final recognizer = _FakeRecognizer(available: true, failsToStop: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    await expectLater(controller.stop(), throwsA(isA<_PlatformFailure>()));
    expect(
      controller.isListening,
      isFalse,
      reason: 'the session is over on the platform either way',
    );
  });

  test('a session that cannot start leaves the field alone', () async {
    final recognizer = _FakeRecognizer(available: true)..complains = true;
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();

    final started = await controller.listen(onWords: (_) {});

    expect(started, isFalse);
    expect(controller.isListening, isFalse);
  });

  test('an unavailable recogniser never starts a session', () async {
    final recognizer = _FakeRecognizer(available: false);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);

    expect(await controller.listen(onWords: (_) {}), isFalse);
    expect(recognizer.listenCalls, 0);
    expect(controller.notice, speechUnavailableNotice);
  });

  test('notifies listeners once when availability is resolved', () async {
    final controller = SpeechCaptureController(
      recognizer: _FakeRecognizer(available: true),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.ensureAvailable();

    expect(notifications, 1);
  });

  test('a late status change ends the session', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    recognizer.reportListening(false);

    expect(
      controller.isListening,
      isFalse,
      reason: 'the platform can end a session without being asked',
    );
  });

  test('a repeated status change is taken once', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});
    var notifications = 0;
    controller.addListener(() => notifications++);

    // A transient error reports the session as ended and may report it again.
    recognizer.reportListening(false);
    recognizer.reportListening(false);

    expect(notifications, 1);
  });

  test('an unavailability report does not retire the mic', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    recognizer.reportUnavailable();

    expect(
      controller.isAvailable,
      isTrue,
      reason: 'only initialisation can answer whether speech runs here',
    );
    expect(controller.notice, speechUnavailableNotice);
    expect(
      await controller.listen(onWords: (_) {}),
      isFalse,
      reason: 'a session is already running',
    );
    await controller.stop();
    expect(await controller.listen(onWords: (_) {}), isTrue);
  });

  test('a final result after a stop still reaches the consumer', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    final heard = <String>[];
    await controller.listen(onWords: heard.add);
    recognizer.reportListening(true);
    recognizer.emit('I pra');

    await controller.stop();
    // The platform arms a timer that delivers the last hypothesis after a
    // stop, and dropping it would strand the person mid-word.
    recognizer.emit('I pray');

    expect(heard, ['I pra', 'I pray']);
  });

  group('a leftover final result from the session it replaced', () {
    // The platform hands results to whichever session is listening now, so a
    // stopped session's final result is stamped with the session that replaced
    // it and has already passed the token that fenced it out. Applying it
    // would say the sentence twice, into a field the person has since typed.
    Future<(SpeechCaptureController, _FakeRecognizer, List<String>)>
    restart() async {
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
      await controller.ensureAvailable();
      await controller.listen(onWords: (_) {});
      recognizer.emit('I pra');
      await controller.stop();
      final live = <String>[];
      await controller.listen(onWords: live.add);
      return (controller, recognizer, live);
    }

    test('is dropped as the new session\'s first callback', () async {
      final (controller, recognizer, live) = await restart();
      addTearDown(controller.dispose);

      recognizer.emit('I pray');

      expect(
        live,
        isEmpty,
        reason: 'the stopped session already said this, into the same field',
      );
    });

    test('does not swallow a session that opens with something else', () async {
      final (controller, recognizer, live) = await restart();
      addTearDown(controller.dispose);

      recognizer.emit('and peace');

      expect(live, ['and peace']);
    });

    // A new session whose opening words extend the stopped session's last
    // words is indistinguishable from a leftover result, and is dropped with
    // one. Recorded here because the cost is real: recognised words grow, so
    // the second callback restores everything the first held, and that is the
    // whole bound on what can be lost.
    test(
      'costs a new session its first callback when it opens the same way',
      () async {
        final (controller, recognizer, live) = await restart();
        addTearDown(controller.dispose);

        recognizer.emit('I pray for');
        recognizer.emit('I pray for you');

        expect(live, [
          'I pray for you',
        ], reason: 'the second callback carries what the dropped one held');
      },
    );

    test('is only ever dropped as the first callback', () async {
      final (controller, recognizer, live) = await restart();
      addTearDown(controller.dispose);
      // Dropped, but not remembered: what a later stop reports as the session's
      // words is what the consumer was actually told.
      recognizer.emit('I pray for');
      await controller.stop();
      final later = <String>[];
      await controller.listen(onWords: later.add);
      recognizer.emit('I pray for you');

      expect(later, ['I pray for you']);
      expect(
        live,
        isEmpty,
        reason:
            'this session opened the same way, so it lost its first callback',
      );
    });

    test('a session the platform ended on its own arms nothing', () async {
      // Nothing asked for this session to end, so there is no evidence of what it
      // was about to say and no leftover to expect.
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
      addTearDown(controller.dispose);
      await controller.ensureAvailable();
      await controller.listen(onWords: (_) {});
      recognizer.emit('I pra');
      recognizer.reportListening(false);
      final live = <String>[];
      await controller.listen(onWords: live.add);

      recognizer.emit('I pray');

      expect(live, ['I pray']);
    });

    test('a session stopped without words arms nothing', () async {
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
      addTearDown(controller.dispose);
      await controller.ensureAvailable();
      await controller.listen(onWords: (_) {});
      await controller.stop();
      final live = <String>[];
      await controller.listen(onWords: live.add);

      // Nothing to match, so even a first callback that repeats is the
      // person's own.
      recognizer.emit('I pray');

      expect(live, ['I pray']);
    });

    test('is not expected a second time, after another restart', () async {
      final (controller, recognizer, live) = await restart();
      addTearDown(controller.dispose);
      recognizer.emit('I pray for');
      await controller.stop();
      final later = <String>[];
      await controller.listen(onWords: later.add);

      recognizer.emit('I pray again');

      expect(
        later,
        ['I pray again'],
        reason:
            'the words no longer carry what the session it replaced ended on',
      );
    });
  });

  test('words from a superseded session are dropped', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    addTearDown(controller.dispose);
    await controller.ensureAvailable();
    final first = <String>[];
    await controller.listen(onWords: first.add);
    await controller.stop();
    final second = <String>[];
    await controller.listen(onWords: second.add);
    recognizer.reportListening(true);

    // The first session's platform may still be holding a listener, and its
    // words would land on a field the person has since edited.
    recognizer.emitTo(0, 'I pra');
    recognizer.emitTo(1, 'I pray');

    expect(first, isEmpty);
    expect(second, ['I pray']);
  });

  test(
    'a session that starts after disposal does not open the microphone',
    () async {
      final recognizer = _FakeRecognizer(available: true)
        ..listenGate = Completer<void>();
      final controller = SpeechCaptureController(recognizer: recognizer);
      await controller.ensureAvailable();
      final started = controller.listen(onWords: (_) {});
      await pumpEventQueue();

      controller.dispose();
      await pumpEventQueue();
      recognizer.listenGate!.complete();

      expect(await started, isFalse);
      expect(
        recognizer.stoppedWhileLive,
        isTrue,
        reason: 'the platform opened a microphone nobody was left to hold',
      );
    },
  );

  test('words arriving after disposal are dropped', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    final heard = <String>[];
    await controller.listen(onWords: heard.add);

    controller.dispose();
    recognizer.emit('the morning');

    expect(heard, isEmpty);
  });

  test('platform callbacks after disposal are ignored', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    controller.dispose();

    expect(
      () {
        recognizer.reportListening(false);
        recognizer.reportUnavailable();
      },
      returnsNormally,
      reason: 'a disposed notifier may not notify',
    );
  });

  test('disposing without a session asks the platform for nothing', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();

    controller.dispose();
    await pumpEventQueue();

    expect(
      recognizer.stopCalls,
      0,
      reason: 'the microphone was never opened, so it need not be closed',
    );
  });
}

/// A second implementation of [SpeechRecognizer], which is what makes that
/// interface worth having.
class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({required this.available, this.failsToStop = false});

  final bool available;
  final bool failsToStop;

  /// Makes [listen] throw, the way an implementation that breaks its own
  /// contract would. Set before the call rather than passed to it, so the
  /// signature here stays exactly the interface's.
  var complains = false;

  /// Holds [listen] open until completed, the way a slow platform does.
  Completer<void>? listenGate;

  /// Whether a [stop] arrived while the platform was actually listening, which
  /// is the only kind that closes a microphone.
  var stoppedWhileLive = false;

  var initializeCalls = 0;
  var listenCalls = 0;
  var stopCalls = 0;
  bool _listening = false;
  void Function(bool)? _onListeningChanged;
  final _wordCallbacks = <void Function(String)>[];
  VoidCallback? _onUnavailable;

  /// What the platform last reported, which is never assumed to match what the
  /// controller believes.
  bool get reportedListening => _listening;

  /// Delivers words to the newest session, as the platform would.
  void emit(String words) => emitTo(_wordCallbacks.length - 1, words);

  /// Delivers words to one session by index, so a test can model a superseded
  /// session the platform has not finished dropping.
  void emitTo(int session, String words) => _wordCallbacks[session](words);

  void reportListening(bool listening) {
    _listening = listening;
    _onListeningChanged?.call(listening);
  }

  void reportUnavailable() => _onUnavailable?.call();

  @override
  Future<bool> initialize({
    void Function(bool listening)? onListeningChanged,
    VoidCallback? onUnavailable,
  }) async {
    initializeCalls++;
    _onListeningChanged = onListeningChanged;
    _onUnavailable = onUnavailable;
    if (!available) onUnavailable?.call();
    return available;
  }

  @override
  Future<void> listen({required void Function(String words) onWords}) async {
    listenCalls++;
    if (complains) throw const _PlatformFailure();
    _wordCallbacks.add(onWords);
    await listenGate?.future;
    reportListening(true);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (_listening) stoppedWhileLive = true;
    _listening = false;
    if (failsToStop) throw const _PlatformFailure();
  }
}

/// The shape of what the platform actually throws. `SpeechToText`'s own
/// failures implement [Exception], which is why a session that cannot start is
/// caught rather than a programming error being swallowed.
class _PlatformFailure implements Exception {
  const _PlatformFailure();
}
