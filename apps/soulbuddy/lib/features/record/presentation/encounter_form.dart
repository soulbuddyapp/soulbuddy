import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../audio/domain/memory_audio.dart';
import '../audio/presentation/inline_audio_capture.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../../persons/domain/prayer_person.dart';

class EncounterForm extends ConsumerStatefulWidget {
  const EncounterForm({
    required this.onSave,
    required this.onCancel,
    this.memoryType = MemoryType.encounter,
    this.allowMemoryTypeChoice = false,
    this.initialTitle,
    this.initialDate,
    this.audio,
    this.people = const [],
    this.initialPersonIds = const [],
    this.bodyLabel,
    this.bodyPrompt,
    this.initialBody,
    this.initialSensitive = false,
    this.initialRecallEnabled = true,
    super.key,
  });

  final Future<void> Function(EncounterDraft draft) onSave;
  final VoidCallback onCancel;
  final MemoryType memoryType;
  final bool allowMemoryTypeChoice;
  final String? initialTitle;
  final DateTime? initialDate;
  final MemoryAudioDraft? audio;
  final List<PrayerPerson> people;
  final List<String> initialPersonIds;
  final String? bodyLabel;
  final String? bodyPrompt;
  final String? initialBody;
  final bool initialSensitive;
  final bool initialRecallEnabled;

  @override
  ConsumerState<EncounterForm> createState() => _EncounterFormState();
}

class _EncounterFormState extends ConsumerState<EncounterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  var _isAltar = false;
  var _isSaving = false;
  late var _sensitive =
      widget.initialSensitive || widget.memoryType == MemoryType.leftBehind;
  late var _recallEnabled = widget.initialRecallEnabled;
  late var _memoryType = widget.memoryType;
  String? _saveError;
  var _canceling = false;
  var _captureBusy = false;
  late MemoryAudioDraft? _audioDraft = widget.audio;
  late final Set<String> _personIds = widget.initialPersonIds.toSet();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: _shortTitle(widget.initialTitle ?? ''),
    );
    final requestedDate = widget.initialDate;
    final date =
        requestedDate != null &&
            requestedDate.year >= 1900 &&
            !requestedDate.isAfter(DateTime.now())
        ? requestedDate
        : DateTime.now();
    _dateController = TextEditingController(text: _dateOnly(date));
  }

  @override
  void dispose() {
    _titleController.dispose();
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
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_audioDraft == null) {
      setState(() => _saveError = 'Record audio first.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        EncounterDraft(
          title: _titleController.text.trim().isEmpty
              ? _defaultTitle
              : _titleController.text.trim(),
          // Older callers may supply text. Preserve it without offering a new
          // long-form editor or inventing a transcript of the recording.
          body: widget.initialBody ?? '',
          occurredOn: _dateController.text,
          isAltar: _isAltar,
          memoryType: _memoryType,
          sensitive: _sensitive,
          recallEnabled: _recallEnabled,
          audio: _audioDraft,
          personIds: _personIds.toList(growable: false),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Recording kept. Try saving again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SafeArea(
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
                        onPressed: _isSaving ? null : _cancel,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Remember'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        'Keep this recording',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (widget.allowMemoryTypeChoice) ...[
                      Text(
                        'Memory type',
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
                      value: _sensitive,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _sensitive = value),
                    ),
                    SwitchListTile(
                      title: const Text('Daily remembrance'),
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
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Title (optional)',
                        hintText: _defaultTitle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InlineAudioCapture(
                      key: const Key('encounter-add-audio'),
                      enableSoundscape: true,
                      saveLabel: 'Use recording',
                      enabled: !_isSaving,
                      label: _audioDraft == null
                          ? 'Record audio'
                          : 'Record again',
                      onBusyChanged: (busy) =>
                          setState(() => _captureBusy = busy),
                      onSave: (recording) async {
                        final previous = _audioDraft;
                        setState(() {
                          _audioDraft = recording;
                          _saveError = null;
                        });
                        if (previous != null) {
                          try {
                            final store = await ref.read(
                              audioAssetStoreProvider.future,
                            );
                            await store.discardTemporary(previous.temporaryKey);
                          } catch (_) {
                            /* Startup cleanup handles older temporary files. */
                          }
                        }
                      },
                    ),
                    if (_audioDraft != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Recording · ${_durationLabel(_audioDraft!.duration)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (widget.people.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'People (optional)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final person in widget.people)
                            FilterChip(
                              label: Text(person.name),
                              selected: _personIds.contains(person.id),
                              onSelected: _isSaving
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected) {
                                        _personIds.add(person.id);
                                      } else {
                                        _personIds.remove(person.id);
                                      }
                                    }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text('Date', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      label: 'Date',
                      child: TextFormField(
                        key: const Key('encounter-date'),
                        controller: _dateController,
                        readOnly: true,
                        enabled: !_isSaving,
                        onTap: _chooseDate,
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
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
                        title: const Text('Keep on Altar'),
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
                      key: const Key('encounter-save'),
                      onPressed:
                          _isSaving || _captureBusy || _audioDraft == null
                          ? null
                          : _save,
                      child: Text(_isSaving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (_isSaving || _canceling || _captureBusy) return;
    _canceling = true;
    final recording = _audioDraft;
    if (recording != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard recording?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) {
        _canceling = false;
        return;
      }
      try {
        final store = await ref.read(audioAssetStoreProvider.future);
        await store.discardTemporary(recording.temporaryKey);
      } catch (_) {
        // Old temporary recordings are also removed by startup cleanup. A
        // cleanup failure should never trap someone in the memory form.
      }
    }
    if (mounted) widget.onCancel();
  }

  String get _defaultTitle {
    final contextTitle = _shortTitle(widget.initialTitle ?? '');
    if (contextTitle.isNotEmpty) return contextTitle;
    final kind = _memoryType == MemoryType.encounter
        ? 'Voice memory'
        : _memoryTypeChipLabel(_memoryType);
    return '$kind · ${_dateController.text}';
  }
}

String _memoryTypeChipLabel(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'Left behind',
  _ => type.name[0].toUpperCase() + type.name.substring(1),
};

String _shortTitle(String value) {
  final title = value.trim();
  return String.fromCharCodes(title.runes.take(120)).trimRight();
}

String _durationLabel(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
