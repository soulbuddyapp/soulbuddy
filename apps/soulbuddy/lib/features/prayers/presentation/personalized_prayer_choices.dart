import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

class PersonalizedPrayerChoice<T> {
  const PersonalizedPrayerChoice({required this.value, required this.label});

  final T value;
  final String label;
}

class PersonalizedPrayerChoices<T> extends StatelessWidget {
  const PersonalizedPrayerChoices({
    required this.label,
    required this.choices,
    required this.onSelected,
    this.selected,
    super.key,
  });

  final String label;
  final List<PersonalizedPrayerChoice<T>> choices;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final width = wide
                ? (constraints.maxWidth - AppSpacing.sm) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final choice in choices)
                  SizedBox(
                    width: width,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: RadioListTile<T>(
                        value: choice.value,
                        title: Text(choice.label),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
