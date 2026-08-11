import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../../core/design/app_spacing.dart';
import '../domain/personal_prayer.dart';
import '../domain/prayer_reminder.dart';
import '../providers/prayer_practice_providers.dart';

enum _ReminderChoice { once, daily, weekdays }

class PrayerReminderControl extends ConsumerWidget {
  const PrayerReminderControl({required this.prayer, super.key});

  final PersonalPrayer prayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(prayerReminderProvider(prayer.id));
    return reminder.when(
      data: (value) => _button(context, value),
      loading: () => _button(context, null, enabled: false),
      error: (_, _) => _button(context, null, enabled: false),
    );
  }

  Widget _button(
    BuildContext context,
    PrayerReminder? reminder, {
    bool enabled = true,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: enabled
          ? () => showPrayerReminderSheet(
              context,
              prayer: prayer,
              existing: reminder,
            )
          : null,
      icon: const Icon(Icons.notifications_none),
      label: Text(
        reminder == null ? 'Set reminder' : _scheduleLabel(context, reminder),
      ),
    ),
  );
}

Future<void> showPrayerReminderSheet(
  BuildContext context, {
  required PersonalPrayer prayer,
  PrayerReminder? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        PrayerReminderSheet(prayer: prayer, existing: existing),
  );
}

class PrayerReminderSheet extends ConsumerStatefulWidget {
  const PrayerReminderSheet({required this.prayer, this.existing, super.key});

  final PersonalPrayer prayer;
  final PrayerReminder? existing;

  @override
  ConsumerState<PrayerReminderSheet> createState() =>
      _PrayerReminderSheetState();
}

class _PrayerReminderSheetState extends ConsumerState<PrayerReminderSheet> {
  late _ReminderChoice _choice;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  bool _saving = false;
  String? _validation;

  @override
  void initState() {
    super.initState();
    final schedule = widget.existing?.schedule;
    _choice = switch (schedule?.type) {
      PrayerScheduleType.once => _ReminderChoice.once,
      PrayerScheduleType.weekdays => _ReminderChoice.weekdays,
      _ => _ReminderChoice.daily,
    };
    _time = schedule == null
        ? const TimeOfDay(hour: 7, minute: 30)
        : TimeOfDay(
            hour: schedule.localTime.hour,
            minute: schedule.localTime.minute,
          );
    _weekdays = schedule?.weekdaysMask == null
        ? {DateTime.now().weekday}
        : {
            for (var weekday = 1; weekday <= 7; weekday++)
              if ((schedule!.weekdaysMask! & (1 << (weekday - 1))) != 0)
                weekday,
          };
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
                  'Prayer reminder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _choiceChip('Once', _ReminderChoice.once),
                    _choiceChip('Every day', _ReminderChoice.daily),
                    _choiceChip('Selected days', _ReminderChoice.weekdays),
                  ],
                ),
                if (_choice == _ReminderChoice.weekdays) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    key: const Key('prayer-reminder-weekdays'),
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
                                  _validation = null;
                                }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('prayer-reminder-time'),
                  onPressed: _saving ? null : _chooseTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(_time),
                  ),
                ),
                if (_validation != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _validation!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ChoiceChip _choiceChip(String label, _ReminderChoice choice) => ChoiceChip(
    label: Text(label),
    selected: _choice == choice,
    onSelected: _saving
        ? null
        : (_) => setState(() {
            _choice = choice;
            _validation = null;
          }),
  );

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Future<void> _save() async {
    if (_choice == _ReminderChoice.weekdays && _weekdays.isEmpty) {
      setState(() => _validation = 'Choose at least one day.');
      return;
    }
    setState(() {
      _saving = true;
      _validation = null;
    });
    try {
      final timezoneName = await ref.read(prayerDeviceTimezoneProvider)();
      final schedule = _buildSchedule(timezoneName);
      final repository = await ref.read(
        prayerPracticeRepositoryProvider.future,
      );
      final reminder = await repository.saveReminder(
        personalPrayerId: widget.prayer.id,
        schedule: schedule,
        enableOnThisDevice: false,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      String confirmation;
      try {
        final enabled = await ref.read(prayerReminderDeviceEnablerProvider)(
          reminder.id,
        );
        confirmation = enabled
            ? 'Reminder saved on this device'
            : 'Reminder saved. Notifications are off on this device.';
      } catch (_) {
        confirmation =
            'Reminder saved. Notification could not be enabled just now.';
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(confirmation)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _validation = 'Could not save this reminder just now.';
        });
      }
    }
  }

  PrayerReminderSchedule _buildSchedule(String timezoneName) {
    final localTime = PrayerLocalTime(hour: _time.hour, minute: _time.minute);
    return switch (_choice) {
      _ReminderChoice.daily => PrayerReminderSchedule.daily(
        localTime: localTime,
        timezone: timezoneName,
      ),
      _ReminderChoice.weekdays => PrayerReminderSchedule.weekdays(
        localTime: localTime,
        timezone: timezoneName,
        weekdaysMask: _weekdays.fold(0, (mask, day) => mask | (1 << (day - 1))),
      ),
      _ReminderChoice.once => PrayerReminderSchedule.once(
        localTime: localTime,
        timezone: timezoneName,
        onceAt: _nextOnceAt(timezoneName),
      ),
    };
  }

  DateTime _nextOnceAt(String timezoneName) {
    timezone_data.initializeTimeZones();
    final location = timezone.getLocation(timezoneName);
    final now = timezone.TZDateTime.now(location);
    var occurrence = timezone.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    if (!occurrence.isAfter(now)) {
      occurrence = timezone.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + 1,
        _time.hour,
        _time.minute,
      );
    }
    return occurrence.toUtc();
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

String _scheduleLabel(BuildContext context, PrayerReminder reminder) {
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(
      hour: reminder.schedule.localTime.hour,
      minute: reminder.schedule.localTime.minute,
    ),
  );
  return switch (reminder.schedule.type) {
    PrayerScheduleType.once => 'Once at $time',
    PrayerScheduleType.daily => 'Every day at $time',
    PrayerScheduleType.weekdays => 'Selected days at $time',
  };
}
