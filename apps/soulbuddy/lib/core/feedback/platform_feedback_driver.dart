import 'app_feedback.dart';

abstract interface class PlatformFeedbackDriver {
  Future<void> playHaptic(AppHaptic haptic);

  Future<void> playSound(AppFeedbackSound sound);
}
