import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../features/circles/presentation/circles_screen.dart';
import '../features/prayers/presentation/prayers_screen.dart';
import '../features/prayers/presentation/prayer_detail_screen.dart';
import '../features/prayers/presentation/prayer_draft_screen.dart';
import '../features/prayers/presentation/personal_prayer_detail_screen.dart';
import '../features/prayers/presentation/personalized_prayer_screen.dart';
import '../features/record/presentation/record_screen.dart';
import '../features/remember/presentation/remember_screen.dart';
import '../features/scripture/presentation/scripture_passage_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/today_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/prayers',
              builder: (context, state) => const PrayersScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const PersonalizedPrayerScreen(),
                ),
                GoRoute(
                  path: 'requests/:requestId',
                  builder: (context, state) => PersonalizedPrayerScreen(
                    requestId: state.pathParameters['requestId'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'draft',
                      builder: (context, state) => PrayerDraftScreen(
                        requestId: state.pathParameters['requestId']!,
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
              path: '/record',
              builder: (context, state) => const RecordScreen(),
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
                  path: 'scripture/:book/:chapter',
                  builder: (context, state) => ScripturePassageScreen(
                    book: state.pathParameters['book']!,
                    chapter: int.parse(state.pathParameters['chapter']!),
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
            ),
          ],
        ),
      ],
    ),
  ],
);

class _SoulBuddyShell extends StatelessWidget {
  const _SoulBuddyShell({required this.navigationShell});

  static const _destinations = [
    _AppDestination(
      label: 'Today',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
    ),
    _AppDestination(
      label: 'Prayers',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _AppDestination(
      label: 'Record',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
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

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1080,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _selectDestination,
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
              onDestinationSelected: _selectDestination,
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
