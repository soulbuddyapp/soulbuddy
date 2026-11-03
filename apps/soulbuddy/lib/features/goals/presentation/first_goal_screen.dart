import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../guards/application/guard_recommendations.dart';
import '../../guards/data/bundled_guard_catalogue.dart';
import '../../onboarding/presentation/first_prayer_choice_page.dart';
import '../../prayers/providers/recorded_personal_prayer_providers.dart';
import '../../record/audio/presentation/inline_audio_capture.dart';
import '../../record/data/voice_note_repository.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../record/providers/voice_note_providers.dart';
import '../../scripture/presentation/scripture_picker_sheet.dart';
import '../application/goal_starter_content.dart';
import '../domain/goal.dart';
import '../domain/goal_action_suggestion.dart';
import '../domain/goal_onboarding_progress.dart';
import '../providers/goal_onboarding_providers.dart';
import 'goal_action_suggestion_panel.dart';

class FirstGoalScreen extends ConsumerStatefulWidget {
  const FirstGoalScreen({super.key});

  @override
  ConsumerState<FirstGoalScreen> createState() => _FirstGoalScreenState();
}

class _FirstGoalScreenState extends ConsumerState<FirstGoalScreen> {
  var _saving = false;
  var _recordingBusy = false;
  String? _pendingPrayerId;

  bool get _blocked => _saving || _recordingBusy;

  void _setRecordingBusy(bool busy) {
    if (mounted) setState(() => _recordingBusy = busy);
  }

