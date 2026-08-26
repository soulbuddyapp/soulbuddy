import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_screen.dart';

class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({
    required this.child,
    required this.onBeginWithPrayer,
    required this.onSkip,
    super.key,
  });

  final Widget child;
  final VoidCallback onBeginWithPrayer;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  var _completedForSession = false;

  Future<void> _finish(VoidCallback destination) async {
    try {
      await ref.read(onboardingRepositoryProvider).complete();
    } on Object {
      // Local storage should never keep someone from using the app.
    }
    if (!mounted) return;
    setState(() => _completedForSession = true);
    destination();
  }

  @override
  Widget build(BuildContext context) {
    if (_completedForSession) return widget.child;

    final completed = ref.watch(onboardingCompleteProvider);
    return completed.when(
      loading: () => const _WelcomeLoading(),
      error: (_, _) => _welcome(),
      data: (isComplete) => isComplete ? widget.child : _welcome(),
    );
  }

  Widget _welcome() {
    return OnboardingScreen(
      onBeginWithPrayer: () => _finish(widget.onBeginWithPrayer),
      onSkip: () => _finish(widget.onSkip),
    );
  }
}

class _WelcomeLoading extends StatelessWidget {
  const _WelcomeLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SoulBuddy',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
