import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/feedback/app_feedback.dart';
import 'package:soulbuddy/core/feedback/app_feedback_preferences.dart';
import 'package:soulbuddy/core/feedback/app_feedback_service.dart';
import 'package:soulbuddy/core/feedback/platform_feedback_driver.dart';

void main() {
  test('maps semantic intents to restrained haptic and sound cues', () async {
    final driver = _RecordingFeedbackDriver();
    final service = AppFeedbackService(driver: driver);

    final selection = await service.emit(
      AppFeedbackIntent.selection,
      preferences: AppFeedbackPreferences.defaults,
    );
    final saved = await service.emit(
      AppFeedbackIntent.saved,
      preferences: AppFeedbackPreferences.defaults,
    );
    final completed = await service.emit(
      AppFeedbackIntent.prayerCompleted,
      preferences: AppFeedbackPreferences.defaults,
    );
    final warning = await service.emit(
      AppFeedbackIntent.warning,
      preferences: AppFeedbackPreferences.defaults,
    );
    final dismissed = await service.emit(
      AppFeedbackIntent.dismissed,
      preferences: AppFeedbackPreferences.defaults,
    );
    final eligible = await service.emit(
      AppFeedbackIntent.publicationEligible,
      preferences: AppFeedbackPreferences.defaults,
    );

    expect(driver.haptics, [
      AppHaptic.selection,
      AppHaptic.light,
      AppHaptic.medium,
      AppHaptic.warning,
      AppHaptic.selection,
      AppHaptic.heavy,
    ]);
    expect(driver.sounds, [
      AppFeedbackSound.softTap,
      AppFeedbackSound.gentleCompletion,
      AppFeedbackSound.publicationEligible,
    ]);
    expect(selection.visualCue, AppFeedbackVisualCue.none);
    expect(saved.visualCue, AppFeedbackVisualCue.check);
    expect(completed.visualCue, AppFeedbackVisualCue.completion);
    expect(warning.visualCue, AppFeedbackVisualCue.warning);
    expect(dismissed.visualCue, AppFeedbackVisualCue.dismissed);
    expect(eligible.visualCue, AppFeedbackVisualCue.lightMotes);
  });

  test('independently gates haptics and sounds', () async {
    final driver = _RecordingFeedbackDriver();
    final service = AppFeedbackService(driver: driver);

    await service.emit(
      AppFeedbackIntent.prayerCompleted,
      preferences: AppFeedbackPreferences.defaults.copyWith(
        hapticsEnabled: false,
      ),
    );
    expect(driver.haptics, isEmpty);
    expect(driver.sounds, [AppFeedbackSound.gentleCompletion]);

    driver.clear();
    await service.emit(
      AppFeedbackIntent.prayerCompleted,
      preferences: AppFeedbackPreferences.defaults.copyWith(
        soundsEnabled: false,
      ),
    );
    expect(driver.haptics, [AppHaptic.medium]);
    expect(driver.sounds, isEmpty);
  });

  test(
    'system reduced motion always suppresses animated visual cues',
    () async {
      final service = AppFeedbackService(driver: _RecordingFeedbackDriver());

      final systemReduced = await service.emit(
        AppFeedbackIntent.publicationEligible,
        preferences: AppFeedbackPreferences.defaults,
        systemReduceMotion: true,
      );
      final appReduced = await service.emit(
        AppFeedbackIntent.prayerCompleted,
        preferences: AppFeedbackPreferences.defaults.copyWith(
          reducedMotion: true,
        ),
      );

      expect(systemReduced.animate, isFalse);
      expect(systemReduced.visualCue, AppFeedbackVisualCue.check);
      expect(appReduced.animate, isFalse);
      expect(appReduced.visualCue, AppFeedbackVisualCue.check);
    },
  );

  test(
    'driver failures never fail the underlying action feedback call',
    () async {
      final service = AppFeedbackService(driver: _ThrowingFeedbackDriver());

      final result = await service.emit(
        AppFeedbackIntent.prayerCompleted,
        preferences: AppFeedbackPreferences.defaults,
      );

      expect(result.visualCue, AppFeedbackVisualCue.completion);
    },
  );
}

class _RecordingFeedbackDriver implements PlatformFeedbackDriver {
  final haptics = <AppHaptic>[];
  final sounds = <AppFeedbackSound>[];

  @override
  Future<void> playHaptic(AppHaptic haptic) async => haptics.add(haptic);

  @override
  Future<void> playSound(AppFeedbackSound sound) async => sounds.add(sound);

  void clear() {
    haptics.clear();
    sounds.clear();
  }
}

class _ThrowingFeedbackDriver implements PlatformFeedbackDriver {
  @override
  Future<void> playHaptic(AppHaptic haptic) => throw StateError('haptic');

  @override
  Future<void> playSound(AppFeedbackSound sound) => throw StateError('sound');
}
