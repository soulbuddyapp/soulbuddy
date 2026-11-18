import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../domain/prayer_person.dart';
import '../providers/person_providers.dart';
import 'person_prayer_audio_section.dart';

class PersonEditorScreen extends ConsumerWidget {
  const PersonEditorScreen({super.key, this.personId});

  final String? personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = personId;
    if (id == null) return const _PersonEditor();
    return ref
        .watch(prayerPersonProvider(id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Scaffold(
            body: Center(child: Text('This person could not be opened.')),
          ),
          data: (person) => person == null
              ? const Scaffold(body: Center(child: Text('Person not found.')))
              : _PersonEditor(existing: person),
        );
  }
}

class _PersonEditor extends ConsumerStatefulWidget {
  const _PersonEditor({this.existing});
  final PrayerPerson? existing;

  @override
  ConsumerState<_PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends ConsumerState<_PersonEditor> {
  late final TextEditingController _name;
  late final TextEditingController _relationship;
  late PersonPrayerCadence _cadence;
  late int _weekdaysMask;
  TimeOfDay? _time;
  var _saving = false;
  var _recordPrayer = false;

  @override
  void initState() {
    super.initState();
    final person = widget.existing;
    _name = TextEditingController(text: person?.name);
    _relationship = TextEditingController(text: person?.relationship);
    _cadence = person?.cadence ?? PersonPrayerCadence.daily;
    _weekdaysMask = person?.weekdaysMask ?? 0;
    final parts = person?.localTime?.split(':');
    if (parts?.length == 2) {
      _time = TimeOfDay(
        hour: int.parse(parts![0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Add a person' : 'Edit person'),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextField(
                key: const Key('person-name'),
                controller: _name,
                maxLength: 120,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('person-relationship'),
                controller: _relationship,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Remember them',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<PersonPrayerCadence>(
                segments: const [
                  ButtonSegment(
                    value: PersonPrayerCadence.daily,
                    label: Text('Daily'),
                  ),
                  ButtonSegment(
                    value: PersonPrayerCadence.weekly,
                    label: Text('Weekly'),
                  ),
                  ButtonSegment(
                    value: PersonPrayerCadence.selectedDays,
                    label: Text('Days'),
                  ),
                ],
                selected: {_cadence},
                onSelectionChanged: (value) => setState(() {
                  _cadence = value.single;
                  if (_cadence != PersonPrayerCadence.daily &&
                      _weekdaysMask == 0) {
                    _weekdaysMask = 1 << (DateTime.now().weekday - 1);
                  }
                }),
              ),
              if (_cadence != PersonPrayerCadence.daily) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (var index = 0; index < 7; index++)
                      FilterChip(
                        label: Text(
                          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                        ),
                        selected: _weekdaysMask & (1 << index) != 0,
                        onSelected: (selected) => setState(() {
                          if (_cadence == PersonPrayerCadence.weekly) {
                            _weekdaysMask = 1 << index;
                          } else if (selected) {
                            _weekdaysMask |= 1 << index;
                          } else if (_weekdaysMask != 1 << index) {
                            _weekdaysMask &= ~(1 << index);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('person-prayer-time'),
                onPressed: _pickTime,
                icon: const Icon(Icons.notifications_none),
                label: Text(
                  _time == null
                      ? 'Add prayer time (optional)'
                      : 'Prayer time · ${_time!.format(context)}',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Record a prayer'),
                value: _recordPrayer,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _recordPrayer = value ?? false),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const Key('save-person'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (value != null) setState(() => _time = value);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add their name.')));
      return;
    }
    setState(() => _saving = true);
    PrayerPerson? savedPerson;
    String? reminderNotice;
    final localTime = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    String? timezone;
    if (localTime != null) {
      try {
        timezone = await ref.read(prayerDeviceTimezoneProvider)();
      } catch (_) {
        reminderNotice =
            'Person saved. Check the prayer reminder time on this device.';
      }
    }
    try {
      final repository = await ref.read(personRepositoryProvider.future);
      final draft = PrayerPersonDraft(
        name: name,
        relationship: _relationship.text,
        cadence: _cadence,
        localTime: localTime,
        timezone: timezone,
        weekdaysMask: _weekdaysMask,
      );
      savedPerson = widget.existing == null
          ? await repository.create(draft)
          : await repository.update(widget.existing!.id, draft);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this person yet.')),
        );
      }
      return;
    }

    if (localTime != null) {
      try {
        final allowed = await ref.read(enablePersonPrayerRemindersProvider)();
        if (!allowed) {
          reminderNotice =
              'Person saved. Allow notifications to receive prayer reminders.';
        }
      } catch (_) {
        reminderNotice =
            'Person saved. The prayer reminder could not be scheduled yet.';
      }
    }
    ref.invalidate(prayerPeopleProvider);
    if (mounted && _recordPrayer) {
      await showPersonPrayerRecording(context, savedPerson.id);
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      context.go('/persons/${savedPerson.id}');
      if (reminderNotice case final notice?) {
        messenger.showSnackBar(SnackBar(content: Text(notice)));
      }
    }
  }
}
