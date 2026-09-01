import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../goals/providers/goal_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../sacred_hours/domain/sacred_hour.dart';
import '../../sacred_hours/providers/sacred_hour_providers.dart';
import '../../sacred_hours/presentation/sacred_hours_onboarding_page.dart';
import '../providers/onboarding_providers.dart';
import '../providers/first_prayer_providers.dart';
import 'onboarding_screen.dart';

class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({
    required this.child,
    required this.onBeginWithGoal,
    required this.onResumeFirstPrayer,
    required this.onSkip,
    super.key,
  });

  final Widget child;
  final VoidCallback onBeginWithGoal;
  final VoidCallback onResumeFirstPrayer;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  var _completedForSession = false;
  var _resumeScheduled = false;
  var _preparingSacredHours = false;

  Future<void> _prepareSacredHours(
    SacredHoursOnboardingSelection? selection, {
    required bool requestNotifications,
  }) async {
    if (_preparingSacredHours) return;
    _preparingSacredHours = true;
    try {
      final timezone = await ref.read(prayerDeviceTimezoneProvider)();
      final repository = await ref.read(sacredHourRepositoryProvider.future);
      final defaults = await repository.ensureDefaults(timezone: timezone);
      if (selection != null) {
        for (final hour in defaults) {
          final isMorning = hour.purpose == SacredHourPurpose.morning;
          final isEvening = hour.purpose == SacredHourPurpose.evening;
          if (!isMorning && !isEvening) continue;
          await repository.save(
            SacredHourDraft(
              name: hour.name,
              localTime: isMorning
                  ? selection.morningStart
                  : selection.eveningStart,
              timezone: timezone,
              durationMinutes: hour.durationMinutes,
              prayerMinutes: isMorning
                  ? selection.morningPrayerMinutes
                  : selection.eveningPrayerMinutes,
              enabled: true,
              sound: hour.sound,
              purpose: hour.purpose,
              prayer: hour.prayer,
              personId: hour.personId,
            ),
            id: hour.id,
          );
        }
      }
      if (requestNotifications) {
        await ref.read(prayerReminderSchedulerProvider).requestPermission();
      }
    } on Object {
      // Sacred Hours remain available from Settings if setup or permission
      // access is unavailable during onboarding.
    }
  }

  Future<void> _finish(VoidCallback destination) async {
    try {
      await ref.read(onboardingRepositoryProvider).complete();
    } on Object {
      // Local storage should never keep someone from using the app.
    }
    if (!mounted) return;
    setState(() => _completedForSession = true);
    destination();
  }

  @override
  Widget build(BuildContext context) {
    if (_completedForSession) return widget.child;

    final completed = ref.watch(onboardingCompleteProvider);
    return completed.when(
      loading: () => const _WelcomeLoading(),
      error: (_, _) => _welcome(),
      data: (isComplete) => isComplete ? _completed() : _welcome(),
    );
  }

  Widget _completed() {
    final legacyPrayer = ref.watch(firstPrayerSavedProgressProvider);
    final goalProgress = ref.watch(goalOnboardingProgressProvider);
    if (!_resumeScheduled) {
      VoidCallback? destination;
      if (legacyPrayer case AsyncData(value: != null)) {
        // A partially completed legacy flow is resumed once rather than silently
        // discarded during the Goal migration.
        destination = widget.onResumeFirstPrayer;
      } else if (legacyPrayer case AsyncData(value: null)) {
        if (goalProgress case AsyncData(value: != null)) {
          destination = widget.onBeginWithGoal;
        }
      } else if (legacyPrayer case AsyncError()) {
        if (goalProgress case AsyncData(value: != null)) {
          destination = widget.onBeginWithGoal;
        }
      }

      if (destination != null) {
        _resumeScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) destination!();
        });
      }
    }
    return widget.child;
  }

  Widget _welcome() {
    final preferences =
        ref.watch(appFeedbackPreferencesProvider).value ??
        AppFeedbackPreferences.defaults;
    final systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    return OnboardingScreen(
      onBeginWithGoal: () => _finish(widget.onBeginWithGoal),
      onKeepSacredHours: (selection) =>
          _prepareSacredHours(selection, requestNotifications: true),
      onSkip: () async {
        await _prepareSacredHours(null, requestNotifications: false);
        await _finish(widget.onSkip);
      },
      reduceMotion: preferences.reducedMotion,
      onSensoryCue: (cue) async {
        final intent = switch (cue) {
          OnboardingSensoryCue.step => AppFeedbackIntent.onboardingStep,
          OnboardingSensoryCue.sacredHours =>
            AppFeedbackIntent.onboardingSacredHours,
          OnboardingSensoryCue.completed => AppFeedbackIntent.prayerCompleted,
        };
        unawaited(
          ref
              .read(appFeedbackServiceProvider)
              .emit(
                intent,
                preferences: preferences,
                systemReduceMotion: systemReduceMotion,
              ),
        );
      },
    );
  }
}

class _WelcomeLoading extends StatelessWidget {
  const _WelcomeLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SoulBuddy',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
