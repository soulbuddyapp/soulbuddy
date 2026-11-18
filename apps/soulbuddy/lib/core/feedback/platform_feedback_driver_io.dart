import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'app_feedback.dart';
import 'feedback_sound_output.dart';
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
  Future<void> playSound(AppFeedbackSound sound) => playFeedbackAsset(
    sound,
    context: AudioContextConfig(
      respectSilence: true,
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build(),
  );
}
