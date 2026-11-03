import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/presentation/audio_playback_control.dart';
import '../audio/presentation/inline_audio_capture.dart';
import '../audio/domain/memory_audio.dart';
import '../domain/encounter_draft.dart';
import '../providers/encounter_providers.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../data/voice_note_repository.dart';
import '../domain/encounter.dart';
import '../providers/voice_note_providers.dart';

/// Replaces a long-form field with context-linked recordings.
class VoiceNotesField extends ConsumerStatefulWidget {
  const VoiceNotesField({
    required this.noteContext,
    required this.title,
    this.onRecorded,
    this.onBusyChanged,
    this.beforeRecord,
    this.enabled = true,
    this.includeAllFields = false,
    this.autoStart = false,
    this.recordLabel = 'Record',
    this.showTitle = true,
    super.key,
  });
  final VoiceNoteContext noteContext;
  final String title;
  final ValueChanged<Encounter>? onRecorded;
  final ValueChanged<bool>? onBusyChanged;
  final Future<void> Function()? beforeRecord;
  final bool enabled;
  final bool includeAllFields;
  final bool autoStart;
  final String recordLabel;
  final bool showTitle;

  @override
  ConsumerState<VoiceNotesField> createState() => _VoiceNotesFieldState();
}

class _VoiceNotesFieldState extends ConsumerState<VoiceNotesField> {
  String? _error;

  @override
  void didUpdateWidget(covariant VoiceNotesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteContext != widget.noteContext) {
      _error = null;
    }
  }

  VoiceNoteContext? _captureContext;
  ValueChanged<Encounter>? _captureCallback;
  String? _captureTitle;

  Future<void> _prepare() async {
    final scope = widget.noteContext;
    _captureContext = scope;
    _captureCallback = widget.onRecorded;
    _captureTitle = widget.title;
    await widget.beforeRecord?.call();
    if (!mounted || widget.noteContext != scope) {
      throw StateError('Recording context changed');
    }
  }

  Future<void> _save(RecordedAudioDraft draft) async {
    final scope = _captureContext;
    if (scope == null) throw StateError('Missing recording context');
    final repository = await ref.read(encounterRepositoryProvider.future);
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final memory = await repository.create(
      EncounterDraft(
        title: String.fromCharCodes(_captureTitle!.runes.take(120)),
        body: '',
        occurredOn: date,
        isAltar: false,
        sensitive: true,
        recallEnabled: false,
        audio: draft,
        voiceNoteContext: scope,
      ),
    );
    if (mounted && widget.noteContext == scope) _captureCallback?.call(memory);
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.noteContext;
    final busyChanged = widget.onBusyChanged;
    final notes = ref.watch(
      voiceNotesProvider(
        widget.includeAllFields
            ? (type: scope.type, id: scope.id, field: '*')
            : scope,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle)
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        for (final note in notes.value ?? const <VoiceNoteLink>[])
          RecordedMemoryPlayer(
            encounterId: note.encounterId,
            title: note.title,
          ),
        if (notes.hasError) const Text('Recordings unavailable'),
        if (_error != null) Text(_error!),
        InlineAudioCapture(
          contextIdentity: scope,
          autoStart: widget.autoStart,
          beforeStart: _prepare,
          onSave: _save,
          onBusyChanged: busyChanged,
          enabled: widget.enabled,
          label: widget.recordLabel,
        ),
      ],
    );
  }
}

class RecordedMemoryPlayer extends ConsumerWidget {
  const RecordedMemoryPlayer({
    required this.encounterId,
    required this.title,
    super.key,
  });
  final String encounterId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(memoryAudioForEncounterProvider(encounterId));
    return audio.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Recording unavailable'),
      data: (value) => value == null
          ? const Text('Recording unavailable on this device')
          : AudioPlaybackControl(
              audio: value,
              compact: true,
              label: title,
              sessionRoute: '/remember/$encounterId',
            ),
    );
  }
}
