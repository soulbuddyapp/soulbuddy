import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../goals/domain/goal.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../../core/speech/sayable_field.dart';
import '../domain/guard_definition.dart';
import '../providers/guard_providers.dart';

Future<void> showGuardConfigurationSheet(
  BuildContext context, {
  required Goal goal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => GuardConfigurationSheet(goal: goal),
  );
}

class GuardConfigurationSheet extends ConsumerWidget {
  const GuardConfigurationSheet({required this.goal, super.key});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(goalGuardSelectionsProvider(goal.id));
    final catalogue = ref.watch(guardCatalogueProvider);
    final height = MediaQuery.sizeOf(context).height * 0.94;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            _Header(goalTitle: goal.title),
            Expanded(
              child: selections.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Unavailable(
                  onRetry: () =>
                      ref.invalidate(goalGuardSelectionsProvider(goal.id)),
                ),
                data: (value) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      'Choose concrete walls you have reviewed or configured for this Goal.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'SoulBuddy records your configuration choice. It does not verify that a device, account, network, or service still enforces it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (var index = 0; index < catalogue.length; index++) ...[
                      _GuardCard(
                        definition: catalogue[index],
                        selection: _selectionFor(value, catalogue[index].id),
                        onReview: () => _openEditor(
                          context,
                          ref,
                          definition: catalogue[index],
                          selection: _selectionFor(value, catalogue[index].id),
                        ),
                        onRemove: (selection) =>
                            _remove(context, ref, selection),
                      ),
                      if (index != catalogue.length - 1)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required GuardDefinition definition,
    required GoalGuardSelection? selection,
  }) async {
    final note = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _GuardEditor(
        goalId: goal.id,
        definition: definition,
        configured: selection != null,
        initialNote: selection?.privateNote,
      ),
    );
    if (note == null || !context.mounted) return;

    try {
      final repository = await ref.read(
        guardSelectionRepositoryProvider.future,
      );
      await repository.select(
        goalId: goal.id,
        definition: definition,
        privateNote: note.isEmpty ? null : note,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This wall could not be saved just now.')),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    GoalGuardSelection selection,
  ) async {
    try {
      final repository = await ref.read(
        guardSelectionRepositoryProvider.future,
      );
      await repository.archive(selection.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This wall could not be removed just now.'),
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.goalTitle});

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
              Text(
                'Close the door',
                style: Theme.of(context).textTheme.titleLarge,
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
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _GuardCard extends StatelessWidget {
  const _GuardCard({
    required this.definition,
    required this.selection,
    required this.onReview,
    required this.onRemove,
  });

  final GuardDefinition definition;
  final GoalGuardSelection? selection;
  final VoidCallback onReview;
  final ValueChanged<GoalGuardSelection> onRemove;

  @override
  Widget build(BuildContext context) {
    final configured = selection != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(definition.kind), size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(definition.description),
                    ],
                  ),
                ),
              ],
            ),
            if (configured) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Configured in SoulBuddy',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              if (_hasText(selection!.privateNote)) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  selection!.privateNote!.trim(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  onPressed: onReview,
                  child: Text(configured ? 'Review or edit' : 'Review'),
                ),
                if (configured)
                  TextButton(
                    onPressed: () => onRemove(selection!),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardEditor extends StatefulWidget {
  const _GuardEditor({
    required this.goalId,
    required this.definition,
    required this.configured,
    this.initialNote,
  });

  final String goalId;
  final GuardDefinition definition;
  final bool configured;
  final String? initialNote;

  @override
  State<_GuardEditor> createState() => _GuardEditorState();
}

class _GuardEditorState extends State<_GuardEditor> {
  bool _recordingBusy = false;
  late final _note = TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.definition.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.definition.description),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Review the steps',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (
              var index = 0;
              index < widget.definition.steps.length;
              index++
            ) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 28, child: Text('${index + 1}.')),
                  Expanded(child: Text(widget.definition.steps[index])),
                ],
              ),
              if (index != widget.definition.steps.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.lg),
            VoiceNotesField(
              key: const Key('guard-private-recording'),
              noteContext: (
                type: 'goal',
                id: widget.goalId,
                field: 'guard:${widget.definition.id}',
              ),
              title: 'Private guard notes',
              onBusyChanged: (busy) => setState(() => _recordingBusy = busy),
            ),
            ExpansionTile(
              title: Text(
                _hasText(widget.initialNote) ? 'Earlier note' : 'Write note',
              ),
              children: [
                SayableField(
                  controller: _note,
                  enabled: !_recordingBusy,
                  labelText: 'Private note',
                  maxLines: 4,
                  maxLength: 4000,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SoulBuddy does not verify enforcement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('guard-mark-configured'),
              onPressed: _recordingBusy
                  ? null
                  : () => Navigator.pop(context, _note.text.trim()),
              child: Text(widget.configured ? 'Save' : 'Mark configured'),
            ),
            TextButton(
              onPressed: _recordingBusy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your configured walls could not be opened just now.'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

/// Shown when the field's limit cut a dictated note short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.

GoalGuardSelection? _selectionFor(
  List<GoalGuardSelection> selections,
  String definitionId,
) {
  for (final selection in selections) {
    if (selection.guardDefinitionId == definitionId) return selection;
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

IconData _iconFor(GuardKind kind) => switch (kind) {
  GuardKind.contentFilter => Icons.filter_alt_outlined,
  GuardKind.osRestriction => Icons.admin_panel_settings_outlined,
  GuardKind.appOrAccountRemoval => Icons.phonelink_erase_outlined,
  GuardKind.physicalBoundary => Icons.directions_walk_outlined,
  GuardKind.paymentFriction => Icons.credit_card_off_outlined,
  GuardKind.trustedPersonControl => Icons.person_outline,
};
