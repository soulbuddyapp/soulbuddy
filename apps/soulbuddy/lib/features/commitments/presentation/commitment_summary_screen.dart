import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/presentation/sanctuary_backdrop.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../record/providers/voice_note_providers.dart';
import '../domain/commitment.dart';
import '../providers/commitment_providers.dart';
import '../providers/commitment_reminder_providers.dart';
import 'commitment_journey_screen.dart';

class CommitmentGoalsEntryCard extends ConsumerWidget {
  const CommitmentGoalsEntryCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(commitmentEntryProvider);
    return entry.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => ListTile(
        title: const Text('My commitment'),
        trailing: IconButton(
          tooltip: 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(commitmentEntryProvider),
        ),
      ),
      data: (value) => Card(
        child: ListTile(
          leading: const Icon(Icons.spa_outlined),
          title: Text(switch (value) {
            CommitmentEntry.begin => 'Begin your commitment',
            CommitmentEntry.continueJourney => 'Continue your commitment',
            CommitmentEntry.viewCommitment => 'View commitment',
          }),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final primary = ref.read(primaryCommitmentProvider).value;
            context.push(
              primary == null
                  ? '/welcome/commitment'
                  : '/commitments/${primary.id}',
            );
          },
        ),
      ),
    );
  }
}

class CommitmentSummaryScreen extends ConsumerStatefulWidget {
  const CommitmentSummaryScreen({required this.commitmentId, super.key});
  final String commitmentId;
  @override
  ConsumerState<CommitmentSummaryScreen> createState() =>
      _CommitmentSummaryScreenState();
}