  static const _situationContext = (
    type: 'goal',
    id: 'onboarding',
    field: 'situation',
  );

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
      data: (progress) => PopScope(
        canPop: !_blocked,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('New Goal'),
            leading: _canGoBack(progress)
                ? IconButton(
                    tooltip: 'Back',
                    onPressed: _blocked ? null : () => _goBack(progress),
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            actions: [
              if (compactTodayAction)
                IconButton(
                  tooltip: 'Go to Today',
                  onPressed: _blocked ? null : () => context.go('/today'),
                  icon: const Icon(Icons.today_outlined),
                )
              else
                TextButton(
                  onPressed: _blocked ? null : () => context.go('/today'),
                  child: const Text('Go to Today'),
                ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey((progress.stage, progress.title == null)),
              child: _page(progress),
            ),
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
        _pendingPrayerId = null;
        unawaited(
          ref
              .read(goalOnboardingControllerProvider.notifier)
              .chooseStarter(option.key),
        );
      },
    ),
    GoalOnboardingStage.stopBehavior => FirstPrayerChoicePage(
      question: 'What are you trying to stop?',
      choices: goalStopBehaviorOptions.map((option) => option.label).toList(),
      onChoose: (label) {
        final option = goalStopBehaviorOptions.firstWhere(
          (item) => item.label == label,
        );
        unawaited(
          ref
              .read(goalOnboardingControllerProvider.notifier)
              .chooseStopBehavior(option.key),
        );
      },
    ),
    GoalOnboardingStage.alcoholSafety => _AlcoholSafetyPage(
      onMedicalGuidance: () => ref
          .read(goalOnboardingControllerProvider.notifier)
          .chooseAlcoholSafety(GoalAlcoholSafetyChoice.medicalGuidance),
      onNoKnownRisk: () => ref
          .read(goalOnboardingControllerProvider.notifier)
          .chooseAlcoholSafety(GoalAlcoholSafetyChoice.noKnownWithdrawalRisk),
    ),
    GoalOnboardingStage.alcoholCare => _AlcoholCarePage(
      onContinue: () => ref
          .read(goalOnboardingControllerProvider.notifier)
          .confirmAlcoholCare(),
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
      hintText: _todayActionHint(progress),
      continueLabel: 'Keep this',
      enabled: !_blocked,
      recording: VoiceNotesField(
        noteContext: (type: 'goal', id: 'onboarding', field: 'action'),
        title: 'Action notes',
        onBusyChanged: _setRecordingBusy,
      ),
      suggestionRequest: GoalActionSuggestionRequest(
        starterKey: progress.starterKey!,
        stopBehaviorKey: progress.stopBehaviorKey,
        title: progress.title!,
        situation: progress.currentSituation,
        agencyChoice: progress.agencyChoice!,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
      showSuggestionsByDefault:
          progress.agencyChoice == GoalAgencyChoice.notSure,
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
      supporting: _GuardSuggestions(behaviorKey: progress.stopBehaviorKey),
      enabled: !_blocked,
      recording: VoiceNotesField(
        noteContext: (type: 'goal', id: 'onboarding', field: 'guard'),
        title: 'Guard notes',
        onBusyChanged: _setRecordingBusy,
      ),
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
      final behavior = stopBehaviorOption(progress.stopBehaviorKey);
      final stopping = progress.starterKey == GoalStarterKey.stopControl;
      return _GoalTextPage(
        question:
            behavior?.titleQuestion ??
            (stopping ? 'What do you want to stop?' : 'Name it simply.'),
        hintText:
            behavior?.titleHint ??
            (stopping
                ? 'For example: Stop watching pornography'
                : 'What would you like help with?'),
        supporting: behavior?.supportNote == null
            ? null
            : _BehaviorSupportNote(text: behavior!.supportNote!),
        continueLabel: 'Continue',
        maxLength: 120,
        requireText: true,
        onContinue: (value) =>
            ref.read(goalOnboardingControllerProvider.notifier).setTitle(value),
      );
    }

    final notes = ref.watch(voiceNotesProvider(_situationContext));
    final recordings = notes.value ?? const <VoiceNoteLink>[];
    final earlierNote = progress.currentSituation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Why now? What needs to change?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              VoiceNotesField(
                key: const Key('first-goal-situation-recording'),
                noteContext: _situationContext,
                title: 'My situation',
                enabled: !_blocked,
                onBusyChanged: _setRecordingBusy,
              ),
              if (recordings.isEmpty && earlierNote != null) ...[
                const SizedBox(height: AppSpacing.md),
                ExpansionTile(
                  title: const Text('Earlier note'),
                  children: [Text(earlierNote)],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (recordings.isNotEmpty || earlierNote != null)
                FilledButton(
                  key: const Key('first-goal-situation-continue'),
                  onPressed: _blocked
                      ? null
                      : () => ref
                            .read(goalOnboardingControllerProvider.notifier)
                            .setSituation(
                              situation: recordings.isEmpty
                                  ? earlierNote
                                  : recordings.first.title,
                              byVoice:
                                  recordings.isNotEmpty ||
                                  progress.situationByVoice == true,
                            ),
                  child: const Text('Continue'),
                ),
              TextButton(
                onPressed: _blocked
                    ? null
                    : () => ref
                          .read(goalOnboardingControllerProvider.notifier)
                          .setSituation(situation: null, byVoice: false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _todayActionHint(GoalOnboardingProgress progress) {
    return stopBehaviorOption(progress.stopBehaviorKey)?.todayActionHint ??
        'One small faithful step';
  }

  Widget _prayerPage(GoalOnboardingProgress progress) {
    final starterKey = progress.starterKey;
    if (starterKey == null) {
      return const _GoalMessage('This Goal needs a starting point.');
    }
    final prayers = ref.watch(firstGoalPrayerOptionsProvider(starterKey));
    final scriptureReference = _scriptureReference(progress);
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
                    'Choose a prayer or Scripture, or record your own prayer.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  prayers.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text(
                      'Prepared prayers are unavailable just now.',
                    ),
                    data: (items) => Column(
                      children: [
                        for (final prayer in items) ...[
                          Card(
                            child: ListTile(
                              key: Key('first-goal-prayer-${prayer.id}'),
                              title: Text(prayer.title),
                              subtitle: Text(
                                prayer.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                  if (scriptureReference != null) ...[
                    Card(
                      child: ListTile(
                        key: const Key('first-goal-scripture-selection'),
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(scriptureReference),
                        subtitle: Text(progress.scriptureTranslation!),
                        trailing: const Icon(Icons.check_circle_outline),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  OutlinedButton.icon(
                    key: const Key('first-goal-scripture'),
                    onPressed: _blocked ? null : _chooseScripture,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(
                      scriptureReference == null
                          ? 'Choose Scripture'
                          : 'Change Scripture',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InlineAudioCapture(
                    key: const Key('first-goal-own-prayer'),
                    enableSoundscape: true,
                    enabled: !_saving,
                    onBusyChanged: _setRecordingBusy,
                    onDiscarded: () => _pendingPrayerId = null,
                    label:
                        progress.prayerSource ==
                            GoalOnboardingPrayerSource.personalPrayer
                        ? 'Record another prayer'
                        : 'Record my prayer',
                    onSave: (draft) async {
                      if (_pendingPrayerId == null) {
                        final repository = await ref.read(
                          recordedPersonalPrayerRepositoryProvider.future,
                        );
                        final prayer = await repository.create(
                          title: progress.title ?? 'My prayer',
                          purpose: prayerPurposeForGoalStarter(
                            progress.starterKey!,
                          ),
                          audio: draft,
                        );
                        _pendingPrayerId = prayer.id;
                      }
                      await ref
                          .read(goalOnboardingControllerProvider.notifier)
                          .choosePersonalPrayer(_pendingPrayerId!);
                      _pendingPrayerId = null;
                    },
                  ),
                  if (progress.prayerSource ==
                      GoalOnboardingPrayerSource.personalPrayer)
                    const ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Your prayer is selected'),
                    ),
                  if (progress.prayerSource ==
                          GoalOnboardingPrayerSource.ownWords &&
                      progress.ownPrayerText != null)
                    ExpansionTile(
                      title: const Text('Earlier prayer'),
                      children: [Text(progress.ownPrayerText!)],
                    ),
                  if (progress.hasCompletePrayerSelection) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('finish-first-goal'),
                      onPressed: _blocked ? null : _finish,
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

  Future<void> _chooseScripture() async {
    final selection = await showScripturePicker(context);
    if (selection == null || !mounted) return;
    await ref
        .read(goalOnboardingControllerProvider.notifier)
        .chooseScripture(
          translation: selection.translation,
          book: selection.book,
          chapter: selection.chapter,
          firstVerse: selection.firstVerse,
          lastVerse: selection.lastVerse,
        );
  }

  String? _scriptureReference(GoalOnboardingProgress progress) {
    if (progress.prayerSource != GoalOnboardingPrayerSource.scripture ||
        progress.scriptureBook == null ||
        progress.scriptureChapter == null ||
        progress.scriptureFirstVerse == null ||
        progress.scriptureLastVerse == null) {
      return null;
    }
    final verses = progress.scriptureFirstVerse == progress.scriptureLastVerse
        ? '${progress.scriptureFirstVerse}'
        : '${progress.scriptureFirstVerse}-${progress.scriptureLastVerse}';
    return '${progress.scriptureBook} ${progress.scriptureChapter}:$verses';
  }

  bool _canGoBack(GoalOnboardingProgress progress) {
    return progress.stage != GoalOnboardingStage.starter;
  }

  Future<void> _goBack(GoalOnboardingProgress progress) async {
    await ref.read(goalOnboardingControllerProvider.notifier).goBack();
  }

  Future<void> _finish() async {
    if (_blocked) return;
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

class _AlcoholSafetyPage extends StatefulWidget {
  const _AlcoholSafetyPage({
    required this.onMedicalGuidance,
    required this.onNoKnownRisk,
  });

  final Future<void> Function() onMedicalGuidance;
  final Future<void> Function() onNoKnownRisk;

  @override
  State<_AlcoholSafetyPage> createState() => _AlcoholSafetyPageState();
}

class _AlcoholSafetyPageState extends State<_AlcoholSafetyPage> {
  var _working = false;

  Future<void> _run(Future<void> Function() action) async {
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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Before you make an alcohol plan',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Stopping suddenly after prolonged heavy drinking can cause dangerous withdrawal.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SoulBuddy cannot assess withdrawal risk. If you drink heavily or regularly, have had shaking, sweating, vomiting, hallucinations or seizures when cutting down, or you are not sure, get medical guidance before stopping.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'If severe withdrawal symptoms are happening now, seek emergency medical care.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('first-goal-alcohol-medical-guidance'),
              onPressed: _working ? null : () => _run(widget.onMedicalGuidance),
              child: const Text('This may apply, or I’m not sure'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('first-goal-alcohol-no-known-risk'),
              onPressed: _working ? null : () => _run(widget.onNoKnownRisk),
              child: const Text('None of these apply to me'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reviewed safety source: NIAAA',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AlcoholCarePage extends StatefulWidget {
  const _AlcoholCarePage({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  State<_AlcoholCarePage> createState() => _AlcoholCarePageState();
}

class _AlcoholCarePageState extends State<_AlcoholCarePage> {
  var _working = false;

  Future<void> _continue() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await widget.onContinue();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Make medical guidance the first step',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Do not use SoulBuddy as a detox plan. Contact a qualified medical professional or appropriate medical service before stopping heavy alcohol use suddenly.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'SoulBuddy can still support prayer, accountability and practical walls around that care.',
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('first-goal-alcohol-care-reviewed'),
              onPressed: _working ? null : _continue,
              child: Text(_working ? 'Keeping…' : 'I understand — continue'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BehaviorSupportNote extends StatelessWidget {
  const _BehaviorSupportNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(text),
    ),
  );
}

class _GuardSuggestions extends StatelessWidget {
  const _GuardSuggestions({required this.behaviorKey});

  final GoalStopBehaviorKey? behaviorKey;

  @override
  Widget build(BuildContext context) {
    final option = stopBehaviorOption(behaviorKey);
    final definitions = recommendedGuardDefinitions(
      definitions: BundledGuardCatalogue.definitions,
      contextTag: option?.guardContextTag,
    );
    if (definitions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Walls to consider',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reviewed ideas only. Nothing is configured until you set it up and save it from Return.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < definitions.length; index++) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definitions[index].title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(definitions[index].description),
                ],
              ),
            ),
          ),
          if (index != definitions.length - 1)
            const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _GoalTextPage extends StatefulWidget {
  const _GoalTextPage({
    required this.question,
    required this.onContinue,
    this.initialValue,
    this.hintText,
    this.continueLabel = 'Continue',
    this.onSkip,
    this.maxLength = 120,
    this.requireText = false,
    this.supporting,
    this.recording,
    this.suggestionRequest,
    this.showSuggestionsByDefault = false,
    this.enabled = true,
  });

  final String question;
  final String? initialValue;
  final String? hintText;
  final String continueLabel;
  final FutureOr<void> Function(String value) onContinue;
  final FutureOr<void> Function()? onSkip;
  final int maxLength;
  final bool requireText;
  final Widget? supporting;
  final Widget? recording;
  final GoalActionSuggestionRequest? suggestionRequest;
  final bool showSuggestionsByDefault;
  final bool enabled;

  @override
  State<_GoalTextPage> createState() => _GoalTextPageState();
}

class _GoalTextPageState extends State<_GoalTextPage> {
  bool get _hasLegacyText =>
      widget.initialValue != null &&
      (widget.initialValue!.runes.length > widget.maxLength ||
          widget.initialValue!.contains('\n'));

  late final TextEditingController _controller = TextEditingController(
    text: _hasLegacyText ? '' : widget.initialValue ?? '',
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
            if (widget.supporting != null) ...[
              const SizedBox(height: AppSpacing.md),
              widget.supporting!,
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('first-goal-text-field'),
              controller: _controller,
              enabled: widget.enabled && !_working,
              autofocus: true,
              maxLength: widget.maxLength,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Short title',
                hintText: widget.hintText,
              ),
            ),
            if (_hasLegacyText)
              ExpansionTile(
                title: const Text('Earlier note'),
                children: [Text(widget.initialValue!)],
              ),
            if (widget.recording != null) ...[
              const SizedBox(height: AppSpacing.md),
              widget.recording!,
            ],
            if (widget.suggestionRequest case final request?) ...[
              const SizedBox(height: AppSpacing.sm),
              GoalActionSuggestionPanel(
                request: request,
                expandedInitially: widget.showSuggestionsByDefault,
                onChoose: (text) {
                  _controller.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                final missingRequiredText =
                    widget.requireText && value.text.trim().isEmpty;
                final invalidLabel =
                    value.text.trim().runes.length > widget.maxLength ||
                    value.text.contains('\n');
                return FilledButton(
                  key: const Key('first-goal-text-continue'),
                  onPressed:
                      !widget.enabled ||
                          _working ||
                          missingRequiredText ||
                          invalidLabel
                      ? null
                      : () => _run(
                          () => widget.onContinue(
                            _controller.text.trim().isEmpty && _hasLegacyText
                                ? widget.initialValue!.trim()
                                : _controller.text.trim(),
                          ),
                        ),
                  child: Text(_working ? 'Keeping…' : widget.continueLabel),
                );
              },
            ),
            if (widget.onSkip case final onSkip?)
              TextButton(
                onPressed: !widget.enabled || _working
                    ? null
                    : () => _run(onSkip),
                child: const Text('Not now'),
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
