import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'app_feedback.dart';
import 'platform_feedback_driver.dart';

PlatformFeedbackDriver createPlatformFeedbackDriver() =>
    const _WebPlatformFeedbackDriver();

class _WebPlatformFeedbackDriver implements PlatformFeedbackDriver {
  const _WebPlatformFeedbackDriver();

  @override
  Future<void> playHaptic(AppHaptic haptic) async {}

  @override
  Future<void> playSound(AppFeedbackSound sound) async {
    final player = AudioPlayer();
    final completion = player.onPlayerComplete.first.whenComplete(
      player.dispose,
    );
    try {
      await player.play(AssetSource(_assetPath(sound)), volume: 0.18);
      unawaited(completion);
    } catch (_) {
      await player.dispose();
      rethrow;
    }
  }
}

String _assetPath(AppFeedbackSound sound) => switch (sound) {
  AppFeedbackSound.softTap => 'audio/feedback/soft_tap.wav',
  AppFeedbackSound.gentleCompletion => 'audio/feedback/gentle_completion.wav',
  AppFeedbackSound.publicationEligible =>
    'audio/feedback/publication_eligible.wav',
};
