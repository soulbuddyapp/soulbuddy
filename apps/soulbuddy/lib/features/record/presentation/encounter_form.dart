import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../audio/domain/memory_audio.dart';

class EncounterForm extends StatefulWidget {
  const EncounterForm({
    required this.onSave,
    required this.onCancel,
    this.memoryType = MemoryType.encounter,
    this.allowMemoryTypeChoice = false,
    this.initialTitle,
    this.audio,
    super.key,
  });

  final Future<void> Function(EncounterDraft draft) onSave;
  final VoidCallback onCancel;
  final MemoryType memoryType;
  final bool allowMemoryTypeChoice;
  final String? initialTitle;
  final MemoryAudioDraft? audio;

  @override
  State<EncounterForm> createState() => _EncounterFormState();
}

class _EncounterFormState extends State<EncounterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _bodyController = TextEditingController();
  late final TextEditingController _dateController;
  var _isAltar = false;
  var _isSaving = false;
  late var _sensitive = widget.memoryType == MemoryType.leftBehind;
  var _recallEnabled = true;
  late var _memoryType = widget.memoryType;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _dateController = TextEditingController(text: _dateOnly(DateTime.now()));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _dateController.text = _dateOnly(selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        EncounterDraft(
          title: _titleController.text,
          body: _bodyController.text,
          occurredOn: _dateController.text,
          isAltar: _isAltar,
          memoryType: _memoryType,
          sensitive: _sensitive,
          recallEnabled: _recallEnabled,
          audio: widget.audio,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = widget.audio == null
              ? 'The memory could not be saved. Try again.'
              : 'The recording is still here. Try saving again or discard it.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isSaving ? null : widget.onCancel,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Record'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      'Record ${_memoryTypeLabel(_memoryType)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.allowMemoryTypeChoice) ...[
                    Text(
                      'What kind of memory is this?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final type in MemoryType.values)
                          ChoiceChip(
                            label: Text(_memoryTypeChipLabel(type)),
                            selected: _memoryType == type,
                            onSelected: _isSaving
                                ? null
                                : (_) => setState(() {
                                    _memoryType = type;
                                    if (type == MemoryType.leftBehind) {
                                      _sensitive = true;
                                    }
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SwitchListTile(
                    title: const Text('Sensitive'),
                    subtitle: const Text(
                      'Hide the excerpt on the Remember list.',
                    ),
                    value: _sensitive,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _sensitive = value),
                  ),
                  SwitchListTile(
                    title: const Text('Include in daily remembrance'),
                    subtitle: const Text(
                      'SoulBuddy may bring this back for quiet recall.',
                    ),
                    value: _recallEnabled,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _recallEnabled = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const Key('encounter-title'),
                    controller: _titleController,
                    enabled: !_isSaving,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Add a short title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('encounter-body'),
                    controller: _bodyController,
                    enabled: !_isSaving,
                    maxLength: 4000,
                    minLines: 4,
                    maxLines: 10,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What happened? (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('encounter-date'),
                    controller: _dateController,
                    readOnly: true,
                    enabled: !_isSaving,
                    onTap: _chooseDate,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.componentRadius,
                      ),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      title: const Text('Keep this as an Altar'),
                      subtitle: const Text(
                        'Mark an encounter you want to return to and remember.',
                      ),
                      value: _isAltar,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _isAltar = value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_saveError case final error?) ...[
                    Text(error, key: const Key('encounter-save-error')),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _memoryTypeLabel(MemoryType type) => switch (type) {
  MemoryType.encounter => 'an encounter',
  MemoryType.leftBehind => 'What I left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};

String _memoryTypeChipLabel(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'Left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
