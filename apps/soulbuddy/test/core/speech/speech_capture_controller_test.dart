import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_controller.dart';
import 'package:soulbuddy/core/speech/speech_recognizer.dart';

void main() {
  test('reports unavailable once, not per tap', () async {
    final recognizer = _FakeRecognizer(available: false);
    final controller = SpeechCaptureController(recognizer: recognizer);

    expect(await controller.ensureAvailable(), isFalse);
    expect(await controller.ensureAvailable(), isFalse);
    expect(recognizer.initializeCalls, 1);
    expect(controller.notice, speechUnavailableNotice);
  });

  test('stays available without a notice', () async {
    final controller = SpeechCaptureController(
      recognizer: _FakeRecognizer(available: true),
    );

    expect(await controller.ensureAvailable(), isTrue);
    expect(controller.notice, isNull);
  });

  test(
    'starts listening without waiting for the recogniser to agree',
    () async {
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
      await controller.ensureAvailable();

      final started = await controller.listen(onWords: (_) {});

      expect(started, isTrue);
      expect(controller.isListening, isTrue);
      expect(recognizer.isListening, isTrue);
    },
  );

  test('delivers words while listening', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    final heard = <String>[];
    await controller.listen(onWords: heard.add);

    recognizer.emit('the morning');
    recognizer.emit('the morning light');

    expect(heard, ['the morning', 'the morning light']);
  });

  test(
    'stopping clears listening even when the recogniser is silent',
    () async {
      final recognizer = _FakeRecognizer(available: true);
      final controller = SpeechCaptureController(recognizer: recognizer);
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
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    await expectLater(controller.stop(), throwsStateError);
    expect(
      controller.isListening,
      isFalse,
      reason: 'the session is over on the platform either way',
    );
  });

  test('a session that cannot start leaves the field alone', () async {
    final recognizer = _FakeRecognizer(available: true)..complains = true;
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();

    final started = await controller.listen(onWords: (_) {});

    expect(started, isFalse);
    expect(controller.isListening, isFalse);
  });

  test('an unavailable recogniser never starts a session', () async {
    final recognizer = _FakeRecognizer(available: false);
    final controller = SpeechCaptureController(recognizer: recognizer);

    expect(await controller.listen(onWords: (_) {}), isFalse);
    expect(recognizer.listenCalls, 0);
    expect(controller.notice, speechUnavailableNotice);
  });

  test('notifies listeners when availability is resolved', () async {
    final controller = SpeechCaptureController(
      recognizer: _FakeRecognizer(available: true),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.ensureAvailable();

    expect(notifications, greaterThan(0));
  });

  test('a late status change ends the session', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
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
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});
    var notifications = 0;
    controller.addListener(() => notifications++);

    // A transient error reports the session as ended and may report it again.
    recognizer.reportListening(false);
    recognizer.reportListening(false);

    expect(notifications, 1);
  });

  test('a permanent failure stops offering the microphone', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    recognizer.reportUnavailable();

    expect(controller.isAvailable, isFalse);
    expect(controller.notice, speechUnavailableNotice);
    expect(await controller.listen(onWords: (_) {}), isFalse);
    expect(
      recognizer.initializeCalls,
      1,
      reason: 'the question was already answered, so it is not asked again',
    );
  });

  test('disposing releases an open session', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();
    await controller.listen(onWords: (_) {});

    controller.dispose();
    await pumpEventQueue();

    expect(recognizer.stopCalls, 1);
  });

  test('disposing does not disturb a session that never started', () async {
    final recognizer = _FakeRecognizer(available: true);
    final controller = SpeechCaptureController(recognizer: recognizer);
    await controller.ensureAvailable();

    controller.dispose();
    await pumpEventQueue();

    expect(recognizer.stopCalls, 0);
  });
}

/// A second implementation of [SpeechRecognizer], which is what makes that
/// interface worth having.
class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({required this.available, this.failsToStop = false});

  final bool available;
  final bool failsToStop;

  /// Makes the next [listen] throw, the way an implementation that breaks its
  /// own contract would. Set before the call rather than passed to it, so the
  /// signature here stays exactly the interface's.
  var complains = false;

  var initializeCalls = 0;
  var listenCalls = 0;
  var stopCalls = 0;
  var _listening = false;
  void Function(bool)? _onListeningChanged;
  void Function(String)? _onWords;
  VoidCallback? _onUnavailable;

  @override
  bool get isListening => _listening;

  void emit(String words) => _onWords?.call(words);

  void reportListening(bool listening) => _onListeningChanged?.call(listening);

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
    if (complains) throw StateError('could not start');
    _listening = true;
    _onWords = onWords;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (failsToStop) throw StateError('platform stop failed');
    _listening = false;
  }
}
