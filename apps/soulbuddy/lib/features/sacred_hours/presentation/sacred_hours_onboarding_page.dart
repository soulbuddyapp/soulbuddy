import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/covenant_grace_tokens.dart';
import '../../prayers/domain/prayer_reminder.dart';

class SacredHoursOnboardingSelection {
  const SacredHoursOnboardingSelection({
    required this.morningStart,
    required this.eveningStart,
    required this.morningPrayerMinutes,
    required this.eveningPrayerMinutes,
  });

  factory SacredHoursOnboardingSelection.defaults() =>
      SacredHoursOnboardingSelection(
        morningStart: PrayerLocalTime(hour: 6, minute: 0),
        eveningStart: PrayerLocalTime(hour: 22, minute: 0),
        morningPrayerMinutes: 15,
        eveningPrayerMinutes: 15,
      );

  final PrayerLocalTime morningStart;
  final PrayerLocalTime eveningStart;
  final int morningPrayerMinutes;
  final int eveningPrayerMinutes;

  SacredHoursOnboardingSelection copyWith({
    PrayerLocalTime? morningStart,
    PrayerLocalTime? eveningStart,
    int? morningPrayerMinutes,
    int? eveningPrayerMinutes,
  }) => SacredHoursOnboardingSelection(
    morningStart: morningStart ?? this.morningStart,
    eveningStart: eveningStart ?? this.eveningStart,
    morningPrayerMinutes: morningPrayerMinutes ?? this.morningPrayerMinutes,
    eveningPrayerMinutes: eveningPrayerMinutes ?? this.eveningPrayerMinutes,
  );
}

class SacredHoursOnboardingPage extends StatelessWidget {
  const SacredHoursOnboardingPage({
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final SacredHoursOnboardingSelection selection;
  final ValueChanged<SacredHoursOnboardingSelection> onChanged;

  Future<void> _changeTime(
    BuildContext context, {
    required bool morning,
  }) async {
    final current = morning ? selection.morningStart : selection.eveningStart;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: morning ? 'Morning Sacred Hour' : 'Evening Sacred Hour',
    );
    if (chosen == null) return;
    final localTime = PrayerLocalTime(hour: chosen.hour, minute: chosen.minute);
    onChanged(
      morning
          ? selection.copyWith(morningStart: localTime)
          : selection.copyWith(eveningStart: localTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Sacred Hours setup',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            Text(
              'Set apart an hour',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Pray first. Then bring the work before you into God’s '
                'presence. Consider why He has placed you there and how you '
                'can serve Him in it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SacredHourSlab(
              title: 'Morning',
              start: selection.morningStart,
              prayerMinutes: selection.morningPrayerMinutes,
              changeKey: const Key('morning-time-change'),
              minuteKey: (minutes) => Key('morning-prayer-$minutes'),
              onChangeTime: () => _changeTime(context, morning: true),
              onPrayerMinutesChanged: (minutes) =>
                  onChanged(selection.copyWith(morningPrayerMinutes: minutes)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SacredHourSlab(
              title: 'Evening',
              start: selection.eveningStart,
              prayerMinutes: selection.eveningPrayerMinutes,
              changeKey: const Key('evening-time-change'),
              minuteKey: (minutes) => Key('evening-prayer-$minutes'),
              onChangeTime: () => _changeTime(context, morning: false),
              onPrayerMinutesChanged: (minutes) =>
                  onChanged(selection.copyWith(eveningPrayerMinutes: minutes)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SacredHourSlab extends StatelessWidget {
  const _SacredHourSlab({
    required this.title,
    required this.start,
    required this.prayerMinutes,
    required this.changeKey,
    required this.minuteKey,
    required this.onChangeTime,
    required this.onPrayerMinutesChanged,
  });

  final String title;
  final PrayerLocalTime start;
  final int prayerMinutes;
  final Key changeKey;
  final Key Function(int minutes) minuteKey;
  final VoidCallback onChangeTime;
  final ValueChanged<int> onPrayerMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<CovenantGraceColors>() ?? CovenantGraceColors.light;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: SizedBox(
        width: double.infinity,
        child: CustomPaint(
          painter: _NaturalSlabPainter(colors),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            _formatRange(start),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: changeKey,
                      onPressed: onChangeTime,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Begin with prayer',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final minutes in const [5, 15, 30])
                      ChoiceChip(
                        key: minuteKey(minutes),
                        label: Text('$minutes min'),
                        selected: prayerMinutes == minutes,
                        onSelected: (_) => onPrayerMinutesChanged(minutes),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NaturalSlabPainter extends CustomPainter {
  const _NaturalSlabPainter(this.colors);

  final CovenantGraceColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(8, 2)
      ..lineTo(size.width - 13, 0)
      ..lineTo(size.width - 3, 10)
      ..lineTo(size.width, size.height - 12)
      ..lineTo(size.width - 9, size.height)
      ..lineTo(12, size.height - 2)
      ..lineTo(1, size.height - 14)
      ..lineTo(3, 11)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()..color = colors.umber.withValues(alpha: .12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.limestoneLight, colors.limestone],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.umber.withValues(alpha: .28),
    );
  }

  @override
  bool shouldRepaint(covariant _NaturalSlabPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

String _formatRange(PrayerLocalTime start) {
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = (startMinutes + 60) % (24 * 60);
  return '${_clockTime(startMinutes)}–${_clockTime(endMinutes, suffix: true)}';
}

String _clockTime(int totalMinutes, {bool suffix = false}) {
  final hour24 = (totalMinutes ~/ 60) % 24;
  final minute = totalMinutes % 60;
  final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final value = '$hour12:${minute.toString().padLeft(2, '0')}';
  return suffix ? '$value${hour24 < 12 ? 'am' : 'pm'}' : value;
}
