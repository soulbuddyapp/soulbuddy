import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/design/app_spacing.dart';
import '../features/prayers/providers/personal_prayer_providers.dart';
import '../features/prayers/providers/prayer_practice_providers.dart';
import '../features/prayers/application/prayer_reminder_coordinator.dart';
import '../features/prayers/presentation/prayer_reminder_card.dart';
import '../features/record/audio/providers/memory_audio_providers.dart';
import '../core/identity/local_identity_providers.dart';
import 'router.dart';

class SoulBuddyApp extends ConsumerWidget {
  const SoulBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(prayerGenerationWorkerProvider);
    ref.watch(prayerReminderCoordinatorProvider);
    ref.watch(memoryAudioStartupCleanupProvider);
    ref.watch(installationSessionBootstrapProvider);
    ref.listen(prayerReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: PrayerReminderOpened(:final occurrence))) {
        appRouter.go('/prayers/saved/${occurrence!.reminder.personalPrayerId}');
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
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: compactNavigation ? 92 : AppSpacing.md,
              child: const SafeArea(
                top: false,
                child: PrayerReminderCardHost(),
              ),
            ),
          ],
        );
      },
    );
  }
}
