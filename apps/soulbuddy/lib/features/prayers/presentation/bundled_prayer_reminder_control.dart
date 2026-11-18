import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/bundled_prayer_reminder.dart';
import '../application/bundled_prayer_audio.dart';
import '../providers/bundled_prayer_reminder_providers.dart';

class BundledPrayerReminderControl extends ConsumerStatefulWidget {
  const BundledPrayerReminderControl({
    super.key,
    required this.prayerId,
    required this.body,
  });
  final String prayerId;
  final String body;
  @override
  ConsumerState<BundledPrayerReminderControl> createState() =>
      _BundledPrayerReminderControlState();
}

class _BundledPrayerReminderControlState
    extends ConsumerState<BundledPrayerReminderControl> {
  bool busy = false;
  String? error;
  late Future<bool> _audioMatches;
  @override
  void initState() {
    super.initState();
    _loadAudioMatch();
  }

  @override
  void didUpdateWidget(covariant BundledPrayerReminderControl old) {
    super.didUpdateWidget(old);
    if (old.prayerId != widget.prayerId || old.body != widget.body) {
      _loadAudioMatch();
    }
  }

  void _loadAudioMatch() {
    _audioMatches = BundledPrayerAudioCatalog.load().then(
      (catalog) => catalog.assetFor(widget.prayerId, widget.body) != null,
    );
  }

  Future<void> setTime((int, int)? current) async {
    final value = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: current.$1, minute: current.$2),
    );
    if (value == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (await ref.read(
        bundledPrayerReminderProvider.future,
      )).setDaily(widget.prayerId, value.hour, value.minute);
      ref.invalidate(bundledPrayerReminderTimeProvider(widget.prayerId));
      ref.invalidate(bundledPrayerReminderAudioProvider(widget.prayerId));
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not set the reminder. Check notification permissions and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setAudio((int, int) time, bool enabled) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (await ref.read(
        bundledPrayerReminderProvider.future,
      )).setDaily(widget.prayerId, time.$1, time.$2, audioEnabled: enabled);
      ref.invalidate(bundledPrayerReminderAudioProvider(widget.prayerId));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update prayer audio. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (await ref.read(
        bundledPrayerReminderProvider.future,
      )).remove(widget.prayerId);
      ref.invalidate(bundledPrayerReminderTimeProvider(widget.prayerId));
      ref.invalidate(bundledPrayerReminderAudioProvider(widget.prayerId));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not remove the reminder. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (BundledPrayerReminder.numberFor(widget.prayerId) == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<bool>(
      future: _audioMatches,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(_loadAudioMatch),
            child: const Text('Try prayer audio again'),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        return _controls(context, canSchedule: snapshot.data!);
      },
    );
  }

  Widget _controls(BuildContext context, {required bool canSchedule}) {
    final time = ref.watch(bundledPrayerReminderTimeProvider(widget.prayerId));
    return time.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => TextButton(
        onPressed: () =>
            ref.invalidate(bundledPrayerReminderTimeProvider(widget.prayerId)),
        child: const Text('Try reminder again'),
      ),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              if (canSchedule)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => setTime(value),
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(
                    value == null
                        ? 'Set daily reminder'
                        : 'Daily · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: value.$1, minute: value.$2))}',
                  ),
                ),
              if (value != null)
                TextButton(
                  onPressed: busy ? null : remove,
                  child: const Text('Remove reminder'),
                ),
            ],
          ),
          if (!canSchedule) const Text('Prayer audio unavailable.'),
          if (value != null && canSchedule)
            ref
                .watch(bundledPrayerReminderAudioProvider(widget.prayerId))
                .when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(
                      bundledPrayerReminderAudioProvider(widget.prayerId),
                    ),
                    child: const Text('Try prayer audio again'),
                  ),
                  data: (enabled) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prayer audio'),
                    value: enabled,
                    onChanged: busy
                        ? null
                        : (enabled) => setAudio(value, enabled),
                  ),
                ),
          if (error != null) Text(error!),
        ],
      ),
    );
  }
}
