import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'app_feedback.dart';

Future<void> playFeedbackAsset(
  AppFeedbackSound sound, {
  AudioContext? context,
}) {
  final player = AudioPlayer();
  return playFeedbackOutput(
    completed: player.onPlayerComplete,
    start: () => player.play(
      AssetSource(switch (sound) {
        AppFeedbackSound.softTap => 'audio/feedback/soft_tap.wav',
        AppFeedbackSound.gentleCompletion =>
          'audio/feedback/gentle_completion.wav',
        AppFeedbackSound.publicationEligible =>
          'audio/feedback/publication_eligible.wav',
        AppFeedbackSound.sacredGentleChime =>
          'audio/sacred_hours/sacred_gentle_chime.wav',
      }),
      volume: 0.18,
      ctx: context,
    ),
    dispose: player.dispose,
  );
}

/// One owner cleans up the output after either playback or a failed start.
/// A very short cue can finish before start returns, so subscribe first.
Future<void> playFeedbackOutput({
  required Stream<void> completed,
  required Future<void> Function() start,
  required Future<void> Function() dispose,
}) async {
  final end = Completer<AsyncError?>();
  void finish([AsyncError? failure]) {
    if (!end.isCompleted) {
      end.complete(failure);
    }
  }

  StreamSubscription<void>? subscription;
  AsyncError? failure;
  try {
    subscription = completed.listen(
      (_) => finish(),
      onError: (Object error, StackTrace stack) =>
          finish(AsyncError(error, stack)),
      onDone: () => finish(
        AsyncError(
          StateError('Feedback ended without a completion event'),
          StackTrace.current,
        ),
      ),
    );
    await start();
    failure = await end.future;
  } catch (error, stack) {
    failure = AsyncError(error, stack);
  }

  // In particular, dispose closes the completion stream. Remove our listener
  // before disposing so that stream closure cannot start a second cleanup.
  try {
    await subscription?.cancel();
  } catch (error, stack) {
    failure ??= AsyncError(error, stack);
  }
  try {
    await dispose();
  } catch (error, stack) {
    failure ??= AsyncError(error, stack);
  }

  if (failure != null) {
    Error.throwWithStackTrace(failure.error, failure.stackTrace);
  }
}