class _CommitmentSummaryScreenState
    extends ConsumerState<CommitmentSummaryScreen> {
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    // This also settles recovery after a process died following the transaction.
    unawaited(_recover());
  }

  Future<void> _recover() async {
    try {
      final recovery = await ref.read(
        commitmentRecoveryRepositoryProvider.future,
      );
      if (await recovery.resolve() != widget.commitmentId) return;
      await (await ref.read(voiceNoteRepositoryProvider.future)).move(
        type: 'commitment',
        fromId: 'journey:primary',
        toId: widget.commitmentId,
      );
      final identity = await ref.read(localIdentityProvider.future);
      final local = await (await ref.read(
        commitmentReminderDeviceRepositoryProvider.future,
      )).load(widget.commitmentId, identity.deviceId);
      final coordinator = await ref.read(
        commitmentReminderCoordinatorProvider.future,
      );
      if (local != null && local.mode != CommitmentReminderMode.off) {
        final permitted = await coordinator.enableOnThisDevice(
          widget.commitmentId,
          local.mode,
        );
        if (!permitted && mounted) {
          setState(
            () => _error =
                'Notifications are disabled. Your meditation schedule is saved.',
          );
        }
      }
      await recovery.acknowledge(widget.commitmentId);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Reminder unavailable. Your commitment is saved.',
        );
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Changes could not be saved. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTitle(
    String title,
    String initial,
    Future<void> Function(String) save,
  ) async {
    final controller = TextEditingController(text: initial);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 1,
            maxLength: 120,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text != null && mounted) await _run(() => save(text));
  }

  Future<void> _schedule(CommitmentDetails d) async {
    final plan = d.plan;
    if (plan == null) return;
    final identity = await ref.read(localIdentityProvider.future);
    if (!mounted) return;
    final local = await (await ref.read(
      commitmentReminderDeviceRepositoryProvider.future,
    )).load(widget.commitmentId, identity.deviceId);
    if (!mounted) return;
    var progress = CommitmentJourneyProgress(
      frequency: plan.frequency,
      weekdaysMask: plan.weekdaysMask,
      localTime: plan.localTime,
      timezone: plan.timezone,
      durationMinutes: plan.durationMinutes,
      reminderMode: local?.mode ?? CommitmentReminderMode.off,
      guideId: d.commitment.guideId,
    );
    final result = await showModalBottomSheet<CommitmentJourneyProgress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Meditation schedule',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommitmentGuideId.values
                    .map(
                      (guide) => ChoiceChip(
                        label: Text(commitmentGuideLabel(guide)),
                        selected: progress.guideId == guide,
                        onSelected: (_) => update(
                          () => progress = progress.copyWith(guideId: guide),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              CommitmentScheduleFields(
                progress: progress,
                onChanged: (v) => update(() => progress = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  try {
                    validateCommitmentPlan(
                      frequency: progress.frequency!,
                      weekdaysMask: progress.weekdaysMask,
                      localTime: progress.localTime!,
                      timezone: progress.timezone!,
                      durationMinutes: progress.durationMinutes!,
                    );
                    Navigator.pop(ctx, progress);
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Choose at least one day.')),
                    );
                  }
                },
                child: const Text('Save schedule'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final repository = await ref.read(commitmentRepositoryProvider.future);
      await repository.savePlan(
        CommitmentMeditationPlanDraft(
          commitmentId: widget.commitmentId,
          frequency: result.frequency!,
          weekdaysMask: result.weekdaysMask,
          localTime: result.localTime!,
          timezone: result.timezone!,
          durationMinutes: result.durationMinutes!,
          enabled: true,
        ),
      );
      await repository.updateGuide(widget.commitmentId, result.guideId!);
      if (!mounted) return;
      final coordinator = await ref.read(
        commitmentReminderCoordinatorProvider.future,
      );
      final permitted = await coordinator.enableOnThisDevice(
        widget.commitmentId,
        result.reminderMode!,
      );
      if (!permitted && mounted) {
        setState(
          () => _error =
              'Notifications are disabled. Your meditation schedule is saved.',
        );
      }
    });
  }

  bool _reviewDue(CommitmentPreparationCycle cycle) {
    final now = tz.TZDateTime.now(tz.getLocation(cycle.startTimezone));
    return commitmentLocalDate(now).compareTo(cycle.reviewLocalDate) >= 0;
  }

  Future<void> _setCycle(
    CommitmentPreparationCycle cycle,
    CommitmentPreparationCycleState state,
  ) => _run(() async {
    await (await ref.read(
      commitmentRepositoryProvider.future,
    )).savePreparationCycle(
      CommitmentPreparationCycleDraft(
        commitmentId: widget.commitmentId,
        startedAtUtc: cycle.startedAtUtc,
        startedLocalDate: cycle.startedLocalDate,
        startTimezone: cycle.startTimezone,
        reviewLocalDate: cycle.reviewLocalDate,
        state: state,
      ),
    );
  });
  Widget _details(CommitmentDetails d) {
    final c = d.commitment;
    final cycle = d.preparationCycle;
    final sessions = ref.watch(commitmentSessionsProvider(c.id)).value ?? [];
    final due = cycle != null && _reviewDue(cycle);
    final listening =
        cycle?.state == CommitmentPreparationCycleState.listeningOpened;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/sanctuary/sacred_hour_portal.webp',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -.65),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xDD14261F)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(c.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        _recordedSection('calling', 'Calling', c.calling),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton.icon(
          onPressed: () => context.push('/commitments/${c.id}/meditate'),
          icon: const Icon(Icons.spa_outlined),
          label: const Text('Meditate'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${d.plan?.localTime ?? ''} · ${d.plan?.durationMinutes ?? 10} minutes',
          ),
          subtitle: Text(commitmentGuideLabel(c.guideId)),
          trailing: IconButton(
            tooltip: 'Meditation schedule',
            onPressed: _busy ? null : () => _schedule(d),
            icon: const Icon(Icons.tune),
          ),
        ),
        if (cycle != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    due ? 'A time to reflect' : 'Preparation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${sessions.where((s) => s.sessionKind == CommitmentSessionKind.meditation && s.actualDurationSeconds > 0).map((s) => s.localDate).toSet().length} days of meditation',
                  ),
                  if (!due)
                    Text('Reflection from ${cycle.reviewLocalDate}')
                  else if (!listening &&
                      cycle.state !=
                          CommitmentPreparationCycleState.deferred) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'What has become clearer? What still needs patience?',
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _setCycle(
                                cycle,
                                CommitmentPreparationCycleState.listeningOpened,
                              );
                              if (mounted && _error == null) {
                                context.push('/commitments/${c.id}/listen');
                              }
                            },
                      child: const Text('Listening and discernment'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _setCycle(
                              cycle,
                              CommitmentPreparationCycleState.deferred,
                            ),
                      child: const Text('More time to prepare'),
                    ),
                  ],
                  if (listening ||
                      (due &&
                          cycle.state ==
                              CommitmentPreparationCycleState.deferred))
                    TextButton(
                      onPressed: () =>
                          context.push('/commitments/${c.id}/listen'),
                      child: const Text('Listening and discernment'),
                    ),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('My needs'),
          children: [
            for (var index = 0; index < 3; index++)
              _recordedSection(
                'needs-${index + 1}',
                'Need ${index + 1}',
                [c.keyNeedOne, c.keyNeedTwo, c.keyNeedThree][index],
              ),
          ],
        ),
        ExpansionTile(
          title: const Text('Daily practices'),
          children: [
            for (final p in d.practices)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(_shortLabel(p.body)),
                    trailing:
                        p.body.runes.length > 120 && d.practices.length <= 1
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: 'Practice options',
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editTitle(
                                  'Practice title',
                                  p.body,
                                  (body) async => (await ref.read(
                                    commitmentRepositoryProvider.future,
                                  )).updatePractice(p.id, body: body),
                                );
                              }
                              if (value == 'remove') {
                                await _run(
                                  () async => (await ref.read(
                                    commitmentRepositoryProvider.future,
                                  )).archivePractice(p.id),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              if (p.body.runes.length <= 120)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit title'),
                                ),
                              if (d.practices.length > 1)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                            ],
                          ),
                  ),
                  _recordedSection(
                    'practice:${p.id}',
                    'Practice recording',
                    p.body.runes.length > 120 ? p.body : '',
                  ),
                ],
              ),
          ],
        ),
        if (d.declaration != null)
          ExpansionTile(
            title: const Text('My declaration'),
            children: [
              _recordedSection(
                'declaration',
                'Declaration',
                d.declaration!.body,
              ),
            ],
          ),
        ListTile(
          title: const Text('A word about readiness'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/commitments/${c.id}/readiness'),
        ),
        ListTile(
          title: const Text('Linked goal'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/goals/${c.goalId}'),
        ),
      ],
    );
  }

  Widget _recordedSection(String field, String title, String legacyText) {
    final noteContext = (
      type: 'commitment',
      id: widget.commitmentId,
      field: field,
    );
    final notes = ref.watch(voiceNotesProvider(noteContext));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoiceNotesField(
            noteContext: noteContext,
            title: title,
            enabled: !_busy,
          ),
          if (legacyText.isNotEmpty && (notes.value?.isEmpty ?? true))
            SelectableText(legacyText),
          if (legacyText.runes.length > 120 &&
              (notes.value?.isNotEmpty ?? false))
            ExpansionTile(
              title: const Text('Earlier text'),
              children: [SelectableText(legacyText)],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My commitment'),
      leading: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close),
        onPressed: () => context.go('/goals'),
      ),
    ),
    body: SanctuaryBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ref
                .watch(commitmentDetailsProvider(widget.commitmentId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(
                        commitmentDetailsProvider(widget.commitmentId),
                      ),
                      child: const Text('Retry commitment'),
                    ),
                  ),
                  data: (d) => d == null
                      ? const Center(child: Text('Commitment unavailable.'))
                      : _details(d),
                ),
          ),
        ),
      ),
    ),
  );
}

String _shortLabel(String value) =>
    String.fromCharCodes(value.trim().runes.take(120));
