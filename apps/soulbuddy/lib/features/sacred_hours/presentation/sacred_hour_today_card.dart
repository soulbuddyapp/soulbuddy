import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/app_spacing.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/meditation_session.dart';
import '../application/sacred_hour_today_window.dart';
import '../domain/sacred_hour.dart';

class SacredHourTodayCard extends ConsumerStatefulWidget {
  const SacredHourTodayCard({
    required this.hour,
    required this.nowUtc,
    required this.onOpen,
    this.completed = false,
    this.soundPlayer,
    super.key,
  });
  final SacredHour hour;
  final DateTime nowUtc;
  final VoidCallback onOpen;
  final bool completed;
  final MeditationSoundBedPlayer? soundPlayer;
  @override
  ConsumerState<SacredHourTodayCard> createState() =>
      _SacredHourTodayCardState();
}

class _SacredHourTodayCardState extends ConsumerState<SacredHourTodayCard> {
  late final MeditationSoundBedPlayer _player =
      widget.soundPlayer ?? AudioplayersMeditationSoundBedPlayer();
  MeditationSoundBed? _sound;
  double _volume = .15;
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final value = await ref.read(meditationSoundPreferencesProvider).load();
      if (mounted) {
        setState(() {
          _sound = value.sound;
          _volume = value.volume;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final sound = _sound;
    if (sound == null) return;
    await _player.start(sound, volume: _volume);
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final window = SacredHourTodayWindow.classify(widget.hour, widget.nowUtc);
    final active = window.phase == SacredHourTodayPhase.active;
    final action = widget.completed
        ? 'Complete'
        : active
        ? 'Open'
        : 'Prepare';
    return Card(
      key: const Key('sacred-hour-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(width: 4, height: 64, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.hour.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    '${active ? 'Now' : 'In ${window.minutesUntil} min'} · ${_formatRange(widget.hour)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Begin with ${widget.hour.prayerMinutes} minutes of prayer',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('sacred-hour-today-audio'),
              onPressed: _sound == null ? null : () => unawaited(_toggle()),
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              tooltip: _playing ? 'Pause music' : 'Play music',
            ),
            FilledButton.tonal(onPressed: widget.onOpen, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

String _formatRange(SacredHour hour) {
  final start = hour.localTime.hour * 60 + hour.localTime.minute;
  final end = (start + hour.durationMinutes) % (24 * 60);
  return '${_time(start)}–${_time(end, suffix: true)}';
}

String _time(int minutes, {bool suffix = false}) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final value =
      '${h == 0
          ? 12
          : h > 12
          ? h - 12
          : h}:${m.toString().padLeft(2, '0')}';
  return suffix ? '$value${h < 12 ? 'am' : 'pm'}' : value;
}
