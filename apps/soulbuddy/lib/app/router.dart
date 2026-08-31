import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../core/feedback/app_feedback.dart';
import '../core/feedback/app_feedback_preferences.dart';
import '../core/feedback/app_feedback_providers.dart';
import '../features/circles/presentation/circle_detail_screen.dart';
import '../features/circles/presentation/circles_screen.dart';
import '../features/goals/presentation/first_goal_screen.dart';
import '../features/goals/presentation/goal_detail_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/onboarding/presentation/legacy_first_prayer_migration_screen.dart';
import '../features/persons/presentation/person_detail_screen.dart';
import '../features/persons/presentation/person_editor_screen.dart';
import '../features/persons/presentation/persons_screen.dart';
import '../features/prayers/presentation/personal_prayer_detail_screen.dart';
import '../features/prayers/presentation/prayer_create_screen.dart';
import '../features/prayers/presentation/prayer_detail_screen.dart';
import '../features/prayers/presentation/prayers_screen.dart';
import '../features/record/presentation/record_screen.dart';
import '../features/remember/presentation/daily_remembrance_screen.dart';
import '../features/remember/presentation/memory_detail_screen.dart';
import '../features/remember/presentation/remember_screen.dart';
import '../features/scripture/presentation/scripture_passage_screen.dart';
import '../features/sacred_hours/presentation/sacred_hour_session_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/today_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(path: '/record', redirect: (context, state) => '/remember/capture'),
    GoRoute(
      path: '/welcome/goal',
      builder: (context, state) => const FirstGoalScreen(),
    ),
    GoRoute(
      path: '/welcome/prayer',
      builder: (context, state) => const LegacyFirstPrayerMigrationScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/sacred-hours/:hourId',
      builder: (context, state) => SacredHourSessionScreen(
        hourId: state.pathParameters['hourId']!,
        occurrenceKey: state.uri.queryParameters['occurrence'],
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _SoulBuddyShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => TodayScreen(
                focusAltar: state.uri.queryParameters['focus'] == 'altar',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              builder: (context, state) => const GoalsScreen(),
              routes: [
                GoRoute(
                  path: ':goalId',
                  builder: (context, state) =>
                      GoalDetailScreen(goalId: state.pathParameters['goalId']!),
                ),
              ],
            ),
            GoRoute(
              path: '/prayers',
              builder: (context, state) => const PrayersScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const PrayerCreateScreen(),
                ),
                GoRoute(
                  path: 'saved/:prayerId',
                  builder: (context, state) => PersonalPrayerDetailScreen(
                    prayerId: state.pathParameters['prayerId']!,
                  ),
                ),
                GoRoute(
                  path: ':prayerId',
                  builder: (context, state) => PrayerDetailScreen(
                    prayerId: state.pathParameters['prayerId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/persons',
              builder: (context, state) => const PersonsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const PersonEditorScreen(),
                ),
                GoRoute(
                  path: ':personId',
                  builder: (context, state) => PersonDetailScreen(
                    personId: state.pathParameters['personId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => PersonEditorScreen(
                        personId: state.pathParameters['personId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/remember',
              builder: (context, state) => const RememberScreen(),
              routes: [
                GoRoute(
                  path: 'capture',
                  builder: (context, state) {
                    final personId = state.uri.queryParameters['person'];
                    final mode = switch (state.uri.queryParameters['mode']) {
                      'speak' => RecordStartMode.speak,
                      'write' => RecordStartMode.write,
                      _ when personId != null && personId.isNotEmpty =>
                        RecordStartMode.person,
                      _ => RecordStartMode.choices,
                    };
                    return RecordScreen(
                      key: ValueKey(
                        'remember-capture-${mode.name}-${personId ?? ''}',
                      ),
                      startMode: mode,
                      initialPersonIds: switch (personId) {
                        final String id when id.isNotEmpty => [id],
                        _ => const [],
                      },
                      initialBodyPrompt:
                          state.uri.queryParameters['source'] == 'sacred-hour'
                          ? 'What may God be teaching me here?'
                          : null,
                    );
                  },
                ),
                GoRoute(
                  path: 'daily/:localDate',
                  builder: (context, state) => DailyRemembranceScreen(
                    localDate: state.pathParameters['localDate']!,
                  ),
                ),
                GoRoute(
                  path: 'scripture/:book/:chapter',
                  builder: (context, state) => ScripturePassageScreen(
                    book: state.pathParameters['book']!,
                    chapter: int.parse(state.pathParameters['chapter']!),
                  ),
                ),
                GoRoute(
                  path: ':memoryId',
                  builder: (context, state) => MemoryDetailScreen(
                    memoryId: state.pathParameters['memoryId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/circles',
              builder: (context, state) => const CirclesScreen(),
              routes: [
                GoRoute(
                  path: ':circleId',
                  builder: (context, state) => CircleDetailScreen(
                    circleId: state.pathParameters['circleId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _SoulBuddyShell extends ConsumerWidget {
  const _SoulBuddyShell({required this.navigationShell});

  static const _destinations = [
    _AppDestination(
      label: 'Today',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
    ),
    _AppDestination(
      label: 'Goals',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
    ),
    _AppDestination(
      label: 'Persons',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    _AppDestination(
      label: 'Remember',
      icon: Icons.bookmark_border,
      selectedIcon: Icons.bookmark,
    ),
    _AppDestination(
      label: 'Circles',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
  ];

  final StatefulNavigationShell navigationShell;

  void _selectDestination(WidgetRef ref, int index) {
    if (index != navigationShell.currentIndex) {
      final preferences =
          ref.read(appFeedbackPreferencesProvider).value ??
          AppFeedbackPreferences.defaults;
      unawaited(
        ref
            .read(appFeedbackServiceProvider)
            .emit(AppFeedbackIntent.selection, preferences: preferences),
      );
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1080,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) =>
                      _selectDestination(ref, index),
                  groupAlignment: -0.75,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _ShellBody(navigationShell: navigationShell)),
              ],
            ),
          );
        }

        return Scaffold(
          body: _ShellBody(navigationShell: navigationShell),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _selectDestination(ref, index),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: navigationShell),
      Positioned(
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        child: SafeArea(
          child: Material(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.94),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
        ),
      ),
    ],
  );
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
