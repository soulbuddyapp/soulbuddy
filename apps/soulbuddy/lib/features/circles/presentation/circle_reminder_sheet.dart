import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../prayers/domain/prayer_reminder.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../domain/circle.dart';
import '../domain/circle_reminder.dart';
import '../providers/circle_providers.dart';

class CircleReminderControl extends ConsumerWidget {
  const CircleReminderControl({required this.circle, super.key});

  final Circle circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(circleReminderProvider(circle.publicId));
    return reminder.when(
      data: (value) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('circle-reminder-control'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () =>
              showCircleReminderSheet(context, circle: circle, existing: value),
          icon: const Icon(Icons.notifications_none_rounded),
          label: Text(
            value == null
                ? 'Set reminder'
                : MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay(
                      hour: value.localTime.hour,
                      minute: value.localTime.minute,
                    ),
                  ),
          ),
        ),
      ),
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

Future<void> showCircleReminderSheet(
  BuildContext context, {
  required Circle circle,
  CircleReminder? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => CircleReminderSheet(circle: circle, existing: existing),
);

class CircleReminderSheet extends ConsumerStatefulWidget {
  const CircleReminderSheet({required this.circle, this.existing, super.key});

  final Circle circle;
  final CircleReminder? existing;

  @override
  ConsumerState<CircleReminderSheet> createState() =>
      _CircleReminderSheetState();
}

class _CircleReminderSheetState extends ConsumerState<CircleReminderSheet> {
  late TimeOfDay _time;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _time = existing == null
        ? const TimeOfDay(hour: 7, minute: 30)
        : TimeOfDay(
            hour: existing.localTime.hour,
            minute: existing.localTime.minute,
          );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Circle reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('circle-reminder-time'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _saving ? null : _chooseTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(_time),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save reminder'),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: _saving ? null : _remove,
                child: const Text('Remove reminder'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final timezone = await ref.read(prayerDeviceTimezoneProvider)();
      final reminder = CircleReminder(
        circleId: widget.circle.publicId,
        circleName: widget.circle.name,
        localTime: PrayerLocalTime(hour: _time.hour, minute: _time.minute),
        timezone: timezone,
        platformNotificationId: CircleReminder.platformNotificationIdFor(
          widget.circle.publicId,
        ),
      );
      await ref.read(circleReminderRepositoryProvider).save(reminder);
      final coordinator = await ref.read(
        circleReminderCoordinatorProvider.future,
      );
      final notificationsAllowed = await coordinator.enableOnThisDevice();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            notificationsAllowed
                ? 'Reminder saved'
                : 'Notifications are unavailable',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Reminder could not be saved';
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(circleReminderRepositoryProvider)
          .remove(widget.circle.publicId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reminder removed')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Reminder could not be removed';
        });
      }
    }
  }
}
