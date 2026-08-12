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
    // Original, provenance-tracked tones are added in the next implementation
    // task. Sound is deliberately a safe no-op until those assets exist.
  }
}
