import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/prayer_release.dart';
import '../providers/prayer_release_providers.dart';

/// One compact discovery row for a published weekly collection.
///
/// It carries the label, title, one purpose line, and one action. The five
/// prayer bodies are never rendered here.
class WeeklyPrayerReleaseCard extends ConsumerStatefulWidget {
  const WeeklyPrayerReleaseCard({
    required this.release,
    this.onOpen,
    this.onAdded,
    super.key,
  });

  final PrayerRelease release;
  final VoidCallback? onOpen;
  final ValueChanged<String>? onAdded;

  @override
  ConsumerState<WeeklyPrayerReleaseCard> createState() =>
      _WeeklyPrayerReleaseCardState();
}

class _WeeklyPrayerReleaseCardState
    extends ConsumerState<WeeklyPrayerReleaseCard> {
  var _adding = false;
  var _failed = false;
  var _added = false;

  @override
  void initState() {
    super.initState();
    _added = widget.release.added;
  }

  Future<void> _add() async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _failed = false;
    });

    try {
      final repository = await ref.read(
        prayerReleaseRepositoryProvider.future,
      );
      await repository.addRelease(widget.release.slug);
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
      widget.onAdded?.call(widget.release.slug);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final added = _added || release.added;
    final theme = Theme.of(context);

    return Card(
      key: const Key('weekly-prayer-release-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              release.discoveryLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(release.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              release.discoveryDetail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (added)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  Text('Added', style: theme.textTheme.bodyMedium),
                  TextButton(
                    key: const Key('weekly-prayer-release-open'),
                    onPressed: () => widget.onOpen?.call(),
                    child: const Text('Open'),
                  ),
                ],
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton(
                    key: const Key('weekly-prayer-release-add'),
                    onPressed: _adding ? null : _add,
                    child: Text(_adding ? 'Adding' : 'Add prayers'),
                  ),
                  if (_failed) ...[
                    Text(
                      'Not added yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      key: const Key('weekly-prayer-release-retry'),
                      onPressed: _add,
                      child: const Text('Try again'),
                    ),
                  ] else
                    TextButton(
                      key: const Key('weekly-prayer-release-preview'),
                      onPressed: () => widget.onOpen?.call(),
                      child: const Text('See the prayers'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
