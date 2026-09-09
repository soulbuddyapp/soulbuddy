import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../core/design/sacred_piece.dart';
import '../core/feedback/app_feedback.dart';
import '../core/feedback/app_feedback_preferences.dart';
import '../core/feedback/app_feedback_providers.dart';
import '../features/circles/presentation/circle_detail_screen.dart';
import '../features/circles/presentation/circles_screen.dart';
import '../features/goals/presentation/first_goal_screen.dart';
import '../features/goals/presentation/goal_detail_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/formation/presentation/formation_reading_screen.dart';
import '../features/onboarding/presentation/legacy_first_prayer_migration_screen.dart';
import '../features/orientation/presentation/orientation_library_screen.dart';
import '../features/persons/presentation/person_detail_screen.dart';
import '../features/persons/presentation/person_editor_screen.dart';
import '../features/persons/presentation/persons_screen.dart';
import '../features/prayers/presentation/personal_prayer_detail_screen.dart';
import '../features/prayers/domain/library_prayer.dart';
import '../features/prayers/presentation/meditation_screen.dart';
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
      path: '/orientation',
      builder: (context, state) => OrientationLibraryScreen(
        initialNuggetId: state.uri.queryParameters['nugget'],
        onClose: () => context.canPop() ? context.pop() : context.go('/today'),
      ),
    ),
    GoRoute(
      path: '/formation/readings/:readingId',
      redirect: (context, state) =>
          '/prayers/meditation/${state.pathParameters['readingId']}',
    ),
    GoRoute(
      path: '/formation/readings',
      redirect: (context, state) => '/prayers/meditation',
    ),
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
                  builder: (context, state) => PrayerCreateScreen(
                    contextTitle: state.uri.queryParameters['context'],
                    prayerStarter: state.uri.queryParameters['starter'],
                    initialPurpose:
                        switch (state.uri.queryParameters['purpose']) {
                          final String value => PrayerPurpose.fromWire(value),
                          _ => null,
                        },
                  ),
                ),
                GoRoute(
                  path: 'meditation',
                  builder: (context, state) => const MeditationScreen(),
                  routes: [
                    GoRoute(
                      path: ':readingId',
                      builder: (context, state) => FormationReadingScreen(
                        readingId: state.pathParameters['readingId'],
                      ),
                    ),
                  ],
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
              builder: (context, state) => RememberScreen(
                initialFilter: state.uri.queryParameters['filter'],
              ),
              routes: [
                GoRoute(
                  path: 'capture',
                  builder: (context, state) {
                    final personId = state.uri.queryParameters['person'];
                    final source = state.uri.queryParameters['source'];
                    final mode = switch (state.uri.queryParameters['mode']) {
                      'speak' => RecordStartMode.speak,
                      'write' => RecordStartMode.write,
                      'reflection' => RecordStartMode.reflection,
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
                      initialTitle: state.uri.queryParameters['title'],
                      initialBodyPrompt:
                          state.uri.queryParameters['prompt'] ??
                          switch (source) {
                            'sacred-hour' =>
                              'What may God be teaching me here?',
                            'orientation' =>
                              'What will I remember, pray about, and put into practice from this Nugget?',
                            'formation' =>
                              'What is God showing me through this Scripture, and what will I practice?',
                            _ => null,
                          },
                      privateReflection:
                          source == 'orientation' || source == 'formation',
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
      piece: SacredPiece.today,
    ),
    _AppDestination(
      label: 'Goals',
      piece: SacredPiece.goal,
    ),
    _AppDestination(
      label: 'Persons',
      piece: SacredPiece.person,
    ),
    _AppDestination(
      label: 'Remember',
      piece: SacredPiece.remember,
    ),
    _AppDestination(
      label: 'Circles',
      piece: SacredPiece.circle,
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
                        icon: Icon(
                          destination.piece.icon,
                          key: Key('nav-piece-${destination.piece.name}'),
                        ),
                        selectedIcon: Icon(
                          destination.piece.selectedIcon,
                          key: Key('nav-piece-${destination.piece.name}'),
                        ),
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
                    icon: Icon(
                      destination.piece.icon,
                      key: Key('nav-piece-${destination.piece.name}'),
                    ),
                    selectedIcon: Icon(
                      destination.piece.selectedIcon,
                      key: Key('nav-piece-${destination.piece.name}'),
                    ),
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
    required this.piece,
  });

  final String label;
  final SacredPiece piece;
}
