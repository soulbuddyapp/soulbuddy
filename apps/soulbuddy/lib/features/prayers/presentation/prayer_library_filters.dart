import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';
import 'prayer_library_tile.dart';

class PrayerLibraryFilters extends StatelessWidget {
  const PrayerLibraryFilters({
    required this.grounding,
    required this.purpose,
    required this.onGroundingChanged,
    required this.onPurposeChanged,
    super.key,
  });

  final PrayerGrounding? grounding;
  final PrayerPurpose? purpose;
  final ValueChanged<PrayerGrounding?> onGroundingChanged;
  final ValueChanged<PrayerPurpose?> onPurposeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSection<PrayerGrounding>(
          label: 'Grounding',
          allKey: const Key('grounding-all'),
          selected: grounding,
          values: PrayerGrounding.values,
          labelFor: prayerGroundingLabel,
          keyFor: (value) =>
              Key('grounding-${value.wireValue.replaceAll('_', '-')}'),
          onSelected: onGroundingChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _FilterSection<PrayerPurpose>(
          label: 'Purpose',
          allKey: const Key('purpose-all'),
          selected: purpose,
          values: PrayerPurpose.values,
          labelFor: prayerPurposeLabel,
          keyFor: (value) =>
              Key('purpose-${value.wireValue.replaceAll('_', '-')}'),
          onSelected: onPurposeChanged,
        ),
      ],
    );
  }
}

class _FilterSection<T> extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.allKey,
    required this.selected,
    required this.values,
    required this.labelFor,
    required this.keyFor,
    required this.onSelected,
  });

  final String label;
  final Key allKey;
  final T? selected;
  final List<T> values;
  final String Function(T value) labelFor;
  final Key Function(T value) keyFor;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      FilterChip(
        key: allKey,
        label: const Text('All'),
        selected: selected == null,
        onSelected: (_) => onSelected(null),
      ),
      for (final value in values)
        FilterChip(
          key: keyFor(value),
          label: Text(labelFor(value)),
          selected: selected == value,
          onSelected: (_) => onSelected(selected == value ? null : value),
        ),
    ];

    return Semantics(
      container: true,
      label: '$label filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 560) {
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: chips,
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < chips.length; index++) ...[
                      chips[index],
                      if (index != chips.length - 1)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
