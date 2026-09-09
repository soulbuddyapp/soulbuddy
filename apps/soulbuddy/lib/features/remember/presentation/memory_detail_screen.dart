import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/providers/encounter_providers.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  const MemoryDetailScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _updatingAltar = false;
  bool _archiving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                TextField(
                  key: const Key('memory-reflection-body'),
                  controller: _controller,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Add what you understand now',
                    alignLabelWithHint: true,
                  ),
                ),
                FilledButton(
                  key: const Key('memory-save-reflection'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save reflection'),
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
                        Text(reflection.body),
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

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await repository.addReflection(
        widget.memoryId,
        body: body,
        localDate: date,
      );
      ref.invalidate(memoryReflectionsProvider(widget.memoryId));
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this reflection just now.'),
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
