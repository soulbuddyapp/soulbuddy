import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'app_feedback.dart';
import 'platform_feedback_driver.dart';

PlatformFeedbackDriver createPlatformFeedbackDriver() =>
    const _IoPlatformFeedbackDriver();

class _IoPlatformFeedbackDriver implements PlatformFeedbackDriver {
  const _IoPlatformFeedbackDriver();

  @override
  Future<void> playHaptic(AppHaptic haptic) => switch (haptic) {
    AppHaptic.selection => HapticFeedback.selectionClick(),
    AppHaptic.light => HapticFeedback.lightImpact(),
    AppHaptic.medium => HapticFeedback.mediumImpact(),
    AppHaptic.warning => HapticFeedback.vibrate(),
    AppHaptic.heavy => HapticFeedback.heavyImpact(),
  };

  @override
  Future<void> playSound(AppFeedbackSound sound) async {
    final player = AudioPlayer();
    final completion = player.onPlayerComplete.first.whenComplete(
      player.dispose,
    );
    try {
      await player.play(
        AssetSource(_assetPath(sound)),
        volume: 0.18,
        ctx: AudioContextConfig(
          respectSilence: true,
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
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
