import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../record/domain/encounter.dart';
import '../domain/daily_memory.dart';
import '../providers/daily_memory_providers.dart';

class DailyRemembranceCard extends ConsumerStatefulWidget {
  const DailyRemembranceCard({required this.dailyMemory, super.key});

  final DailyMemory dailyMemory;

  @override
  ConsumerState<DailyRemembranceCard> createState() =>
      _DailyRemembranceCardState();
}

class _DailyRemembranceCardState extends ConsumerState<DailyRemembranceCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final daily = widget.dailyMemory;
    return Card(
      key: const Key('daily-remembrance-card'),
      child: InkWell(
        onTap: _busy
            ? null
            : () =>
                  context.push('/remember/daily/${_dateKey(daily.localDate)}'),
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_edu_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Remember today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _typeLabel(daily.memory.memoryType),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                daily.memory.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const CovenantIncisedDivider(
                key: Key('daily-memory-incised-mark'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (daily.status == DailyMemoryStatus.active)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton(
                      key: const Key('daily-memory-open'),
                      onPressed: _busy
                          ? null
                          : () => context.push(
                              '/remember/daily/${_dateKey(daily.localDate)}',
                            ),
                      child: const Text('Return to this'),
                    ),
                    OutlinedButton(
                      key: const Key('daily-memory-remembered'),
                      onPressed: _busy
                          ? null
                          : () => _setStatus(DailyMemoryStatus.remembered),
                      child: const Text('Remembered'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      daily.status == DailyMemoryStatus.remembered
                          ? 'Remembered today'
                          : 'Set aside for today',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setStatus(DailyMemoryStatus status) async {
    final displayed = widget.dailyMemory;
    final systemReduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(dailyMemoryRepositoryProvider.future);
      await repository.setStatus(
        displayed.localDate,
        expectedEncounterId: displayed.memory.id,
        status: status,
      );
      final preferences =
          ref.read(appFeedbackPreferencesProvider).value ??
          AppFeedbackPreferences.defaults;
      unawaited(
        ref
            .read(appFeedbackServiceProvider)
            .emit(
              AppFeedbackIntent.saved,
              preferences: preferences,
              systemReduceMotion: systemReduceMotion,
            ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this remembrance.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _typeLabel(MemoryType type) => switch (type) {
  MemoryType.promise => 'A promise before God',
  MemoryType.leftBehind => 'What you left behind for God’s love',
  MemoryType.revelation => 'A revelation to understand further',
  MemoryType.encounter => 'An encounter to remember',
  _ => 'A record to remember',
};

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
