import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';
import '../domain/prayer_generation_request.dart';
import '../providers/personal_prayer_providers.dart';
import '../../record/providers/encounter_providers.dart';
import 'personalized_prayer_choices.dart';
import 'prayer_context_picker.dart';

class PersonalizedPrayerScreen extends ConsumerStatefulWidget {
  const PersonalizedPrayerScreen({
    this.requestId,
    this.initialMemoryId,
    super.key,
  });

  final String? requestId;
  final String? initialMemoryId;

  @override
  ConsumerState<PersonalizedPrayerScreen> createState() =>
      _PersonalizedPrayerScreenState();
}

class _PersonalizedPrayerScreenState
    extends ConsumerState<PersonalizedPrayerScreen> {
  bool _addingInitialMemory = false;

  @override
  Widget build(BuildContext context) {
    final requestId = widget.requestId;
    final provider = personalizedPrayerControllerProvider(requestId);
    final flow = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      final value = next.value;
      final previousValue = previous?.value;
      if (requestId != null ||
          value?.request == null ||
          value!.step == PersonalizedPrayerStep.request ||
          previousValue?.step == value.step) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final memoryQuery = widget.initialMemoryId == null
            ? ''
            : '?memoryId=${Uri.encodeComponent(widget.initialMemoryId!)}';
        GoRouter.maybeOf(
          context,
        )?.go('/prayers/requests/${value.request!.id}$memoryQuery');
      });
    });
    ref.listen(provider, (previous, next) {
      final memoryId = widget.initialMemoryId;
      final request = next.value?.request;
      if (memoryId == null ||
          request == null ||
          _addingInitialMemory ||
          request.contexts.any((item) => item.sourceId == memoryId)) {
        return;
      }
      _addingInitialMemory = true;
      unawaited(_addInitialMemory(requestId, memoryId));
    });
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: flow.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  _FlowUnavailable(onRetry: () => ref.invalidate(provider)),
              data: (state) => _FlowBody(
                requestId: requestId,
                state: state,
                controller: ref.read(provider.notifier),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addInitialMemory(String? requestId, String memoryId) async {
    try {
      final memories = await ref.read(encountersProvider.future);
      final matches = memories.where((item) => item.id == memoryId);
      if (matches.isNotEmpty) {
        await ref
            .read(personalizedPrayerControllerProvider(requestId).notifier)
            .addEncounter(matches.first);
      }
    } finally {
      _addingInitialMemory = false;
    }
  }
}

class _FlowBody extends StatelessWidget {
  const _FlowBody({
    required this.requestId,
    required this.state,
    required this.controller,
  });

