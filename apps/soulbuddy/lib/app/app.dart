import 'package:flutter/material.dart';

import '../core/design/app_theme.dart';
import 'router.dart';

class SoulBuddyApp extends StatelessWidget {
  const SoulBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SoulBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
