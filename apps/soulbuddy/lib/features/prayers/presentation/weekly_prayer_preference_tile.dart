import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/prayer_release.dart';
import '../providers/prayer_release_providers.dart';

/// The weekly delivery preference.
///
/// Turning it off stops future notices. It never removes a collection the person
/// has already added, and it never adds one on its own.
class WeeklyPrayerPreferenceTile extends ConsumerStatefulWidget {
  const WeeklyPrayerPreferenceTile({super.key});

  @override
  ConsumerState<WeeklyPrayerPreferenceTile> createState() =>
      _WeeklyPrayerPreferenceTileState();
}

class _WeeklyPrayerPreferenceTileState
    extends ConsumerState<WeeklyPrayerPreferenceTile> {
  var _saving = false;
  var _failed = false;

  /// The choice a failed attempt was trying to store, so a retry repeats that
  /// choice rather than the stored one.
  bool? _pending;

  Future<void> _set(bool weeklyEnabled) async {
    if (_saving) return;
    final current = ref.read(prayerReleasePreferenceProvider).value ??
        const PrayerReleasePreference();
    setState(() {
      _saving = true;
      _failed = false;
      _pending = weeklyEnabled;
    });

    try {
      final repository = await ref.read(
        prayerReleaseRepositoryProvider.future,
      );
      await repository.savePreference(
        PrayerReleasePreference(
          weeklyEnabled: weeklyEnabled,
          notificationEnabled: weeklyEnabled,
          timeZone: current.timeZone ?? _deviceTimeZone(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pending = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  /// The person's own zone, so delivery follows their local Monday.
  String _deviceTimeZone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == Duration.zero) return 'UTC';
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = offset.inMinutes.abs().remainder(60).toString().padLeft(2, '0');

    return 'Etc/GMT$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(prayerReleasePreferenceProvider);

    return preference.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('weekly-prayers-preference'),
            value: value.weeklyEnabled,
            onChanged: _saving ? null : _set,
            title: const Text('Weekly prayers'),
            subtitle: const Text('One new prayer collection each week'),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: TextButton(
                key: const Key('weekly-prayers-preference-retry'),
                onPressed: () => _set(_pending ?? value.weeklyEnabled),
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}
