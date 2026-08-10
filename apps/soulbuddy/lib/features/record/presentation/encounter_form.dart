import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../domain/encounter_draft.dart';

class EncounterForm extends StatefulWidget {
  const EncounterForm({
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final Future<void> Function(EncounterDraft draft) onSave;
  final VoidCallback onCancel;

  @override
  State<EncounterForm> createState() => _EncounterFormState();
}

class _EncounterFormState extends State<EncounterForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late final TextEditingController _dateController;
  var _isAltar = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
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

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        EncounterDraft(
          title: _titleController.text,
          body: _bodyController.text,
          occurredOn: _dateController.text,
          isAltar: _isAltar,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      'Record an encounter',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.outline),
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
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Saving…' : 'Save encounter'),
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

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
