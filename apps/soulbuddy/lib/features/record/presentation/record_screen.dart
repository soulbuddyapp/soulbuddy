import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/feature_page.dart';
import '../../../core/storage/persistent_storage.dart';
import '../data/encounter_repository.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../providers/encounter_providers.dart';
import 'encounter_form.dart';

enum _RecordView { choices, form, saved }

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  var _view = _RecordView.choices;
  var _memoryType = MemoryType.encounter;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(encounterRepositoryProvider);

    return switch (_view) {
      _RecordView.form => repository.when(
        data: (value) => EncounterForm(
          memoryType: _memoryType,
          onCancel: () => setState(() => _view = _RecordView.choices),
          onSave: (draft) => _saveEncounter(value, draft),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _RecordUnavailable(
          onRetry: () => ref.invalidate(encounterRepositoryProvider),
        ),
      ),
      _RecordView.saved => FeaturePage(
        title: 'Record saved',
        description: 'It is ready for you in Remember.',
        action: FilledButton(
          onPressed: () => setState(() => _view = _RecordView.choices),
          child: const Text('Record another'),
        ),
      ),
      _RecordView.choices => FeaturePage(
        title: 'Record',
        description: 'Write what happened before it fades.',
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordChoice(
              label: 'Encounter',
              icon: Icons.auto_awesome_outlined,
              onPressed: () => _open(MemoryType.encounter),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'Promise',
              icon: Icons.handshake_outlined,
              onPressed: () => _open(MemoryType.promise),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'What I left behind',
              icon: Icons.arrow_forward_outlined,
              onPressed: () => _open(MemoryType.leftBehind),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'Revelation',
              icon: Icons.lightbulb_outline,
              onPressed: () => _open(MemoryType.revelation),
            ),
            for (final choice in const [
              (MemoryType.scripture, 'Scripture', Icons.menu_book_outlined),
              (MemoryType.person, 'Person', Icons.person_outline),
              (MemoryType.family, 'Family', Icons.family_restroom_outlined),
              (MemoryType.lesson, 'Lesson', Icons.school_outlined),
              (
                MemoryType.testimony,
                'Testimony',
                Icons.record_voice_over_outlined,
              ),
            ]) ...[
              const SizedBox(height: AppSpacing.sm),
              _RecordChoice(
                label: choice.$2,
                icon: choice.$3,
                onPressed: () => _open(choice.$1),
              ),
            ],
          ],
        ),
      ),
    };
  }

  Future<void> _saveEncounter(
    EncounterRepository repository,
    EncounterDraft draft,
  ) async {
    await repository.create(draft);
    unawaited(requestPersistentStorage());
    if (mounted) setState(() => _view = _RecordView.saved);
  }

  void _open(MemoryType type) => setState(() {
    _memoryType = type;
    _view = _RecordView.form;
  });
}

class _RecordChoice extends StatelessWidget {
  const _RecordChoice({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: Key('record-choice-${label.toLowerCase()}'),
      constraints: const BoxConstraints(minHeight: 52),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

class _RecordUnavailable extends StatelessWidget {
  const _RecordUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Record is unavailable',
      description:
          'Your writing is still on this device. Try opening it again.',
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('Try again'),
      ),
    );
  }
}
