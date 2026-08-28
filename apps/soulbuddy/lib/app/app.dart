import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/design/app_spacing.dart';
import '../features/prayers/providers/personal_prayer_providers.dart';
import '../features/prayers/providers/prayer_practice_providers.dart';
import '../features/prayers/application/prayer_reminder_coordinator.dart';
import '../features/prayers/presentation/prayer_reminder_card.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import '../features/record/audio/providers/private_audio_cleanup_provider.dart';
import '../core/identity/local_identity_providers.dart';
import '../features/altar/application/altar_reminder_coordinator.dart';
import '../features/altar/providers/altar_ritual_providers.dart';
import '../features/altar/presentation/altar_today_card.dart';
import '../features/goals/providers/goal_today_providers.dart';
import 'router.dart';

class SoulBuddyApp extends ConsumerWidget {
  const SoulBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(prayerGenerationWorkerProvider);
    ref.watch(prayerReminderCoordinatorProvider);
    ref.watch(altarReminderCoordinatorProvider);
    ref.watch(privateAudioStartupCleanupProvider);
    ref.watch(installationSessionBootstrapProvider);
    ref.listen(prayerReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: PrayerReminderOpened(:final occurrence))) {
        appRouter.go('/prayers/saved/${occurrence!.reminder.personalPrayerId}');
      }
    });
    ref.listen(altarReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: AltarReminderOpened(:final ritualId))) {
        ref.read(pendingAltarOpenProvider.notifier).set(ritualId);
        appRouter.go('/today');
      }
    });
    return MaterialApp.router(
      title: 'SoulBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        final compactNavigation = MediaQuery.sizeOf(context).width < 840;
        return OnboardingGate(
          onBeginWithGoal: () => appRouter.go('/welcome/goal'),
          onResumeFirstPrayer: () => appRouter.go('/welcome/prayer'),
          onSkip: () => appRouter.go('/today'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: compactNavigation ? 92 : AppSpacing.md,
                child: const SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrayerReminderOverlayHost(),
                      SizedBox(height: AppSpacing.sm),
                      AltarReminderOverlayHost(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerReminderOverlayHost extends ConsumerWidget {
  const _PrayerReminderOverlayHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalToday = ref.watch(goalTodaySnapshotProvider);
    final dueReminders = ref.watch(duePrayerOccurrencesProvider);
    return ListenableBuilder(
      listenable: appRouter.routerDelegate,
      builder: (context, child) {
        final onToday =
            appRouter.routerDelegate.currentConfiguration.uri.path == '/today';
        final todayOwnsReminders =
            onToday &&
            goalToday is AsyncData<GoalTodaySnapshot> &&
            dueReminders is AsyncData;
        return todayOwnsReminders
            ? const SizedBox.shrink()
            : const PrayerReminderCardHost();
      },
    );
  }
}
