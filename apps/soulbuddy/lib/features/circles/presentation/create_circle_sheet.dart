import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/app_spacing.dart';
import '../data/circle_directory_repository.dart';
import '../domain/circle.dart';
import '../providers/circle_providers.dart';

class CreateCircleSheet extends ConsumerStatefulWidget {
  const CreateCircleSheet({this.initialCircle, super.key});

  final Circle? initialCircle;

  @override
  ConsumerState<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends ConsumerState<CreateCircleSheet> {
  final _creationKey = const Uuid().v4();
  late final _nameController = TextEditingController(
    text: widget.initialCircle?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.initialCircle?.description ?? '',
  );
  late final _linkController = TextEditingController(
    text: widget.initialCircle?.openUri?.toString() ?? '',
  );
  late CircleCategory _category =
      widget.initialCircle?.category ?? CircleCategory.accountability;
  late CircleVisibility _visibility =
      widget.initialCircle?.visibility ?? CircleVisibility.unlisted;
  late CircleProvider _provider =
      widget.initialCircle?.provider ?? CircleProvider.telegram;
  String? _error;
  var _saving = false;

  bool get _editing => widget.initialCircle != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
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
                _editing ? 'Circle settings' : 'Create a Circle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'SoulBuddy keeps the purpose and settings. Conversation stays in Telegram or WhatsApp.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('circle-name-field'),
                controller: _nameController,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Circle name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('circle-description-field'),
                controller: _descriptionController,
                enabled: !_saving,
                maxLength: 280,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'What are people walking together for?',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<CircleCategory>(
                key: const Key('circle-category-field'),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in CircleCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<CircleVisibility>(
                key: const Key('circle-visibility-field'),
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: [
                  for (final visibility in CircleVisibility.values)
                    DropdownMenuItem(
                      value: visibility,
                      child: Text(visibility.label),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _visibility = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<CircleProvider>(
                segments: [
                  for (final provider in CircleProvider.values)
                    ButtonSegment(
                      value: provider,
                      label: Text(provider.label),
                    ),
                ],
                selected: {_provider},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _provider = selection.single;
                        _error = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('circle-open-url-field'),
                controller: _linkController,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: '${_provider.label} group link',
                  hintText: _provider == CircleProvider.telegram
                      ? 'https://t.me/...'
                      : 'https://chat.whatsapp.com/...',
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('confirm-create-circle'),
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? 'Saving…'
                      : _editing
                      ? 'Save settings'
                      : 'Create Circle',
                ),
              ),
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
    final description = _descriptionController.text.trim();
    final link = Uri.tryParse(_linkController.text.trim());
    if (name.isEmpty || description.isEmpty) {
      setState(() => _error = 'Add a name and purpose for this Circle.');
      return;
    }
    if (link == null || !_provider.allows(link)) {
      setState(
        () => _error = 'Use a valid ${_provider.label} group link.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(circleDirectoryRepositoryProvider.future);
      final Circle circle;
      if (widget.initialCircle case final existing?) {
        circle = await repository.update(
          existing.publicId,
          CircleUpdate(
            name: name,
            category: _category,
            description: description,
            visibility: _visibility,
            provider: _provider,
            openUri: link,
          ),
        );
      } else {
        circle = await repository.create(
          CircleDraft(
            creationKey: _creationKey,
            name: name,
            category: _category,
            description: description,
            visibility: _visibility,
            provider: _provider,
            openUri: link,
          ),
        );
      }
      ref.invalidate(ownedCirclesProvider);
      ref.invalidate(circleDiscoveryProvider);
      ref.invalidate(circleProvider(circle.publicId));
      if (mounted) Navigator.of(context).pop(circle.publicId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this Circle. Check the group link and try again.';
        });
      }
    }
  }
}
