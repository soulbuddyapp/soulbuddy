import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/domain/encounter.dart';
import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/providers/encounter_providers.dart';
import '../../record/presentation/voice_memory_capture.dart';
import 'memory_reflection_content.dart';
import '../domain/daily_memory.dart';
import '../providers/daily_memory_providers.dart';

class DailyRemembranceScreen extends ConsumerStatefulWidget {
  const DailyRemembranceScreen({required this.localDate, super.key});

  final String localDate;

  @override
  ConsumerState<DailyRemembranceScreen> createState() =>
      _DailyRemembranceScreenState();
}

class _DailyRemembranceScreenState
    extends ConsumerState<DailyRemembranceScreen> {
  String? _pendingAudioEncounterId;
  String? _pendingReflectionMemoryId;
  String? _pendingReflectionDate;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final routeDate = DateTime.tryParse(widget.localDate);
    final daily = routeDate == null
        ? const AsyncValue<DailyMemory?>.data(null)
        : ref.watch(dailyMemoryForDateProvider(routeDate));
    return Scaffold(
      appBar: AppBar(title: const Text('Remember')),
      body: daily.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Today’s remembrance could not be opened.'),
        ),
        data: (value) {
          if (value == null || _dateKey(value.localDate) != widget.localDate) {
            return const Center(
              child: Text('No remembrance is set for today.'),
            );
          }
          return _content(value);
        },
      ),
    );
  }

  Widget _content(DailyMemory daily) {
    final memory = daily.memory;
    final reflections = ref.watch(memoryReflectionsProvider(memory.id));
    final audio = ref
        .watch(memoryAudioForEncounterProvider(memory.id))
        .whenOrNull(data: (value) => value);
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            _prompt(memory.memoryType),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(memory.title, style: Theme.of(context).textTheme.headlineMedium),
          Text('Recorded ${memory.occurredOn}'),
          if (memory.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              memory.body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
          if (audio != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AudioPlaybackControl(
              audio: audio,
              label: 'Listen to this memory',
              playLabel: 'Listen',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          reflections.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Earlier reflections are unavailable.'),
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you have understood',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final item in items.take(3)) ...[
                        Text(item.localDate),
                        MemoryReflectionContent(reflection: item),
                        const Divider(),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                key: const Key('daily-memory-focus-remembered'),
                onPressed: _busy
                    ? null
                    : () => _setStatus(daily, DailyMemoryStatus.remembered),
                child: const Text('Remembered'),
              ),
              FilledButton(
                key: const Key('daily-memory-save-reflection'),
                onPressed: _busy ? null : () => _saveReflection(daily),
                child: Text(
                  _pendingAudioEncounterId == null
                      ? 'Record reflection'
                      : 'Save reflection',
                ),
              ),
              OutlinedButton(
                key: const Key('daily-memory-pray'),
                onPressed: _busy
                    ? null
                    : () => context.go(
                        '/prayers/create?memoryId=${Uri.encodeComponent(memory.id)}',
                      ),
                child: const Text('Pray with this'),
              ),
              TextButton(
                key: const Key('daily-memory-not-today'),
                onPressed: _busy
                    ? null
                    : () => _setStatus(daily, DailyMemoryStatus.postponed),
                child: const Text('Not today'),
              ),
              TextButton(
                key: const Key('daily-memory-another'),
                onPressed: _busy ? null : () => _chooseAnother(daily),
                child: const Text('Choose another'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveReflection(DailyMemory displayed) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      if (!mounted) return;
      var audioId = _pendingAudioEncounterId;
      if (audioId == null) {
        final recorded = await showVoiceMemoryCapture(
          context,
          title: 'Reflection · ${displayed.memory.title}',
          occurredOn: DateTime.tryParse(widget.localDate),
        );
        if (recorded == null) return;
        audioId = recorded.id;
        _pendingAudioEncounterId = audioId;
        _pendingReflectionMemoryId = displayed.memory.id;
        _pendingReflectionDate = widget.localDate;
      }
      final parentId = _pendingReflectionMemoryId ?? displayed.memory.id;
      await repository.addReflection(
        parentId,
        body: '',
        localDate: _pendingReflectionDate ?? widget.localDate,
        audioEncounterId: audioId,
      );
      _pendingAudioEncounterId = null;
      _pendingReflectionMemoryId = null;
      _pendingReflectionDate = null;
      if (mounted) {
        ref.invalidate(memoryReflectionsProvider(parentId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _pendingAudioEncounterId == null
                  ? 'Recording unavailable. Try again.'
                  : 'Recording kept. Try saving the reflection again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(
    DailyMemory displayed,
    DailyMemoryStatus status,
  ) async {
    setState(() => _busy = true);
    try {
      final repository = await ref.read(dailyMemoryRepositoryProvider.future);
      await repository.setStatus(
        displayed.localDate,
        expectedEncounterId: displayed.memory.id,
        status: status,
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseAnother(DailyMemory displayed) async {
    setState(() => _busy = true);
    try {
      final repository = await ref.read(dailyMemoryRepositoryProvider.future);
      await repository.chooseAnother(
        displayed.localDate,
        expectedEncounterId: displayed.memory.id,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _prompt(MemoryType type) => switch (type) {
  MemoryType.promise => 'Remember the promise you made before God.',
  MemoryType.leftBehind => 'Remember what you left behind for God’s love.',
  MemoryType.revelation =>
    'Return to this revelation. What more can you understand?',
  MemoryType.encounter => 'Remember what the Lord has done and shown you.',
  _ => 'Return to what you recorded.',
};

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
