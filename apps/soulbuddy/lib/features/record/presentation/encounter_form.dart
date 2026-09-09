import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../audio/domain/memory_audio.dart';
import '../audio/application/audio_capture_controller.dart';
import '../audio/presentation/audio_capture_panel.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../../persons/domain/prayer_person.dart';

class EncounterForm extends ConsumerStatefulWidget {
  const EncounterForm({
    required this.onSave,
    required this.onCancel,
    this.memoryType = MemoryType.encounter,
    this.allowMemoryTypeChoice = false,
    this.initialTitle,
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
  late final TextEditingController _bodyController;
  late final TextEditingController _dateController;
  var _isAltar = false;
  var _isSaving = false;
  late var _sensitive =
      widget.initialSensitive || widget.memoryType == MemoryType.leftBehind;
  late var _recallEnabled = widget.initialRecallEnabled;
  late var _memoryType = widget.memoryType;
  String? _saveError;
  var _canceling = false;
  late MemoryAudioDraft? _audioDraft = widget.audio;
  late final Set<String> _personIds = widget.initialPersonIds.toSet();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
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
          audio: _audioDraft,
          personIds: _personIds.toList(growable: false),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = _audioDraft == null
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
                    if (widget.bodyPrompt case final prompt?) ...[
                      Card(
                        color: Theme.of(context).colorScheme.secondaryContainer
                            .withValues(alpha: 0.55),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(prompt)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    TextFormField(
                      key: const Key('encounter-body'),
                      controller: _bodyController,
                      enabled: !_isSaving,
                      maxLength: 4000,
                      minLines: 4,
                      maxLines: 10,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText:
                            widget.bodyLabel ?? 'What happened? (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('encounter-add-audio'),
                        onPressed: _isSaving ? null : _recordWhatHappened,
                        icon: Icon(
                          _audioDraft == null ? Icons.mic_none : Icons.mic,
                        ),
                        label: Text(
                          _audioDraft == null
                              ? 'Record what happened'
                              : 'Replace voice recording',
                        ),
                      ),
                    ),
                    if (_audioDraft != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Voice recording added',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (widget.people.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Who is this about? (optional)',
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
      ),
    );
  }

  Future<void> _recordWhatHappened() async {
    final keepAlive = ref.listenManual(
      audioCaptureControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    try {
      final controller = await ref.read(audioCaptureControllerProvider.future);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.9,
          child: AudioCapturePanel(
            controller: controller,
            enableSoundscape: true,
            introHeading: 'Record what happened',
            introDescription: 'Speak freely. You can keep writing too.',
            alternativeLabel: 'Keep writing',
            onWriteInstead: () async {
              await _leaveAudioCapture(controller);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            onContinue: (recording) async {
              final previous = _audioDraft;
              if (previous != null) {
                final store = await ref.read(audioAssetStoreProvider.future);
                await store.discardTemporary(previous.temporaryKey);
              }
              if (mounted) setState(() => _audioDraft = recording);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
        ),
      );
    } finally {
      keepAlive.close();
    }
  }

  Future<void> _cancel() async {
    if (_isSaving || _canceling) return;
    _canceling = true;
    final recording = _audioDraft;
    if (recording != null) {
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

  Future<void> _leaveAudioCapture(AudioCaptureController controller) async {
    switch (controller.state.phase) {
      case AudioCapturePhase.review:
        await controller.discard();
        return;
      case AudioCapturePhase.recording ||
          AudioCapturePhase.paused ||
          AudioCapturePhase.failure:
        await controller.cancel();
        return;
      default:
        return;
    }
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
