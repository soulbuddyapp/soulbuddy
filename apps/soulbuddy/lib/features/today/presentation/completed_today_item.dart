import 'package:flutter/material.dart';

class CompletedTodayItem extends StatelessWidget {
  const CompletedTodayItem({
    required this.id,
    required this.label,
    required this.completedAt,
    required this.onDismiss,
    super.key,
  });

  final String id;
  final String label;
  final DateTime completedAt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(completedAt));
    return Dismissible(
      key: ValueKey('completed-today-$id'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      background: ColoredBox(color: scheme.surfaceContainerHighest),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(time, style: Theme.of(context).textTheme.labelSmall),
            IconButton(
              key: ValueKey('dismiss-completed-$id'),
              tooltip: 'Dismiss completed item',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
