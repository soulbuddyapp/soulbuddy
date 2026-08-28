import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../onboarding/presentation/first_prayer_choice_page.dart';
import '../../onboarding/presentation/first_prayer_speech_page.dart';
import '../application/goal_starter_content.dart';
import '../domain/goal.dart';
import '../domain/goal_onboarding_progress.dart';
import '../providers/goal_onboarding_providers.dart';

class FirstGoalScreen extends ConsumerStatefulWidget {
  const FirstGoalScreen({super.key});

  @override
  ConsumerState<FirstGoalScreen> createState() => _FirstGoalScreenState();
}

class _FirstGoalScreenState extends ConsumerState<FirstGoalScreen> {
  _SituationInput? _situationInput;
  var _writingPrayer = false;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(goalOnboardingControllerProvider);
    final compactTodayAction =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) >= 21;
    return flow.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(goalOnboardingControllerProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      data: (progress) => Scaffold(
        appBar: AppBar(
          title: const Text('Your first Goal'),
          leading: _canGoBack(progress)
              ? IconButton(
                  tooltip: 'Back',
                  onPressed: _saving ? null : () => _goBack(progress),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            if (compactTodayAction)
              IconButton(
                tooltip: 'Go to Today',
                onPressed: _saving ? null : () => context.go('/today'),
                icon: const Icon(Icons.today_outlined),
              )
            else
              TextButton(
                onPressed: _saving ? null : () => context.go('/today'),
                child: const Text('Go to Today'),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey((progress.stage, _situationInput, _writingPrayer)),
            child: _page(progress),
          ),
        ),
      ),
    );
  }

  Widget _page(GoalOnboardingProgress progress) => switch (progress.stage) {
    GoalOnboardingStage.starter => FirstPrayerChoicePage(
      question: 'What would you like help with?',
      choices: goalStarterOptions.map((option) => option.label).toList(),
      onChoose: (label) {
        final option = goalStarterOptions.firstWhere(
          (item) => item.label == label,
        );
        unawaited(
          ref
              .read(goalOnboardingControllerProvider.notifier)
              .chooseStarter(option.key),
        );
      },
    ),
    GoalOnboardingStage.situation => _situationPage(progress),
    GoalOnboardingStage.agency => FirstPrayerChoicePage(
      question: 'What can you do about this?',
      choices: const [
        'There are steps I can take',
        'Mostly pray and wait',
        "I'm not sure",
      ],
      onChoose: (label) {
        final choice = switch (label) {
          'There are steps I can take' => GoalAgencyChoice.stepsICanTake,
          'Mostly pray and wait' => GoalAgencyChoice.mostlyPrayAndWait,
          _ => GoalAgencyChoice.notSure,
        };
        unawaited(
          ref
              .read(goalOnboardingControllerProvider.notifier)
              .chooseAgency(choice),
        );
      },
    ),
    GoalOnboardingStage.todayAction => _GoalTextPage(
      question: 'What would help today?',
      initialValue: progress.todayAction,
      hintText: 'One small faithful step',
      continueLabel: 'Keep this',
      onContinue: (value) => ref
          .read(goalOnboardingControllerProvider.notifier)
          .setTodayAction(value),
      onSkip: () => ref
          .read(goalOnboardingControllerProvider.notifier)
          .setTodayAction(null),
    ),
    GoalOnboardingStage.guard => _GoalTextPage(
      question: 'What do you need to guard against or remove?',
      initialValue: progress.guardNote,
      hintText: 'A door to close, remove, or make harder to reach',
      continueLabel: 'Keep this guard',
      onContinue: (value) => ref
          .read(goalOnboardingControllerProvider.notifier)
          .setGuardNote(value),
      onSkip: () => ref
          .read(goalOnboardingControllerProvider.notifier)
          .setGuardNote(null),
    ),
    GoalOnboardingStage.accountability => FirstPrayerChoicePage(
      question: 'Who can walk with you?',
      choices: const ['A trusted person', 'A Circle', 'Not now'],
      onChoose: (label) {
        final choice = switch (label) {
          'A trusted person' => GoalAccountabilityChoice.trustedPerson,
          'A Circle' => GoalAccountabilityChoice.circle,
          _ => GoalAccountabilityChoice.notNow,
        };
        unawaited(
          ref
              .read(goalOnboardingControllerProvider.notifier)
              .chooseAccountability(choice),
        );
      },
    ),
    GoalOnboardingStage.prayer => _prayerPage(progress),
    GoalOnboardingStage.saving => _SavingGoal(onRetry: _finish),
  };

  Widget _situationPage(GoalOnboardingProgress progress) {
    if (progress.title == null) {
      final stopping = progress.starterKey == GoalStarterKey.stopControl;
      return _GoalTextPage(
        question: stopping ? 'What do you want to stop?' : 'Name it simply.',
        hintText: stopping
            ? 'For example: Stop watching pornography'
            : 'What would you like help with?',
        continueLabel: 'Continue',
        maxLength: 120,
        onContinue: (value) =>
            ref.read(goalOnboardingControllerProvider.notifier).setTitle(value),
      );
    }

    return switch (_situationInput) {
      _SituationInput.write => _GoalTextPage(
        question: 'What is happening now?',
        initialValue: progress.currentSituation,
        hintText: 'A few words are enough',
        continueLabel: 'Continue',
        maxLength: 4000,
        onContinue: (value) => ref
            .read(goalOnboardingControllerProvider.notifier)
            .setSituation(situation: value, byVoice: false),
        onSkip: () => ref
            .read(goalOnboardingControllerProvider.notifier)
            .setSituation(situation: null, byVoice: false),
      ),
      _SituationInput.speak => FirstPrayerSpeechPage(
        heading: 'What is happening now?',
        description: 'Say only what would help you name the situation.',
        continueLabel: 'Continue',
        hintText: 'Your words will appear here',
        fieldKey: const Key('first-goal-spoken-situation'),
        onContinue: (words) {
          unawaited(
            ref
                .read(goalOnboardingControllerProvider.notifier)
                .setSituation(situation: words, byVoice: true),
          );
        },
        onWriteInstead: () =>
            setState(() => _situationInput = _SituationInput.write),
        onSkip: () {
          unawaited(
            ref
                .read(goalOnboardingControllerProvider.notifier)
                .setSituation(situation: null, byVoice: false),
          );
        },
      ),
      null => FirstPrayerChoicePage(
        question: 'What is happening now?',
        choices: const ['Speak', 'Write', 'Not now'],
        onChoose: (choice) {
          if (choice == 'Not now') {
            unawaited(
              ref
                  .read(goalOnboardingControllerProvider.notifier)
                  .setSituation(situation: null, byVoice: false),
            );
          } else {
            setState(
              () => _situationInput = choice == 'Speak'
                  ? _SituationInput.speak
                  : _SituationInput.write,
            );
          }
        },
      ),
    };
  }

  Widget _prayerPage(GoalOnboardingProgress progress) {
    if (_writingPrayer) {
      return _GoalTextPage(
        question: 'Bring this to God.',
        initialValue: progress.ownPrayerText,
        hintText: 'Write your prayer in your own words.',
        continueLabel: 'Keep my words',
        maxLength: 4000,
        skipLabel: 'Choose another prayer',
        onContinue: (value) async {
          await ref
              .read(goalOnboardingControllerProvider.notifier)
              .useOwnWords(value);
          if (mounted) setState(() => _writingPrayer = false);
        },
        onSkip: () async {
          if (mounted) setState(() => _writingPrayer = false);
        },
      );
    }

    final starterKey = progress.starterKey;
    if (starterKey == null) {
      return const _GoalMessage('This Goal needs a starting point.');
    }
    final prayers = ref.watch(firstGoalPrayerOptionsProvider(starterKey));
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bring this to God.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose a prepared prayer or use your own words.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  prayers.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text(
                      'Prepared prayers are unavailable just now. Your own words remain available.',
                    ),
                    data: (items) => Column(
                      children: [
                        for (final prayer in items) ...[
                          Card(
                            child: ListTile(
                              key: Key('first-goal-prayer-${prayer.id}'),
                              title: Text(prayer.title),
                              trailing:
                                  progress.prayerSource ==
                                          GoalOnboardingPrayerSource
                                              .libraryPrayer &&
                                      progress.prayerResourceId == prayer.id
                                  ? const Icon(Icons.check_circle_outline)
                                  : const Icon(Icons.chevron_right),
                              onTap: () => ref
                                  .read(
                                    goalOnboardingControllerProvider.notifier,
                                  )
                                  .chooseLibraryPrayer(prayer.id),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('first-goal-own-prayer'),
                    onPressed: () => setState(() => _writingPrayer = true),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      progress.prayerSource ==
                              GoalOnboardingPrayerSource.ownWords
                          ? 'Edit my own words'
                          : 'Use my own words',
                    ),
                  ),
                  if (progress.hasCompletePrayerSelection) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('finish-first-goal'),
                      onPressed: _saving ? null : _finish,
                      child: Text(_saving ? 'Keeping…' : 'Keep this on Today'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canGoBack(GoalOnboardingProgress progress) {
    return _situationInput != null ||
        _writingPrayer ||
        progress.stage != GoalOnboardingStage.starter;
  }

  Future<void> _goBack(GoalOnboardingProgress progress) async {
    if (progress.stage == GoalOnboardingStage.situation &&
        _situationInput != null) {
      setState(() => _situationInput = null);
      return;
    }
    if (progress.stage == GoalOnboardingStage.prayer && _writingPrayer) {
      setState(() => _writingPrayer = false);
      return;
    }
    await ref.read(goalOnboardingControllerProvider.notifier).goBack();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(goalOnboardingControllerProvider.notifier).finalize();
      if (mounted) context.go('/today');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This Goal could not be kept just now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum _SituationInput { speak, write }

class _GoalTextPage extends StatefulWidget {
  const _GoalTextPage({
    required this.question,
    required this.onContinue,
    this.initialValue,
    this.hintText,
    this.continueLabel = 'Continue',
    this.onSkip,
    this.skipLabel = 'Not now',
    this.maxLength = 1000,
  });

  final String question;
  final String? initialValue;
  final String? hintText;
  final String continueLabel;
  final FutureOr<void> Function(String value) onContinue;
  final FutureOr<void> Function()? onSkip;
  final String skipLabel;
  final int maxLength;

  @override
  State<_GoalTextPage> createState() => _GoalTextPageState();
}

class _GoalTextPageState extends State<_GoalTextPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );
  var _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(FutureOr<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.question,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('first-goal-text-field'),
              controller: _controller,
              autofocus: true,
              maxLength: widget.maxLength,
              minLines: widget.maxLength > 120 ? 2 : 1,
              maxLines: widget.maxLength > 120 ? 5 : 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: widget.hintText),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _working
                  ? null
                  : () =>
                        _run(() => widget.onContinue(_controller.text.trim())),
              child: Text(_working ? 'Keeping…' : widget.continueLabel),
            ),
            if (widget.onSkip case final onSkip?)
              TextButton(
                onPressed: _working ? null : () => _run(onSkip),
                child: Text(widget.skipLabel),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SavingGoal extends StatelessWidget {
  const _SavingGoal({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keep this Goal',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class _GoalMessage extends StatelessWidget {
  const _GoalMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
