import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/persistent_storage.dart';
import '../../persons/providers/person_providers.dart';
import '../audio/data/memory_audio_repository.dart';
import '../audio/data/memory_soundscape_preferences.dart';
import '../audio/domain/memory_audio.dart';
import '../audio/domain/memory_soundscape.dart';
import '../audio/presentation/inline_audio_capture.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../domain/encounter.dart';
import '../domain/encounter_draft.dart';
import '../providers/encounter_providers.dart';

/// Captures a memory without leaving the current context.
class InlineMemoryRecorder extends ConsumerStatefulWidget {
  const InlineMemoryRecorder({
    this.label = 'Record',
    this.onBusyChanged,
    this.enabled = true,
    this.buttonKey,
    this.initialTitle,
    this.initialDate,
    this.initialPersonIds = const [],
    this.privateReflection = false,
    this.beforeStart,
    this.autoStart = false,
    this.enableSoundscape = true,
    super.key,
  });
  final String label;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled;
  final Key? buttonKey;
  final String? initialTitle;
  final DateTime? initialDate;
  final List<String> initialPersonIds;
  final bool privateReflection;
  final Future<void> Function()? beforeStart;
  final bool autoStart;
  final bool enableSoundscape;

  @override
  ConsumerState<InlineMemoryRecorder> createState() =>
      _InlineMemoryRecorderState();
}

class _InlineMemoryRecorderState extends ConsumerState<InlineMemoryRecorder> {
  final _title = TextEditingController();
  final _personIds = <String>{};
  DateTime _date = DateTime.now();
  MemoryType _type = MemoryType.encounter;
  bool _sensitive = false;
  bool _recall = true;
  bool _altar = false;
  bool _saving = false;
  bool _detailsOpen = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _personIds.addAll(widget.initialPersonIds);
    _type = _personIds.isEmpty ? MemoryType.encounter : MemoryType.person;
    _sensitive = widget.privateReflection;
    _recall = !widget.privateReflection;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save(RecordedAudioDraft audio) async {
    setState(() => _saving = true);
    try {
      final audioRepository = audio.soundscape == MemorySoundscape.quiet
          ? null
          : ref.read(memoryAudioRepositoryProvider.future);
      final soundPreferences = audioRepository == null
          ? null
          : ref.read(memorySoundscapePreferencesProvider);
      final repository = await ref.read(encounterRepositoryProvider.future);
      final saved = await repository.create(
        EncounterDraft(
          title: _title.text.trim().isEmpty
              ? String.fromCharCodes(
                  (widget.initialTitle ?? 'Voice memory · $_dateLabel').runes
                      .take(120),
                )
              : _title.text.trim(),
          body: '',
          occurredOn: _dateLabel,
          isAltar: _altar,
          memoryType: _type,
          sensitive: _sensitive,
          recallEnabled: _recall,
          personIds: _personIds.toList(growable: false),
          audio: audio,
        ),
      );
      unawaited(requestPersistentStorage());
      if (audioRepository != null && soundPreferences != null) {
        unawaited(
          _saveSoundscape(saved.id, audio, audioRepository, soundPreferences),
        );
      }
      if (!mounted) return;
      ref.invalidate(encountersProvider);
      _title.clear();
      _personIds
        ..clear()
        ..addAll(widget.initialPersonIds);
      _date = widget.initialDate ?? DateTime.now();
      _type = _personIds.isEmpty ? MemoryType.encounter : MemoryType.person;
      _sensitive = widget.privateReflection;
      _recall = !widget.privateReflection;
      _altar = false;
      _detailsOpen = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recording saved'),
          action: SnackBarAction(
            label: 'Listen',
            onPressed: () => context.go('/remember/${saved.id}'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSoundscape(
    String encounterId,
    RecordedAudioDraft audio,
    Future<MemoryAudioRepository> repositoryFuture,
    MemorySoundscapePreferences preferences,
  ) async {
    try {
      final savedAudio = await (await repositoryFuture)
          .watchForEncounter(encounterId)
          .first;
      if (savedAudio == null) return;
      await preferences.save(
        savedAudio.id,
        MemorySoundscapeSettings(
          soundscape: audio.soundscape,
          volume: audio.soundscapeVolume,
        ),
      );
      if (mounted) {
        ref.invalidate(memorySoundscapeSettingsProvider(savedAudio.id));
      }
    } catch (_) {
      // The recording remains saved if its optional sound preference fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _detailsOpen ? ref.watch(prayerPeopleProvider).value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineAudioCapture(
          buttonKey: widget.buttonKey,
          label: widget.label,
          enabled: widget.enabled && !_saving,
          enableSoundscape: widget.enableSoundscape,
          beforeStart: widget.beforeStart,
          autoStart: widget.autoStart,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _active = busy);
            widget.onBusyChanged?.call(busy);
          },
          onSave: _save,
        ),
        if (_active)
          ExpansionTile(
            title: const Text('Details'),
            onExpansionChanged: (open) => setState(() => _detailsOpen = open),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _title,
                maxLength: 120,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Title · optional',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in MemoryType.values)
                    ChoiceChip(
                      label: Text(_typeLabel(type)),
                      selected: _type == type,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                              _type = type;
                              if (type == MemoryType.leftBehind) {
                                _sensitive = true;
                              }
                            }),
                    ),
                ],
              ),
              SwitchListTile(
                title: const Text('Sensitive'),
                value: _sensitive,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _sensitive = value),
              ),
              SwitchListTile(
                title: const Text('Daily remembrance'),
                value: _recall,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _recall = value),
              ),
              if (people != null && people.isNotEmpty) ...[
                Text('People', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final person in people)
                      FilterChip(
                        label: Text(person.name),
                        selected: _personIds.contains(person.id),
                        onSelected: _saving
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
              ListTile(
                title: const Text('Date'),
                subtitle: Text(_dateLabel),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _saving
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null && mounted) {
                          setState(() => _date = selected);
                        }
                      },
              ),
              SwitchListTile(
                title: const Text('Keep on Altar'),
                value: _altar,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _altar = value),
              ),
            ],
          ),
      ],
    );
  }
}

String _typeLabel(MemoryType type) => switch (type) {
  MemoryType.leftBehind => 'Left behind',
  _ => '${type.name[0].toUpperCase()}${type.name.substring(1)}',
};
