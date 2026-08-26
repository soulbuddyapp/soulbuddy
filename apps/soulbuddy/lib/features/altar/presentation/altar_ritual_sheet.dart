import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../../prayers/domain/voice_tablet.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../domain/altar_ritual.dart';
import '../providers/altar_ritual_providers.dart';

enum _AltarDayChoice { daily, selectedDays }

Future<void> showAltarRitualSheet(
  BuildContext context,
  WidgetRef ref, {
  required VoiceTablet tablet,
}) async {
  try {
    final target = AltarTarget.voiceTablet(tablet.id);
    final timezoneName = await ref.read(prayerDeviceTimezoneProvider)();
    final existing = await ref.read(
      altarRitualForTargetProvider(target).future,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AltarRitualSheet(
        tablet: tablet,
        timezoneName: timezoneName,
        existing: existing,
        onSave: (draft) async {
          final repository = await ref.read(
            altarRitualRepositoryProvider.future,
          );
          final ritual = await repository.save(draft);
          final coordinator = await ref.read(
            altarReminderCoordinatorProvider.future,
          );
          await coordinator.enableOnThisDevice(ritual.id);
        },
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Altar just now.')),
      );
    }
  }
}

class AltarRitualSheet extends StatefulWidget {
  const AltarRitualSheet({
    required this.tablet,
    required this.timezoneName,
    required this.onSave,
    this.existing,
    super.key,
  });

  final VoiceTablet tablet;
  final String timezoneName;
  final AltarRitual? existing;
  final Future<void> Function(AltarRitualDraft) onSave;

  @override
  State<AltarRitualSheet> createState() => _AltarRitualSheetState();
}

class _AltarRitualSheetState extends State<AltarRitualSheet> {
  late _AltarDayChoice _dayChoice;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late AltarPlaybackMode _playbackMode;
  var _autoplayWhenOpened = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _dayChoice = existing?.schedule.type == AltarScheduleType.weekdays
        ? _AltarDayChoice.selectedDays
        : _AltarDayChoice.daily;
    _time = existing == null
        ? const TimeOfDay(hour: 7, minute: 30)
        : TimeOfDay(
            hour: existing.schedule.localTime.hour,
            minute: existing.schedule.localTime.minute,
          );
    _weekdays = existing?.schedule.weekdaysMask == null
        ? {DateTime.now().weekday}
        : {
            for (var day = 1; day <= 7; day++)
              if ((existing!.schedule.weekdaysMask! & (1 << (day - 1))) != 0)
                day,
          };
    _playbackMode =
        existing?.playbackMode ??
        (widget.tablet.refrainAudio != null
            ? AltarPlaybackMode.refrain
            : AltarPlaybackMode.fullPrayer);
    if (_playbackMode == AltarPlaybackMode.refrain &&
        widget.tablet.refrainAudio == null) {
      _playbackMode = AltarPlaybackMode.fullPrayer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Keep on my Altar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Return to this prayer at a chosen time.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _dayChip('Every day', _AltarDayChoice.daily),
                    _dayChip('Selected days', _AltarDayChoice.selectedDays),
                  ],
                ),
                if (_playbackMode != AltarPlaybackMode.openQuietly)
                  SwitchListTile(
                    key: const Key('altar-autoplay-on-open'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Play when I open the reminder'),
                    subtitle: const Text(
                      'Off by default. Your recording may use this device’s speaker.',
                    ),
                    value: _autoplayWhenOpened,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _autoplayWhenOpened = value;
                            _error = null;
                          }),
                  ),
                if (_dayChoice == _AltarDayChoice.selectedDays) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    key: const Key('altar-weekdays'),
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(_weekdayLabel(day)),
                          selected: _weekdays.contains(day),
                          onSelected: _saving
                              ? null
                              : (selected) => setState(() {
                                  selected
                                      ? _weekdays.add(day)
                                      : _weekdays.remove(day);
                                  _error = null;
                                }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('altar-time'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                  ),
                  onPressed: _saving ? null : _chooseTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(_time),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'At that time',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (widget.tablet.refrainAudio != null)
                      _playbackChip(
                        'Prayer Refrain',
                        AltarPlaybackMode.refrain,
                      ),
                    _playbackChip('Full prayer', AltarPlaybackMode.fullPrayer),
                    _playbackChip(
                      'Open quietly',
                      AltarPlaybackMode.openQuietly,
                    ),
                  ],
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('save-altar-ritual'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save to my Altar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ChoiceChip _dayChip(String label, _AltarDayChoice value) => ChoiceChip(
    label: Text(label),
    selected: _dayChoice == value,
    onSelected: _saving
        ? null
        : (_) => setState(() {
            _dayChoice = value;
            _error = null;
          }),
  );

  ChoiceChip _playbackChip(String label, AltarPlaybackMode value) => ChoiceChip(
    label: Text(label),
    selected: _playbackMode == value,
    onSelected: _saving
        ? null
        : (_) => setState(() {
            _playbackMode = value;
            _error = null;
          }),
  );

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _save() async {
    if (_dayChoice == _AltarDayChoice.selectedDays && _weekdays.isEmpty) {
      setState(() => _error = 'Choose at least one day.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final localTime = PrayerLocalTime(hour: _time.hour, minute: _time.minute);
      final schedule = _dayChoice == _AltarDayChoice.daily
          ? AltarRitualSchedule.daily(
              localTime: localTime,
              timezone: widget.timezoneName,
            )
          : AltarRitualSchedule.weekdays(
              localTime: localTime,
              timezone: widget.timezoneName,
              weekdaysMask: _weekdays.fold(
                0,
                (mask, day) => mask | (1 << (day - 1)),
              ),
            );
      await widget.onSave(
        AltarRitualDraft(
          target: AltarTarget.voiceTablet(widget.tablet.id),
          schedule: schedule,
          playbackMode: _playbackMode,
          enableOnThisDevice: true,
          autoplayWhenOpened:
              _playbackMode != AltarPlaybackMode.openQuietly &&
              _autoplayWhenOpened,
        ),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not keep this prayer on your Altar just now.';
        });
      }
    }
  }
}

String _weekdayLabel(int weekday) => const {
  DateTime.monday: 'M',
  DateTime.tuesday: 'T',
  DateTime.wednesday: 'W',
  DateTime.thursday: 'T',
  DateTime.friday: 'F',
  DateTime.saturday: 'S',
  DateTime.sunday: 'S',
}[weekday]!;
