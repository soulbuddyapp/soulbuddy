import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/feedback/completion_feedback.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppFeedbackResult? _testResult;
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appFeedbackPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: preferences.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _SettingsUnavailable(
                      onRetry: () =>
                          ref.invalidate(appFeedbackPreferencesProvider),
                    ),
                    data: (value) => _SoundTouchSettings(
                      preferences: value,
                      updating: _updating,
                      testResult: _testResult,
                      onHapticsChanged: (enabled) => _update(
                        (repository) => repository.setHapticsEnabled(enabled),
                      ),
                      onSoundsChanged: (enabled) => _update(
                        (repository) => repository.setSoundsEnabled(enabled),
                      ),
                      onReducedMotionChanged: (enabled) => _update(
                        (repository) => repository.setReducedMotion(enabled),
                      ),
                      onTest: () => _testFeedback(value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _update(
    Future<void> Function(AppFeedbackPreferencesRepository) update,
  ) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      final repository = await ref.read(
        appFeedbackPreferencesRepositoryProvider.future,
      );
      await update(repository);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this setting.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _testFeedback(AppFeedbackPreferences preferences) async {
    final result = await ref
        .read(appFeedbackServiceProvider)
        .emit(
          AppFeedbackIntent.prayerCompleted,
          preferences: preferences,
          systemReduceMotion:
              MediaQuery.maybeOf(context)?.disableAnimations ?? false,
        );
    if (mounted) setState(() => _testResult = result);
  }
}

class _SoundTouchSettings extends StatelessWidget {
  const _SoundTouchSettings({
    required this.preferences,
    required this.updating,
    required this.testResult,
    required this.onHapticsChanged,
    required this.onSoundsChanged,
    required this.onReducedMotionChanged,
    required this.onTest,
  });

  final AppFeedbackPreferences preferences;
  final bool updating;
  final AppFeedbackResult? testResult;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSoundsChanged;
  final ValueChanged<bool> onReducedMotionChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Sound & touch',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose how SoulBuddy confirms actions on this device.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Haptics'),
                subtitle: const Text('Gentle touch feedback for key actions.'),
                value: preferences.hapticsEnabled,
                onChanged: updating ? null : onHapticsChanged,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('In-app sounds'),
                subtitle: const Text('Quiet tones for saves and completion.'),
                value: preferences.soundsEnabled,
                onChanged: updating ? null : onSoundsChanged,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Reduce motion'),
                subtitle: const Text(
                  'Use immediate state changes instead of movement.',
                ),
                value: preferences.reducedMotion,
                onChanged: updating ? null : onReducedMotionChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: updating ? null : onTest,
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('Test feedback'),
        ),
        if (testResult case final result?) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: CompletionFeedback(
              cue: result.visualCue,
              animate: result.animate,
              semanticLabel: 'Feedback played',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Prayer narration is separate and never starts automatically. '
          'Notification sound is controlled by your device.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsUnavailable extends StatelessWidget {
  const _SettingsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Settings could not be opened just now.'),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}
