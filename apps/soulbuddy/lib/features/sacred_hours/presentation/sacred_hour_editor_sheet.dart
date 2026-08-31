import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../persons/domain/prayer_person.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../application/sacred_hour_sound_player.dart';
import '../domain/sacred_hour.dart';
import 'sacred_hour_sound_picker.dart';

class SacredHourEditorValue {
  const SacredHourEditorValue({
    required this.name,
    required this.localTime,
    required this.prayerMinutes,
    required this.sound,
    required this.reminderMode,
    this.prayer,
    this.personId,
  });

  final String name;
  final PrayerLocalTime localTime;
  final int prayerMinutes;
  final SacredHourSound sound;
  final SacredHourReminderMode reminderMode;
  final PrayerReference? prayer;
  final String? personId;
}

class SacredHourEditorSheet extends StatefulWidget {
  const SacredHourEditorSheet({
    required this.timezone,
    required this.existingHours,
    required this.prayers,
    required this.people,
    required this.soundsEnabled,
    required this.player,
    required this.reminderMode,
    required this.onSave,
    this.onRequestPrecise,
    this.hour,
    super.key,
  });

  final SacredHour? hour;
  final String timezone;
  final List<SacredHour> existingHours;
  final List<PrayerDisplay> prayers;
  final List<PrayerPerson> people;
  final bool soundsEnabled;
  final SacredHourSoundPlayer player;
  final SacredHourReminderMode reminderMode;
  final Future<void> Function(SacredHourEditorValue value) onSave;
  final Future<bool> Function()? onRequestPrecise;

  @override
  State<SacredHourEditorSheet> createState() => _SacredHourEditorSheetState();
}

class _SacredHourEditorSheetState extends State<SacredHourEditorSheet> {
  late final TextEditingController _nameController;
  late PrayerLocalTime _localTime;
  late int _prayerMinutes;
  late SacredHourSound _sound;
  late SacredHourReminderMode _reminderMode;
  PrayerReference? _prayer;
  String? _personId;
  bool _confirmOverlap = false;
  bool _saving = false;
  bool _requestingPrecise = false;
  bool? _preciseAllowed;

  @override
  void initState() {
    super.initState();
    final hour = widget.hour;
    _nameController = TextEditingController(text: hour?.name ?? 'Sacred Hour');
    _localTime = hour?.localTime ?? PrayerLocalTime(hour: 6, minute: 0);
    _prayerMinutes = hour?.prayerMinutes ?? 15;
    _sound = hour?.sound ?? SacredHourSound.gentleChime;
    _reminderMode = widget.reminderMode;
    _prayer = hour?.prayer;
    _personId = hour?.personId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    widget.player.stop();
    widget.player.dispose();
    super.dispose();
  }

