import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) => InlineAudioCapture(
    label: 'Record reflection',
    onBusyChanged: widget.onBusyChanged,
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
  );
}
