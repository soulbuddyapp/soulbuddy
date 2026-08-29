import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/storage/persistent_storage.dart';
import '../../goals/domain/goal_link.dart';
import '../../prayers/presentation/voice_tablet_player.dart';
import '../../prayers/providers/voice_tablet_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/presentation/encounter_form.dart';
import '../../record/providers/encounter_providers.dart';
import '../application/return_plan.dart';
import '../data/bundled_guard_catalogue.dart';
import '../domain/guard_definition.dart';
import '../providers/return_providers.dart';
import 'guard_configuration_sheet.dart';

Future<void> showReturnSheet(
  BuildContext context, {
  required String goalId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => ReturnSheet(goalId: goalId),
  );
}

class ReturnSheet extends ConsumerWidget {
  const ReturnSheet({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(goalReturnPlanProvider(goalId));
    final height = MediaQuery.sizeOf(context).height * 0.94;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: height,
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ReturnUnavailable(
            onRetry: () => ref.invalidate(goalReturnPlanProvider(goalId)),
          ),
          data: (value) => value.relevant
              ? _ReturnContent(plan: value)
              : const _ReturnNotRelevant(),
        ),
      ),
    );
  }
}

class _ReturnContent extends ConsumerWidget {
  const _ReturnContent({required this.plan});

  final ReturnPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(guardCatalogueProvider);
    return Column(
      children: [
        _ReturnHeader(goalTitle: plan.goal.title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              if (plan.isDegraded) ...[
                const _DegradedNotice(),
                const SizedBox(height: AppSpacing.md),
              ],
              const _ReturnStepCard(
                number: 1,
                title: 'Move',
                body:
                    'Leave the place, device, account, or circumstance giving immediate opportunity.',
              ),
              const SizedBox(height: AppSpacing.md),
              _ReturnStepCard(
                number: 2,
                title: 'Close the door',
                body: plan.barrierAction?.body ?? 'No barrier action configured.',
                details: [
                  for (final selection in plan.guardSelections)
                    _GuardSummary(
                      selection: selection,
                      definition: _definitionFor(
                        catalogue,
                        selection.guardDefinitionId,
                      ),
                    ),
                ],
                action: OutlinedButton.icon(
                  key: const Key('return-configure-walls'),
                  onPressed: () => showGuardConfigurationSheet(
                    context,
                    goal: plan.goal,
                  ),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Configure walls'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ReturnStepCard(
                number: 3,
                title: 'Return to God',
                body: _spiritualResourceLabel(plan.spiritualResource),
                action: plan.spiritualResource == null
                    ? null
                    : FilledButton.tonalIcon(
                        key: const Key('return-open-spiritual-resource'),
                        onPressed: () => _openSpiritualResource(
                          context,
                          plan.spiritualResource!,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open'),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ReturnStepCard(
                number: 4,
                title: 'Do the replacement',
                body:
                    plan.replacementAction?.body ??
                    'No replacement action configured.',
              ),
              const SizedBox(height: AppSpacing.md),
              _ReturnStepCard(
                number: 5,
                title: 'Do not hide',
                body:
                    plan.accountabilityAction?.body ??
                    'No accountability step configured.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'After the immediate moment',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('return-record-open-door'),
                onPressed: () => _recordOpenDoor(context),
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('What door was still open?'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _recordOpenDoor(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _ReturnReflectionSheet(),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record saved.')),
    );
  }
}

class _ReturnHeader extends StatelessWidget {
  const _ReturnHeader({required this.goalTitle});

  final String goalTitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Return',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                goalTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close Return',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _ReturnStepCard extends StatelessWidget {
  const _ReturnStepCard({
    required this.number,
    required this.title,
    required this.body,
    this.details = const [],
    this.action,
  });

  final int number;
  final String title;
  final String body;
  final List<Widget> details;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('return-step-$number'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepNumber(number: number),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ..._spaced(details),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    ),
  );
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(
      dimension: 32,
      child: Center(
        child: Text(
          '$number',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    ),
  );
}

class _GuardSummary extends StatelessWidget {
  const _GuardSummary({required this.selection, required this.definition});

  final GoalGuardSelection selection;
  final GuardDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final title = definition?.title ?? 'Configured wall';
    final note = selection.privateNote?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(note),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DegradedNotice extends StatelessWidget {
  const _DegradedNotice();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'Some saved Return details are unavailable just now. The core steps are still available.',
        ),
      ),
    ),
  );
}

class _ReturnReflectionSheet extends ConsumerWidget {
  const _ReturnReflectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(encounterRepositoryProvider);
    return repository.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ReflectionUnavailable(
        onRetry: () => ref.invalidate(encounterRepositoryProvider),
      ),
      data: (value) => EncounterForm(
        memoryType: MemoryType.lesson,
        initialTitle: 'What door was still open?',
        onCancel: () => Navigator.pop(context, false),
        onSave: (draft) async {
          await value.create(draft);
          unawaited(requestPersistentStorage());
          if (context.mounted) Navigator.pop(context, true);
        },
      ),
    );
  }
}

class _ReflectionUnavailable extends StatelessWidget {
  const _ReflectionUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Record could not be opened just now.'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class _ReturnUnavailable extends StatelessWidget {
  const _ReturnUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Return could not be opened just now.'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class _ReturnNotRelevant extends StatelessWidget {
  const _ReturnNotRelevant();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Return is not configured for this Goal.'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openSpiritualResource(
  BuildContext context,
  GoalLink link,
) async {
  switch (link.type) {
    case GoalLinkType.personalPrayer:
      final id = link.personalPrayerId;
      if (id == null) break;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.go('/prayers/saved/$id');
      return;
    case GoalLinkType.libraryPrayer:
      final id = link.libraryPrayerId;
      if (id == null) break;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.go('/prayers/$id');
      return;
    case GoalLinkType.scripture:
      final book = link.book;
      final chapter = link.chapter;
      if (book == null || chapter == null) break;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.go(
        '/remember/scripture/${Uri.encodeComponent(book)}/$chapter',
      );
      return;
    case GoalLinkType.voiceTablet:
      final id = link.voiceTabletId;
      if (id == null) break;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => _ReturnVoiceTabletSheet(tabletId: id),
      );
      return;
    case GoalLinkType.encounter || GoalLinkType.circle:
      break;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('This resource could not be opened.')),
  );
}

class _ReturnVoiceTabletSheet extends ConsumerWidget {
  const _ReturnVoiceTabletSheet({required this.tabletId});

