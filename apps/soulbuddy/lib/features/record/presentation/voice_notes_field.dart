import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/presentation/audio_playback_control.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../data/voice_note_repository.dart';
import '../domain/encounter.dart';
import '../providers/voice_note_providers.dart';
import 'voice_memory_capture.dart';

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
    super.key,
  });
  final VoiceNoteContext noteContext;
  final String title;
  final ValueChanged<Encounter>? onRecorded;
  final ValueChanged<bool>? onBusyChanged;
  final Future<void> Function()? beforeRecord;
  final bool enabled;
  final bool includeAllFields;

  @override
  ConsumerState<VoiceNotesField> createState() => _VoiceNotesFieldState();
}

class _VoiceNotesFieldState extends ConsumerState<VoiceNotesField> {
  Encounter? _pending;
  bool _busy = false;
  String? _error;

  @override
  void didUpdateWidget(covariant VoiceNotesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteContext != widget.noteContext) {
      _pending = null;
      _error = null;
    }
  }

  Future<void> _record() async {
    if (_busy || !widget.enabled) return;
    final noteContext = widget.noteContext;
    final title = widget.title;
    final beforeRecord = widget.beforeRecord;
    final onRecorded = widget.onRecorded;
    final onBusyChanged = widget.onBusyChanged;
    var memory = _pending;
    setState(() {
      _busy = true;
      _error = null;
    });
    onBusyChanged?.call(true);
    try {
      await beforeRecord?.call();
      if (!mounted) return;
      // Capture the owner-scoped repository before opening the recorder as well
      // as the context, so a parent change cannot retarget an in-flight save.
      final repository = await ref.read(voiceNoteRepositoryProvider.future);
      if (!mounted) return;
      memory ??= await showVoiceMemoryCapture(context, title: title);
      if (memory == null) return;
      await repository.attach(noteContext, memory.id);
      if (mounted && widget.noteContext == noteContext) {
        _pending = null;
        onRecorded?.call(memory);
      }
    } catch (_) {
      if (mounted && widget.noteContext == noteContext) {
        setState(() {
          _pending = memory;
          _error = memory == null
              ? 'Recording unavailable'
              : 'Saved in Remember. Retry linking.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.noteContext;
    final notes = ref.watch(voiceNotesProvider(
      widget.includeAllFields ? (type: scope.type, id: scope.id, field: '*') : scope,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        for (final note in notes.value ?? const <VoiceNoteLink>[])
          RecordedMemoryPlayer(encounterId: note.encounterId, title: note.title),
        if (notes.hasError) const Text('Recordings unavailable'),
        if (_error != null) Text(_error!),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy || !widget.enabled ? null : _record,
            icon: const Icon(Icons.mic_none),
            label: Text(_busy ? 'Saving…' : _pending == null ? 'Record' : 'Retry'),
          ),
        ),
      ],
    );
  }
}

class RecordedMemoryPlayer extends ConsumerWidget {
  const RecordedMemoryPlayer({required this.encounterId, required this.title, super.key});
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
