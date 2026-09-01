import 'app_feedback.dart';
import 'app_feedback_preferences.dart';
import 'platform_feedback_driver.dart';

class AppFeedbackService {
  const AppFeedbackService({required PlatformFeedbackDriver driver})
    : _driver = driver;

  final PlatformFeedbackDriver _driver;

  Future<AppFeedbackResult> emit(
    AppFeedbackIntent intent, {
    required AppFeedbackPreferences preferences,
    bool systemReduceMotion = false,
  }) async {
    final mapping = _mappingFor(intent);
    if (preferences.hapticsEnabled) {
      try {
        await _driver.playHaptic(mapping.haptic);
      } catch (_) {
        // Sensory feedback is best-effort and must never fail the user action.
      }
    }
    final sound = mapping.sound;
    if (preferences.soundsEnabled && sound != null) {
      try {
        await _driver.playSound(sound);
      } catch (_) {
        // Sensory feedback is best-effort and must never fail the user action.
      }
    }

    final reducedMotion = systemReduceMotion || preferences.reducedMotion;
    return AppFeedbackResult(
      visualCue: reducedMotion
          ? _reducedVisualCue(mapping.visualCue)
          : mapping.visualCue,
      animate: !reducedMotion,
    );
  }
}

_FeedbackMapping _mappingFor(AppFeedbackIntent intent) => switch (intent) {
  AppFeedbackIntent.selection => const _FeedbackMapping(
    haptic: AppHaptic.selection,
    visualCue: AppFeedbackVisualCue.none,
  ),
  AppFeedbackIntent.saved => const _FeedbackMapping(
    haptic: AppHaptic.light,
    sound: AppFeedbackSound.softTap,
    visualCue: AppFeedbackVisualCue.check,
  ),
  AppFeedbackIntent.prayerCompleted => const _FeedbackMapping(
    haptic: AppHaptic.medium,
    sound: AppFeedbackSound.gentleCompletion,
    visualCue: AppFeedbackVisualCue.completion,
  ),
  AppFeedbackIntent.warning => const _FeedbackMapping(
    haptic: AppHaptic.warning,
    visualCue: AppFeedbackVisualCue.warning,
  ),
  AppFeedbackIntent.dismissed => const _FeedbackMapping(
    haptic: AppHaptic.selection,
    visualCue: AppFeedbackVisualCue.dismissed,
  ),
  AppFeedbackIntent.publicationEligible => const _FeedbackMapping(
    haptic: AppHaptic.heavy,
    sound: AppFeedbackSound.publicationEligible,
    visualCue: AppFeedbackVisualCue.lightMotes,
  ),
  AppFeedbackIntent.onboardingStep => const _FeedbackMapping(
    haptic: AppHaptic.selection,
    sound: AppFeedbackSound.softTap,
    visualCue: AppFeedbackVisualCue.none,
  ),
  AppFeedbackIntent.onboardingSacredHours => const _FeedbackMapping(
    haptic: AppHaptic.light,
    sound: AppFeedbackSound.sacredGentleChime,
    visualCue: AppFeedbackVisualCue.lightMotes,
  ),
};

AppFeedbackVisualCue _reducedVisualCue(AppFeedbackVisualCue cue) =>
    switch (cue) {
      AppFeedbackVisualCue.completion ||
      AppFeedbackVisualCue.lightMotes => AppFeedbackVisualCue.check,
      _ => cue,
    };

class _FeedbackMapping {
  const _FeedbackMapping({
    required this.haptic,
    required this.visualCue,
    this.sound,
  });

  final AppHaptic haptic;
  final AppFeedbackSound? sound;
  final AppFeedbackVisualCue visualCue;
}