  final String tabletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablet = ref.watch(voiceTabletProvider(tabletId));
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Voice Tablet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close Voice Tablet',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: tablet.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(voiceTabletProvider(tabletId)),
                  child: const Text('Try Voice Tablet again'),
                ),
              ),
              data: (value) => value == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'This Voice Tablet is not available on this device.',
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: VoiceTabletPlayer(tablet: value),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

String _spiritualResourceLabel(GoalLink? link) {
  if (link == null) return 'No prayer, Scripture, or Voice Tablet configured.';
  return switch (link.type) {
    GoalLinkType.personalPrayer || GoalLinkType.libraryPrayer => 'Prayer',
    GoalLinkType.scripture => _scriptureLabel(link),
    GoalLinkType.voiceTablet => 'Voice Tablet',
    GoalLinkType.encounter || GoalLinkType.circle => 'Configured resource',
  };
}

String _scriptureLabel(GoalLink link) {
  final book = link.book;
  final chapter = link.chapter;
  final first = link.firstVerse;
  final last = link.lastVerse;
  if (book == null || chapter == null || first == null || last == null) {
    return 'Scripture';
  }
  final verses = first == last ? '$first' : '$first-$last';
  return '$book $chapter:$verses';
}

GuardDefinition? _definitionFor(
  List<GuardDefinition> definitions,
  String id,
) {
  for (final definition in definitions) {
    if (definition.id == id) return definition;
  }
  return BundledGuardCatalogue.find(id);
}

List<Widget> _spaced(List<Widget> widgets) {
  if (widgets.length < 2) return widgets;
  final result = <Widget>[];
  for (var index = 0; index < widgets.length; index++) {
    result.add(widgets[index]);
    if (index != widgets.length - 1) {
      result.add(const SizedBox(height: AppSpacing.xs));
    }
  }
  return result;
}