  Future<void> _changeTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _localTime.hour, minute: _localTime.minute),
      helpText: 'Sacred Hour start',
    );
    if (value != null && mounted) {
      setState(() {
        _localTime = PrayerLocalTime(hour: value.hour, minute: value.minute);
        _confirmOverlap = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_overlapsAnother() && !_confirmOverlap) {
      setState(() => _confirmOverlap = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        SacredHourEditorValue(
          name: name,
          localTime: _localTime,
          prayerMinutes: _prayerMinutes,
          sound: _sound,
          reminderMode: _reminderMode,
          prayer: _prayer,
          personId: _personId,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _overlapsAnother() {
    final start = _localTime.hour * 60 + _localTime.minute;
    for (final other in widget.existingHours) {
      if (other.id == widget.hour?.id) continue;
      final otherStart = other.localTime.hour * 60 + other.localTime.minute;
      final distance = (start - otherStart).abs();
      final circularDistance = distance > 720 ? 1440 - distance : distance;
      if (circularDistance < 60) return true;
    }
    return false;
  }

  Future<void> _requestPrecise() async {
    final request = widget.onRequestPrecise;
    if (request == null || _requestingPrecise) return;
    setState(() => _requestingPrecise = true);
    final allowed = await request();
    if (!mounted) return;
    setState(() {
      _requestingPrecise = false;
      _preciseAllowed = allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.hour == null ? 'Add Sacred Hour' : 'Edit Sacred Hour',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              if (Navigator.maybeOf(context)?.canPop() ?? false)
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            subtitle: Text('${_formatTime(_localTime)} · one hour'),
            trailing: TextButton(
              key: const Key('editor-time-change'),
              onPressed: _changeTime,
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Prayer opening', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<int>(
            segments: [
              for (final minutes in const [5, 15, 30])
                ButtonSegment<int>(
                  value: minutes,
                  label: Text('$minutes min'),
                  icon: SizedBox(key: Key('editor-prayer-$minutes')),
                ),
            ],
            selected: {_prayerMinutes},
            onSelectionChanged: (values) =>
                setState(() => _prayerMinutes = values.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _prayer == null ? 'none' : _prayerKey(_prayer!),
            decoration: const InputDecoration(labelText: 'Prayer (optional)'),
            items: [
              const DropdownMenuItem(value: 'none', child: Text('None')),
              for (final prayer in widget.prayers)
                DropdownMenuItem(
                  value: _prayerKey(prayer.reference),
                  child: Text(prayer.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() {
              _prayer = value == null || value == 'none'
                  ? null
                  : _parsePrayerKey(value);
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _personId ?? 'none',
            decoration: const InputDecoration(labelText: 'Person (optional)'),
            items: [
              const DropdownMenuItem(value: 'none', child: Text('None')),
              for (final person in widget.people)
                DropdownMenuItem(
                  value: person.id,
                  child: Text(person.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(
              () => _personId = value == null || value == 'none' ? null : value,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SacredHourSoundPicker(
            selected: _sound,
            soundsEnabled: widget.soundsEnabled,
            player: widget.player,
            onChanged: (value) => setState(() => _sound = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Reminder timing', style: theme.textTheme.titleMedium),
          RadioGroup<SacredHourReminderMode>(
            groupValue: _reminderMode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _reminderMode = value);
              if (value == SacredHourReminderMode.precise) {
                _requestPrecise();
              }
            },
            child: const Column(
              children: [
                RadioListTile<SacredHourReminderMode>(
                  value: SacredHourReminderMode.ordinary,
                  title: Text('Ordinary'),
                  subtitle: Text('Recommended for most phones'),
                ),
                RadioListTile<SacredHourReminderMode>(
                  value: SacredHourReminderMode.precise,
                  title: Text('More precise timing'),
                  subtitle: Text(
                    'Android may ask for Alarms & reminders access',
                  ),
                ),
              ],
            ),
          ),
          if (_reminderMode == SacredHourReminderMode.precise &&
              _preciseAllowed == false)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Using an ordinary reminder until access is allowed.',
                  ),
                ),
                TextButton(
                  onPressed: _requestingPrecise ? null : _requestPrecise,
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (_confirmOverlap) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This overlaps another Sacred Hour. Save again to keep both.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('sacred-hour-save'),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : _confirmOverlap
                  ? 'Save both hours'
                  : 'Save Sacred Hour',
            ),
          ),
        ],
      ),
    );
  }
}

String _prayerKey(PrayerReference reference) =>
    '${reference.source.name}:${reference.id}';

PrayerReference _parsePrayerKey(String key) {
  final separator = key.indexOf(':');
  final source = key.substring(0, separator);
  final id = key.substring(separator + 1);
  return source == PrayerSource.personal.name
      ? PrayerReference.personal(id)
      : PrayerReference.library(id);
}

String _formatTime(PrayerLocalTime time) {
  final hour = time.hour == 0
      ? 12
      : time.hour > 12
      ? time.hour - 12
      : time.hour;
  return '$hour:${time.minute.toString().padLeft(2, '0')}'
      '${time.hour < 12 ? 'am' : 'pm'}';
}
