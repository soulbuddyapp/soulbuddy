import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/speech/sayable_field.dart';

import '../../record/audio/presentation/inline_audio_capture.dart';
import '../../record/domain/encounter.dart';
import '../../record/domain/encounter_draft.dart';
import '../../record/providers/encounter_providers.dart';

class InlineMemoryReflection extends ConsumerStatefulWidget {
  const InlineMemoryReflection({
    required this.memory,
    required this.localDate,
    this.onBusyChanged,
    super.key,
  });
  final Encounter memory;
  final String localDate;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<InlineMemoryReflection> createState() =>
      _InlineMemoryReflectionState();
}

class _InlineMemoryReflectionState
    extends ConsumerState<InlineMemoryReflection> {
  late String _memoryId;
  late String _date;
  late String _title;
  final _words = TextEditingController();
  bool _saving = false;
  bool _recordingBusy = false;

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      InlineAudioCapture(
        label: 'Record reflection',
        enabled: !_saving,
        onBusyChanged: (busy) {
          if (mounted) setState(() => _recordingBusy = busy);
          widget.onBusyChanged?.call(busy);
        },
        beforeStart: () async {
          _memoryId = widget.memory.id;
          _date = widget.localDate;
          _title = 'Reflection · ${widget.memory.title}';
        },
        onSave: (draft) async {
          final repository = await ref.read(encounterRepositoryProvider.future);
          await repository.create(
            EncounterDraft(
              title: String.fromCharCodes(_title.runes.take(80)),
              body: '',
              occurredOn: _date,
              isAltar: false,
              sensitive: true,
              recallEnabled: false,
              audio: draft,
              reflectionParentId: _memoryId,
            ),
          );
          if (mounted) ref.invalidate(memoryReflectionsProvider(_memoryId));
        },
      ),
      ExpansionTile(
        title: const Text('Write reflection'),
        children: [
          SayableField(
            controller: _words,
            labelText: 'Reflection',
            maxLines: 6,
            maxLength: 4000,
            enabled: !_saving && !_recordingBusy,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _words,
            builder: (context, value, _) => FilledButton(
              onPressed: _saving || _recordingBusy || value.text.trim().isEmpty
                  ? null
                  : _saveWords,
              child: const Text('Save reflection'),
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> _saveWords() async {
    if (_saving || _words.text.trim().isEmpty) return;
    final memoryId = widget.memory.id;
    final date = widget.localDate;
    final body = _words.text.trim();
    setState(() => _saving = true);
    widget.onBusyChanged?.call(true);
    try {
      final repository = await ref.read(encounterRepositoryProvider.future);
      await repository.addReflection(memoryId, body: body, localDate: date);
      if (mounted) {
        ref.invalidate(memoryReflectionsProvider(memoryId));
        _words.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reflection could not be saved. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      if (mounted) widget.onBusyChanged?.call(false);
    }
  }
}
