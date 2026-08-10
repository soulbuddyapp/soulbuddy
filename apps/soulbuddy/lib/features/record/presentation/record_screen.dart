import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/feature_page.dart';
import '../data/encounter_repository.dart';
import '../domain/encounter_draft.dart';
import '../providers/encounter_providers.dart';
import 'encounter_form.dart';

enum _RecordView { choices, encounter, saved }

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  var _view = _RecordView.choices;

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming in the next milestone')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(encounterRepositoryProvider);

    return switch (_view) {
      _RecordView.encounter => repository.when(
        data: (value) => EncounterForm(
          onCancel: () => setState(() => _view = _RecordView.choices),
          onSave: (draft) => _saveEncounter(value, draft),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _RecordUnavailable(
          onRetry: () => ref.invalidate(encounterRepositoryProvider),
        ),
      ),
      _RecordView.saved => FeaturePage(
        title: 'Encounter saved',
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
              onPressed: () => setState(() => _view = _RecordView.encounter),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'Lesson',
              icon: Icons.lightbulb_outline,
              onPressed: _showComingSoon,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'Commitment',
              icon: Icons.check_circle_outline,
              onPressed: _showComingSoon,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordChoice(
              label: 'Prayer',
              icon: Icons.menu_book_outlined,
              onPressed: _showComingSoon,
            ),
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
    if (mounted) setState(() => _view = _RecordView.saved);
  }
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
    return SizedBox(
      key: Key('record-choice-${label.toLowerCase()}'),
      height: 52,
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
