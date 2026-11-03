import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/feedback/feedback_sound_output.dart';

void main() {
  test('failed start cancels completion before disposing exactly once', () async {
    final output = _Output();
    final startError = StateError('feedback asset could not be prepared');
    output.disposeError = StateError('secondary disposal failure');

    await expectLater(
      playFeedbackOutput(
        completed: output.completed.stream,
        start: () async => throw startError,
        dispose: output.dispose,
      ),
      throwsA(same(startError)),
    );

    expect(output.disposals, 1);
    expect(output.subscribedAtDisposal, isFalse);
    expect(output.completed.isClosed, isTrue);
  });

  test('completion during start waits for preparation before disposal', () async {
    final output = _Output();
    final started = Completer<void>();
    final result = playFeedbackOutput(
      completed: output.completed.stream,
      start: () {
        output.completed.add(null);
        return started.future;
      },
      dispose: output.dispose,
    );

    expect(output.disposals, 0);
    started.complete();
    await result;

    expect(output.disposals, 1);
    expect(output.subscribedAtDisposal, isFalse);
  });

  test('a playback stream failure reaches the caller after cleanup', () async {
    final output = _Output();
    final playbackError = StateError('feedback output disconnected');
    await expectLater(
      playFeedbackOutput(
        completed: output.completed.stream,
        start: () async => output.completed.addError(playbackError),
        dispose: output.dispose,
      ),
      throwsA(same(playbackError)),
    );

    expect(output.disposals, 1);
    expect(output.subscribedAtDisposal, isFalse);
  });

  test('a disposal failure after playback reaches the caller', () async {
    final output = _Output();
    final cleanupError = StateError('feedback output could not release');
    output.disposeError = cleanupError;
    await expectLater(
      playFeedbackOutput(
        completed: output.completed.stream,
        start: () async => output.completed.add(null),
        dispose: output.dispose,
      ),
      throwsA(same(cleanupError)),
    );

    expect(output.disposals, 1);
  });
}

class _Output {
  final completed = StreamController<void>.broadcast(sync: true);
  int disposals = 0;
  bool? subscribedAtDisposal;
  Object? disposeError;

  Future<void> dispose() async {
    disposals++;
    subscribedAtDisposal = completed.hasListener;
    // The real player closes its completion stream during disposal.
    await completed.close();
    if (disposeError case final error?) {
      throw error;
    }
  }
}
