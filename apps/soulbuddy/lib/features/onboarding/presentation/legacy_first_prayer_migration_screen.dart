import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/first_prayer_progress.dart';
import '../providers/first_prayer_providers.dart';
import 'first_prayer_screen.dart';

class LegacyFirstPrayerMigrationScreen extends ConsumerStatefulWidget {
  const LegacyFirstPrayerMigrationScreen({super.key});

  @override
  ConsumerState<LegacyFirstPrayerMigrationScreen> createState() =>
      _LegacyFirstPrayerMigrationScreenState();
}

class _LegacyFirstPrayerMigrationScreenState
    extends ConsumerState<LegacyFirstPrayerMigrationScreen> {
  var _clearing = false;

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(firstPrayerControllerProvider);
    return flow.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _MigrationMessage(
        busy: _clearing,
        onContinue: _continueReviewed,
        onToday: _goToday,
      ),
      data: (value) {
        final stage = value.progress.stage;
        final hasHistoricalResult =
            value.result != null &&
            stage.index >= FirstPrayerStage.prayer.index;
        if (hasHistoricalResult) {
          return const FirstPrayerScreen();
        }
        return _MigrationMessage(
          busy: _clearing,
          onContinue: _continueReviewed,
          onToday: _goToday,
        );
      },
    );
  }

  Future<void> _continueReviewed() => _clearAndGo('/prayers/create');

  Future<void> _goToday() => _clearAndGo('/today');

  Future<void> _clearAndGo(String location) async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await ref.read(firstPrayerControllerProvider.notifier).complete();
    } on Object {
      // Legacy resumable state must not trap the person in an obsolete flow.
    }
    if (mounted) context.go(location);
  }
}

class _MigrationMessage extends StatelessWidget {
  const _MigrationMessage({
    required this.busy,
    required this.onContinue,
    required this.onToday,
  });

  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Continue with reviewed prayers',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'You have an unfinished earlier prayer setup. SoulBuddy now starts new prayers from reviewed content or your own words. Continuing clears only that unfinished setup; prayers you already saved stay intact.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const Key('legacy-prayer-continue-reviewed'),
                    onPressed: busy ? null : onContinue,
                    child: Text(busy ? 'Opening…' : 'Continue'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const Key('legacy-prayer-go-today'),
                    onPressed: busy ? null : onToday,
                    child: const Text('Go to Today'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
