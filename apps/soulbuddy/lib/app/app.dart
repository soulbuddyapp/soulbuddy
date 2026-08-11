import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/app_theme.dart';
import '../features/prayers/providers/personal_prayer_providers.dart';
import '../features/prayers/providers/prayer_practice_providers.dart';
import 'router.dart';

class SoulBuddyApp extends ConsumerWidget {
  const SoulBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(prayerGenerationWorkerProvider);
    ref.watch(prayerReminderCoordinatorProvider);
    return MaterialApp.router(
      title: 'SoulBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
