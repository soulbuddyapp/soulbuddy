import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../core/design/app_spacing.dart';
import '../core/playback/spiritual_session_mini_player.dart';
import '../core/playback/spiritual_session.dart';
import '../core/playback/spiritual_session_providers.dart';
import '../features/prayers/providers/prayer_practice_providers.dart';
import '../features/prayers/application/prayer_reminder_scheduler.dart';
import '../features/prayers/application/prayer_reminder_coordinator.dart';
import '../features/prayers/domain/prayer_reminder.dart';
import '../features/prayers/presentation/prayer_reminder_card.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import '../features/persons/application/person_prayer_reminder_coordinator.dart';
import '../features/persons/providers/person_providers.dart';
import '../features/record/audio/providers/private_audio_cleanup_provider.dart';
import '../core/identity/local_identity_providers.dart';
import '../core/notifications/push_registration.dart';
import '../features/altar/application/altar_reminder_coordinator.dart';
import '../features/altar/providers/altar_ritual_providers.dart';
import '../features/altar/presentation/altar_today_card.dart';
import '../features/circles/application/circle_reminder_coordinator.dart';
import '../features/circles/providers/circle_providers.dart';
import '../features/daily_formation/providers/daily_formation_providers.dart';
import '../features/goals/providers/goal_today_providers.dart';
import '../features/goals/providers/goal_meditation_providers.dart';
import '../features/goals/application/goal_meditation_reminder_coordinator.dart';
import '../features/sacred_hours/application/sacred_hour_reminder_coordinator.dart';
import '../features/sacred_hours/domain/sacred_hour.dart';
import '../features/sacred_hours/providers/sacred_hour_providers.dart';
import 'router.dart';
import 'app_overlay_visibility.dart';

class SoulBuddyApp extends ConsumerWidget {
  const SoulBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(prayerReminderCoordinatorProvider);
    ref.watch(altarReminderCoordinatorProvider);
    ref.watch(personPrayerReminderCoordinatorProvider);
    ref.watch(privateAudioStartupCleanupProvider);
    ref.watch(installationSessionBootstrapProvider);
    ref.watch(pushRegistrationProvider);
    ref.watch(sacredHourBootstrapProvider);
    ref.watch(sacredHourReminderCoordinatorProvider);
    ref.watch(circleReminderCoordinatorProvider);
    ref.watch(dailyFormationReminderCoordinatorProvider);
    ref.watch(goalMeditationReminderCoordinatorProvider);
    ref.listen(prayerReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: PrayerReminderOpened(:final occurrence))) {
        final due = occurrence!;
        final route = '/prayers/saved/${due.reminder.personalPrayerId}';
        unawaited(_beginPrayerReminderSession(ref, due, route));
        appRouter.go(route);
      }
    });
    ref.listen(altarReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: AltarReminderOpened(:final ritualId))) {
        ref.read(pendingAltarOpenProvider.notifier).set(ritualId);
        appRouter.go('/today');
      }
    });
    ref.listen(personPrayerReminderEventsProvider, (previous, next) {
      if (next case AsyncData(
        value: PersonPrayerReminderOpened(:final personId),
      )) {
        final route = '/persons/$personId';
        unawaited(_beginPersonPrayerSession(ref, personId, route));
        appRouter.go(route);
      }
    });
    ref.listen(sacredHourReminderEventsProvider, (previous, next) {
      if (next case AsyncData(
        value: SacredHourOpened(:final hourId, :final occurrenceKey),
      )) {
        final route = Uri(
          pathSegments: ['sacred-hours', hourId],
          queryParameters: {'occurrence': occurrenceKey},
        ).toString();
        unawaited(_beginSacredHourSession(ref, hourId, occurrenceKey, route));
        appRouter.go(route);
      }
    });
    ref.listen(circleReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: CircleReminderOpened(:final circleId))) {
        appRouter.go('/circles/$circleId');
      }
    });
    ref.listen(dailyFormationReminderEventsProvider, (previous, next) {
      if (next case AsyncData()) appRouter.go('/formation');
    });
    ref.listen(goalMeditationReminderEventsProvider, (previous, next) {
      if (next case AsyncData(value: GoalMeditationOpened(:final goalId))) {
        appRouter.go('/goals/$goalId/meditate');
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
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => OnboardingGate(
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
                      child: SafeArea(
                        top: false,
                        child: ListenableBuilder(
                          listenable: appRouter.routerDelegate,
                          builder: (context, _) {
                            final uri = appRouter
                                .routerDelegate
                                .currentConfiguration
                                .uri;
                            if (AppOverlayVisibility.hideGlobalOverlays(uri)) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpiritualSessionMiniPlayer(
                                  onOpen: appRouter.go,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (!AppOverlayVisibility.hideReminderOverlays(
                                  uri,
                                )) ...[
                                  const _PrayerReminderOverlayHost(
                                    key: Key('prayer-reminder-overlay-host'),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const AltarReminderOverlayHost(
                                    key: Key('altar-reminder-overlay-host'),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _beginPrayerReminderSession(
  WidgetRef ref,
  DuePrayerOccurrence occurrence,
  String route,
) async {
  final perform = ref.read(prayerReminderActionProvider);
  await ref
      .read(spiritualSessionControllerProvider)
      .begin(
        SpiritualSession(
          id: 'prayer-reminder:${occurrence.occurrenceKey}',
          kind: SpiritualSessionKind.prayer,
          title: occurrence.prayerTitle,
          route: route,
          canPause: false,
          completionLabel: 'I prayed',
          onPause: () async {},
          onResume: () async {},
          onComplete: () async {
            await perform(occurrence, PrayerReminderAction.prayed);
          },
          onClose: () async {},
        ),
      );
}

Future<void> _beginPersonPrayerSession(
  WidgetRef ref,
  String personId,
  String route,
) async {
  await ref
      .read(spiritualSessionControllerProvider)
      .begin(
        SpiritualSession(
          id: 'person-prayer:$personId',
          kind: SpiritualSessionKind.person,
          title: 'Pray for this person',
          route: route,
          canPause: false,
          completionLabel: 'I prayed',
          onPause: () async {},
          onResume: () async {},
          onComplete: () async {
            final repository = await ref.read(personRepositoryProvider.future);
            await repository.recordPrayer(personId, localDate: DateTime.now());
          },
          onClose: () async {},
        ),
      );
}

Future<void> _beginSacredHourSession(
  WidgetRef ref,
  String hourId,
  String occurrenceKey,
  String route,
) async {
  final dueAt = DateTime.tryParse(occurrenceKey.split('@').last)?.toUtc();
  await ref
      .read(spiritualSessionControllerProvider)
      .begin(
        SpiritualSession(
          id: 'sacred-hour:$occurrenceKey',
          kind: SpiritualSessionKind.sacredHour,
          title: 'Sacred Hour',
          route: route,
          canPause: false,
          completionLabel: 'Complete',
          onPause: () async {},
          onResume: () async {},
          onComplete: () async {
            if (dueAt != null) {
              final repository = await ref.read(
                sacredHourRepositoryProvider.future,
              );
              await repository.markOccurrence(
                hourId,
                dueAt,
                SacredHourOccurrenceStatus.completed,
              );
            }
          },
          onClose: () async {},
        ),
      );
}

class _PrayerReminderOverlayHost extends ConsumerWidget {
  const _PrayerReminderOverlayHost({super.key});

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
