import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../record/presentation/voice_notes_field.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import '../../record/providers/voice_note_providers.dart';
import '../application/daily_faithfulness.dart';
import '../data/goal_repository.dart';
import '../domain/goal_action.dart';
import '../providers/goal_providers.dart';

final dailyFaithfulnessProvider = FutureProvider<DailyFaithfulness>(
  (ref) async =>
      DailyFaithfulness(await ref.watch(goalRepositoryProvider.future)),
);

final dailyPracticeReviewProvider = StreamProvider.autoDispose
    .family<List<GoalActionOccurrence>, DateTime>((ref, day) async* {
      final repository = await ref.watch(goalRepositoryProvider.future);
      yield* repository is GoalDailyActionReader
          ? (repository as GoalDailyActionReader).watchScheduledActions(day)
          : repository.watchDueActions(day);
    });

Future<void> showDailyPracticeSheet(
  BuildContext context, {
  SpiritualPrecept initial = SpiritualPrecept.strengthForToday,
  String? suggestedAction,
  bool evening = false,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => DailyPracticeSheet(
    initial: initial,
    suggestedAction: suggestedAction,
    evening: evening,
  ),
);

class DailyPracticeSheet extends ConsumerStatefulWidget {
  const DailyPracticeSheet({
    this.initial = SpiritualPrecept.strengthForToday,
    this.suggestedAction,
    this.evening = false,
    super.key,
  });
  final SpiritualPrecept initial;
  final String? suggestedAction;
  final bool evening;
  @override
  ConsumerState<DailyPracticeSheet> createState() => _DailyPracticeSheetState();
}

class _DailyPracticeSheetState extends ConsumerState<DailyPracticeSheet> {
  final _recordingDraftId = 'daily-practice:${const Uuid().v4()}';
  late SpiritualPrecept _precept = widget.initial;
  late final TextEditingController _action = TextEditingController(
    text: widget.suggestedAction ?? _precept.suggestions.first,
  );
  String? _goalId;
  bool _daily = false;
  bool _saving = false;
  bool _recordingBusy = false;
  bool _hasRecordings = false;
  GoalAction? _savedAction;
  String? _error;

  bool get _blocked => _saving || _recordingBusy;

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(activeGoalsProvider);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final due = ref.watch(dailyPracticeReviewProvider(day));
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_blocked,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.evening ? 'Evening reflection' : 'Daily practice',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _blocked ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (widget.evening) ...[
                const SizedBox(height: 12),
                Text(_precept.reflection, style: theme.textTheme.bodyLarge),
                due.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      const Text('Daily actions could not be loaded.'),
                  data: (items) => Column(
                    children: [
                      for (final item in items)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.action.body),
                          value:
                              item.latestEventType ==
                              GoalActionEventType.completed,
                          onChanged: _blocked
                              ? null
                              : (done) => _mark(item, done == true, day),
                        ),
                    ],
                  ),
                ),
                InlineMemoryRecorder(
                  label: 'Record reflection',
                  initialTitle: 'Evening reflection',
                  privateReflection: true,
                  enabled: !_blocked,
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _recordingBusy = busy);
                  },
                ),
                const Divider(height: 28),
              ],
              Wrap(
                spacing: 8,
                children: [
                  for (final precept in SpiritualPrecept.values)
                    ChoiceChip(
                      label: Text(precept.title),
                      selected: _precept == precept,
                      onSelected: _blocked || _savedAction != null
                          ? null
                          : (_) => setState(() {
                              _precept = precept;
                              _action.text = precept.suggestions.first;
                              _error = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _precept.teaching,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 16),
              Text(
                _precept.prayer,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              for (final suggestion in _precept.suggestions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _precept == SpiritualPrecept.guardTheGate
                        ? Icons.lock_outline
                        : Icons.spa_outlined,
                  ),
                  title: Text(suggestion),
                  onTap: _blocked || _savedAction != null
                      ? null
                      : () => setState(() => _action.text = suggestion),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _action,
                enabled: !_blocked && _savedAction == null,
                maxLength: 120,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Action · short label',
                  border: OutlineInputBorder(),
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('practice-goal-$_goalId'),
                initialValue: _goalId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Goal'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('New practice goal'),
                  ),
                  for (final goal in goals.value ?? [])
                    DropdownMenuItem(
                      value: goal.id,
                      child: Text(goal.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _blocked || _savedAction != null
                    ? null
                    : (value) =>
                          setState(() => _goalId = value == '' ? null : value),
              ),
              const SizedBox(height: 16),
              VoiceNotesField(
                noteContext: (
                  type: 'goal',
                  id: _recordingDraftId,
                  field: 'practice',
                ),
                title: 'Private practice notes',
                enabled: !_blocked && _savedAction == null,
                onRecorded: (_) => _hasRecordings = true,
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _recordingBusy = busy);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat daily'),
                value: _daily,
                onChanged: _blocked || _savedAction != null
                    ? null
                    : (value) => setState(() => _daily = value),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton.icon(
                onPressed: _blocked ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Commit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mark(GoalActionOccurrence item, bool done, DateTime day) async {
    if (_blocked) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(goalRepositoryProvider.future);
      if (done) {
        await repository.completeAction(item.action.id, localDate: day);
      } else {
        await repository.retractAction(item.action.id, localDate: day);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Progress could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_blocked) return;
    final label = _action.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Name one manageable action.');
      return;
    }
    if (label.runes.length > 120 || label.contains('\n')) {
      setState(
        () => _error = 'Use one short action label, up to 120 characters.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(dailyFaithfulnessProvider.future);
      _savedAction ??= await service.save(
        precept: _precept,
        body: _action.text,
        localDate: DateTime.now(),
        goalId: _goalId,
        repeatDaily: _daily,
      );
      if (_hasRecordings) {
        final notes = await ref.read(voiceNoteRepositoryProvider.future);
        await notes.move(
          type: 'goal',
          fromId: _recordingDraftId,
          toId: _savedAction!.goalId,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commitment saved.')));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _savedAction == null
              ? 'Commitment could not be saved. Try again.'
              : 'Commitment saved. Retry to link your recordings.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