  final String? requestId;
  final PersonalizedPrayerFlowState state;
  final PersonalizedPrayerController controller;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              if (state.step == PersonalizedPrayerStep.style) {
                Navigator.of(context).maybePop();
              } else {
                controller.goBack();
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: Text(
              state.step == PersonalizedPrayerStep.style ? 'Prayers' : 'Back',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(value: _progress(state.step)),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            _heading(state.step),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _description(state.step),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        content,
      ],
    );
  }

  Widget _content(BuildContext context) {
    return switch (state.step) {
      PersonalizedPrayerStep.style => PersonalizedPrayerChoices<PrayerStyle>(
        label: 'Prayer style',
        selected: state.style,
        choices: const [
          PersonalizedPrayerChoice(
            value: PrayerStyle.daily,
            label: 'Daily / affirming',
          ),
          PersonalizedPrayerChoice(
            value: PrayerStyle.situational,
            label: 'Situational / special',
          ),
        ],
        onSelected: controller.chooseStyle,
      ),
      PersonalizedPrayerStep.reach => PersonalizedPrayerChoices<PrayerReach>(
        label: 'Prayer reach',
        selected: state.reach,
        choices: const [
          PersonalizedPrayerChoice(
            value: PrayerReach.personal,
            label: 'Personal',
          ),
          PersonalizedPrayerChoice(
            value: PrayerReach.encompassing,
            label: 'Encompassing / selfless',
          ),
        ],
        onSelected: controller.chooseReach,
      ),
      PersonalizedPrayerStep.grounding =>
        PersonalizedPrayerChoices<PrayerGrounding>(
          label: 'Prayer grounding',
          selected: state.grounding,
          choices: const [
            PersonalizedPrayerChoice(
              value: PrayerGrounding.generalChristian,
              label: 'General Christian',
            ),
            PersonalizedPrayerChoice(
              value: PrayerGrounding.catholic,
              label: 'Catholic',
            ),
          ],
          onSelected: controller.chooseGrounding,
        ),
      PersonalizedPrayerStep.purpose =>
        PersonalizedPrayerChoices<PrayerPurpose>(
          label: 'Prayer purpose',
          selected: state.purpose,
          choices: const [
            PersonalizedPrayerChoice(
              value: PrayerPurpose.daily,
              label: 'Daily',
            ),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.gratitude,
              label: 'Gratitude',
            ),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.guidance,
              label: 'Guidance',
            ),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.family,
              label: 'Family',
            ),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.healing,
              label: 'Healing',
            ),
            PersonalizedPrayerChoice(value: PrayerPurpose.work, label: 'Work'),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.forgiveness,
              label: 'Forgiveness',
            ),
            PersonalizedPrayerChoice(
              value: PrayerPurpose.difficultTime,
              label: 'A difficult time',
            ),
          ],
          onSelected: controller.choosePurpose,
        ),
      PersonalizedPrayerStep.request => _RequestStep(
        initialValue: state.requestText,
        onChanged: controller.setRequestText,
        onContinue: controller.continueFromRequest,
      ),
      PersonalizedPrayerStep.beneficiary => _BeforeYouAsk(
        question: 'Who should this blessing help?',
        selected: state.request?.beneficiaryChoice,
        choices: const [
          PersonalizedPrayerChoice(value: 'me', label: 'Me'),
          PersonalizedPrayerChoice(
            value: 'household_family',
            label: 'My household or family',
          ),
          PersonalizedPrayerChoice(
            value: 'another_person',
            label: 'Another person',
          ),
          PersonalizedPrayerChoice(
            value: 'people_affected',
            label: 'People affected by this',
          ),
          PersonalizedPrayerChoice(
            value: 'beyond_my_sight',
            label: 'Beyond what I can see',
          ),
        ],
        onSelected: controller.chooseBeneficiary,
      ),
      PersonalizedPrayerStep.surrender => _BeforeYouAsk(
        question: 'What can you entrust to God?',
        selected: state.request?.surrenderChoice,
        choices: const [
          PersonalizedPrayerChoice(value: 'outcome', label: 'The outcome'),
          PersonalizedPrayerChoice(value: 'timing', label: 'The timing'),
          PersonalizedPrayerChoice(
            value: 'way_it_happens',
            label: 'The way it happens',
          ),
          PersonalizedPrayerChoice(value: 'all', label: 'All of these'),
        ],
        onSelected: controller.chooseSurrender,
      ),
      PersonalizedPrayerStep.responsibility => _BeforeYouAsk(
        question: 'If it is given, what responsibility may come with it?',
        selected: state.request?.responsibilityChoice,
        choices: const [
          PersonalizedPrayerChoice(value: 'use_wisely', label: 'Use it wisely'),
          PersonalizedPrayerChoice(
            value: 'share_or_serve',
            label: 'Share or serve',
          ),
          PersonalizedPrayerChoice(
            value: 'repair_attention',
            label: 'Repair what needs attention',
          ),
          PersonalizedPrayerChoice(
            value: 'act_faithfully',
            label: 'Act faithfully',
          ),
          PersonalizedPrayerChoice(
            value: 'time_to_discern',
            label: 'I need time to discern',
          ),
        ],
        onSelected: controller.chooseResponsibility,
      ),
      PersonalizedPrayerStep.alignment => _BeforeYouAsk(
        question:
            'Could this conflict with love, truth, justice, or a responsibility?',
        selected: state.request?.alignmentChoice,
        choices: const [
          PersonalizedPrayerChoice(
            value: 'no_conflict_seen',
            label: 'I see no conflict',
          ),
          PersonalizedPrayerChoice(
            value: 'examine_further',
            label: 'I want to examine this further',
          ),
        ],
        onSelected: controller.chooseAlignment,
      ),
      PersonalizedPrayerStep.context => _ContextStep(
        requestId: requestId,
        request: state.request!,
        onPrepare: () => _prepareDraft(context),
      ),
    };
  }

  Future<void> _prepareDraft(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _PrayerDraftConsentSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    final id = await controller.prepareDraft();
    if (!context.mounted) return;
    GoRouter.maybeOf(context)?.go('/prayers/requests/$id/draft');
  }
}

