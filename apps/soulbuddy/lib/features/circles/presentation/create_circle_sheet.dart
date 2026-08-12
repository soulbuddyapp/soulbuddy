import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../providers/circle_providers.dart';

class CreateCircleSheet extends ConsumerStatefulWidget {
  const CreateCircleSheet({super.key});

  @override
  ConsumerState<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends ConsumerState<CreateCircleSheet> {
  final _nameController = TextEditingController();
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + keyboardInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Name your Circle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose a name for this private space.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('circle-name-field'),
                controller: _nameController,
                enabled: !_saving,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Circle name',
                  hintText: 'Family prayer',
                  errorText: _error,
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _PrivateRecordsNotice(),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('confirm-create-circle'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Creating…' : 'Create private Circle'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for this Circle.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(circleRepositoryProvider.future);
      final circleId = await repository.createCircle(name);
      if (mounted) Navigator.of(context).pop(circleId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not create this Circle. Try again.';
        });
      }
    }
  }
}

class _PrivateRecordsNotice extends StatelessWidget {
  const _PrivateRecordsNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 20, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text('Nothing is shared from your private records.'),
        ),
      ],
    );
  }
}
