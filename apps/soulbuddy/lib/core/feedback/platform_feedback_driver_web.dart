import 'app_feedback.dart';
import 'platform_feedback_driver.dart';

PlatformFeedbackDriver createPlatformFeedbackDriver() =>
    const _WebPlatformFeedbackDriver();

class _WebPlatformFeedbackDriver implements PlatformFeedbackDriver {
  const _WebPlatformFeedbackDriver();

  @override
  Future<void> playHaptic(AppHaptic haptic) async {}

  @override
  Future<void> playSound(AppFeedbackSound sound) async {}
}