class _RequestStep extends StatelessWidget {
  const _RequestStep({
    required this.initialValue,
    required this.onChanged,
    required this.onContinue,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('prayer-request-field'),
          initialValue: initialValue,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'What would you like help praying about?',
            hintText: 'Help me receive and use wisdom today.',
            alignLabelWithHint: true,
          ),
          onChanged: onChanged,
          onFieldSubmitted: (_) => onContinue(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
      ],
    );
  }
}

class _BeforeYouAsk extends StatelessWidget {
  const _BeforeYouAsk({
    required this.question,
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final String question;
  final List<PersonalizedPrayerChoice<String>> choices;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before you ask',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        PersonalizedPrayerChoices<String>(
          label: question,
          selected: selected,
          choices: choices,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _ContextStep extends StatelessWidget {
  const _ContextStep({
    required this.requestId,
    required this.request,
    required this.onPrepare,
  });

  final String? requestId;
  final PrayerGenerationRequest request;
  final Future<void> Function() onPrepare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final context in request.contexts)
          Card(
            child: ListTile(
              leading: Icon(
                context.type == PrayerContextType.encounter
                    ? Icons.bookmark_outline
                    : Icons.menu_book_outlined,
              ),
              title: Text(context.displayLabel),
              subtitle: Text(
                context.type == PrayerContextType.scripture
                    ? 'RSVCE - Scripture'
                    : 'Encounter',
              ),
              trailing: const Icon(Icons.check_circle_outline),
            ),
          ),
        if (request.contexts.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () =>
              PrayerContextPicker.showEncounter(context, requestId: requestId),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Add Encounter'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () =>
              PrayerContextPicker.showScripture(context, requestId: requestId),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Add Scripture'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('prepare-prayer-draft'),
          onPressed: onPrepare,
          child: const Text('Prepare draft'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Only the choices and records you select will be used for this draft.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PrayerDraftConsentSheet extends StatelessWidget {
  const _PrayerDraftConsentSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prepare your prayer draft',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'To prepare this draft, SoulBuddy sends your choices and only the records you selected to DeepSeek. DeepSeek processes this information under its privacy policy.',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Prepare draft'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowUnavailable extends StatelessWidget {
  const _FlowUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This prayer draft could not be opened just now.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _heading(PersonalizedPrayerStep step) => switch (step) {
  PersonalizedPrayerStep.style => 'Choose a prayer style',
  PersonalizedPrayerStep.reach => 'Who is this prayer for?',
  PersonalizedPrayerStep.grounding => 'Choose a grounding',
  PersonalizedPrayerStep.purpose => 'Choose a purpose',
  PersonalizedPrayerStep.request => 'Name your request',
  PersonalizedPrayerStep.beneficiary ||
  PersonalizedPrayerStep.surrender ||
  PersonalizedPrayerStep.responsibility ||
  PersonalizedPrayerStep.alignment => 'A moment of preparation',
  PersonalizedPrayerStep.context => 'Add context',
};

String _description(PersonalizedPrayerStep step) => switch (step) {
  PersonalizedPrayerStep.style =>
    'SoulBuddy will guide the wording; the prayer remains yours before God.',
  PersonalizedPrayerStep.reach =>
    'Choose whether to begin with your own need or hold others within it.',
  PersonalizedPrayerStep.grounding =>
    'This guides the language without replacing your own tradition or counsel.',
  PersonalizedPrayerStep.purpose => 'Choose what best fits this moment.',
  PersonalizedPrayerStep.request =>
    'One short sentence is enough. You can edit the prayer draft later.',
  PersonalizedPrayerStep.beneficiary ||
  PersonalizedPrayerStep.surrender ||
  PersonalizedPrayerStep.responsibility ||
  PersonalizedPrayerStep.alignment =>
    'These choices guide the prayer. They are not a test.',
  PersonalizedPrayerStep.context =>
    'Optionally connect one Encounter and/or one Scripture passage.',
};

double _progress(PersonalizedPrayerStep step) => switch (step) {
  PersonalizedPrayerStep.style => 0.12,
  PersonalizedPrayerStep.reach => 0.25,
  PersonalizedPrayerStep.grounding => 0.38,
  PersonalizedPrayerStep.purpose => 0.5,
  PersonalizedPrayerStep.request => 0.62,
  PersonalizedPrayerStep.beneficiary => 0.7,
  PersonalizedPrayerStep.surrender => 0.77,
  PersonalizedPrayerStep.responsibility => 0.84,
  PersonalizedPrayerStep.alignment => 0.91,
  PersonalizedPrayerStep.context => 1,
};
