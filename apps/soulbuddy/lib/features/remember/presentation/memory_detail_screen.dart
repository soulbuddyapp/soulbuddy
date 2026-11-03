import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/providers/encounter_providers.dart';
import '../../record/presentation/voice_memory_capture.dart';
import 'memory_reflection_content.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  const MemoryDetailScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  String? _pendingAudioEncounterId;
  String? _pendingReflectionMemoryId;
  bool _saving = false;
  bool _updatingAltar = false;
  bool _archiving = false;

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(encountersProvider);
    final reflections = ref.watch(memoryReflectionsProvider(widget.memoryId));
    final audio = ref
        .watch(memoryAudioForEncounterProvider(widget.memoryId))
        .whenOrNull(data: (value) => value);
    return Scaffold(
      appBar: AppBar(title: const Text('Remember')),
      body: memories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('This memory could not be opened.')),
        data: (items) {
          final memory = items
              .where((item) => item.id == widget.memoryId)
              .firstOrNull;
          if (memory == null) {
            return const Center(child: Text('This memory is not available.'));
          }
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  _label(memory.memoryType),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  memory.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(memory.occurredOn),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: SwitchListTile.adaptive(
                    key: const Key('memory-altar-status'),
                    value: memory.isAltar,
                    onChanged: _updatingAltar
                        ? null
                        : (value) => _setAltar(value),
                    secondary: const Icon(Icons.local_fire_department_outlined),
                    title: Text(
                      memory.isAltar ? 'At my Altar' : 'Keep at my Altar',
                    ),
                    subtitle: const Text(
                      'Altar memories stay easy to return to from Today.',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('archive-memory'),
                    onPressed: _archiving ? null : _confirmArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(_archiving ? 'Archiving…' : 'Archive Memory'),
                  ),
                ),
                if (memory.body.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(memory.body),
                ],
                if (audio != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AudioPlaybackControl(audio: audio, allowDelete: true),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'What I understand now',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  key: const Key('memory-save-reflection'),
                  onPressed: _saving ? null : () => _recordReflection(memory),
                  icon: const Icon(Icons.mic_none),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : _pendingAudioEncounterId == null
                        ? 'Record reflection'
                        : 'Save reflection',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                reflections.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Text('Reflections could not be opened.'),
                  data: (items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final reflection in items) ...[
                        Text(
                          reflection.localDate,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        MemoryReflectionContent(reflection: reflection),
                        const Divider(height: AppSpacing.lg),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordReflection(Encounter memory) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      if (!mounted) return;
      var audioId = _pendingAudioEncounterId;
      if (audioId == null) {
        final recorded = await showVoiceMemoryCapture(
          context,
          title: 'Reflection · ${memory.title}',
        );
        if (recorded == null) return;
        audioId = recorded.id;
        _pendingAudioEncounterId = audioId;
        _pendingReflectionMemoryId = memory.id;
      }
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final parentId = _pendingReflectionMemoryId ?? memory.id;
      await repository.addReflection(
        parentId,
        body: '',
        localDate: date,
        audioEncounterId: audioId,
      );
      _pendingAudioEncounterId = null;
      _pendingReflectionMemoryId = null;
      if (mounted) ref.invalidate(memoryReflectionsProvider(parentId));
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAltar(bool value) async {
    setState(() => _updatingAltar = true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      await repository.markAsAltar(widget.memoryId, value: value);
      ref.invalidate(encountersProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The Altar setting could not be changed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAltar = false);
    }
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this Memory?'),
        content: const Text(
          'It will leave your Remember list and daily recall.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Memory'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _archiving = true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      await repository.archive(widget.memoryId);
      ref.invalidate(encountersProvider);
      if (mounted) context.go('/remember');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Memory could not be archived.')),
        );
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }
}

String _label(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'What I left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};
