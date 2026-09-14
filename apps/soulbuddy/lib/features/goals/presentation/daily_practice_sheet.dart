import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  late SpiritualPrecept _precept = widget.initial;
  late final TextEditingController _action = TextEditingController(
    text: widget.suggestedAction ?? _precept.suggestions.first,
  );
  String? _goalId;
  bool _daily = false;
  bool _saving = false;
  String? _error;

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
    return SizedBox(
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
                  onPressed: () => Navigator.pop(context),
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
                        onChanged: _saving
                            ? null
                            : (done) => _mark(item, done == true, day),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(
                    Uri(
                      path: '/remember/capture',
                      queryParameters: {
                        'mode': 'reflection',
                        'source': 'daily-scripture',
                        'title': 'Evening reflection',
                        'prompt': _precept.reflection,
                      },
                    ).toString(),
                  );
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Reflect'),
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
                    onSelected: _saving
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
                onTap: _saving
                    ? null
                    : () => setState(() => _action.text = suggestion),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _action,
              enabled: !_saving,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'My commitment',
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
              onChanged: _saving
                  ? null
                  : (value) =>
                        setState(() => _goalId = value == '' ? null : value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeat daily'),
              value: _daily,
              onChanged: _saving
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
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Commit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mark(GoalActionOccurrence item, bool done, DateTime day) async {
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
    if (_action.text.trim().isEmpty) {
      setState(() => _error = 'Name one manageable action.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(dailyFaithfulnessProvider.future);
      await service.save(
        precept: _precept,
        body: _action.text,
        localDate: DateTime.now(),
        goalId: _goalId,
        repeatDaily: _daily,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commitment saved.')));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Commitment could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
