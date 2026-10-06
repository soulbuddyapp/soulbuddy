import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import '../domain/prayer_release.dart';
import '../providers/prayer_release_providers.dart';

/// One published weekly collection.
///
/// Before an add, only the compact add action is offered. After an add, the
/// exact preparation text and the five ordered entries are presented, and each
/// entry opens the ordinary prayer detail flow.
class PrayerReleaseDetailScreen extends ConsumerStatefulWidget {
  const PrayerReleaseDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<PrayerReleaseDetailScreen> createState() =>
      _PrayerReleaseDetailScreenState();
}

class _PrayerReleaseDetailScreenState
    extends ConsumerState<PrayerReleaseDetailScreen> {
  var _adding = false;
  var _failed = false;

  Future<void> _add() async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _failed = false;
    });

    try {
      final repository = await ref.read(prayerReleaseRepositoryProvider.future);
      await repository.addRelease(widget.slug);
      if (!mounted) return;
      setState(() => _adding = false);
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
    final release = ref.watch(prayerReleaseProvider(widget.slug));
    final content = ref.watch(prayerReleaseContentProvider(widget.slug));

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('prayer-release-back'),
                    onPressed: () => context.go('/prayers'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Prayers'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                release.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => _ReleaseUnavailable(
                    onRetry: () {
                      ref.invalidate(prayerReleaseProvider(widget.slug));
                    },
                  ),
                  data: (value) {
                    if (value == null) {
                      return const _ReleaseMessage(
                        title: 'Collection unavailable',
                        body: 'This prayer collection is not available.',
                      );
                    }

                    return _ReleaseHeader(release: value);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                content.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (items) {
                    if (items.isEmpty) return _addAction();
                    return _addedCollection(items);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addAction() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(
          key: const Key('prayer-release-add'),
          onPressed: _adding ? null : _add,
          child: Text(_adding ? 'Adding' : 'Add prayers'),
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The prayers were not added.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('prayer-release-retry'),
            onPressed: _add,
            child: const Text('Try again'),
          ),
        ],
      ],
    );
  }

  Widget _addedCollection(List<PrayerReleaseItemContent> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ReleaseItemCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ReleaseHeader extends StatelessWidget {
  const _ReleaseHeader({required this.release});

  final PrayerRelease release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          release.discoveryLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SanctuaryReadingHeading(title: release.title, art: SanctuaryArt.prayer),
        const SizedBox(height: AppSpacing.sm),
        Text(
          release.discoveryDetail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReleaseItemCard extends StatelessWidget {
  const _ReleaseItemCard({required this.item});

  final PrayerReleaseItemContent item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      key: Key('prayer-release-item-${item.sortOrder}'),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.sortOrder + 1} \u00B7 ${item.kind.label}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(item.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  key: Key('prayer-release-open-${item.sortOrder}'),
                  onPressed: () =>
                      context.go('/prayers/${item.libraryPrayerId}'),
                  child: const Text('Open prayer'),
                ),
                if (item.practice != null)
                  OutlinedButton.icon(
                    key: Key('prayer-release-attention-${item.sortOrder}'),
                    onPressed: () => context.go(
                      '/prayers/releases/${item.releaseSlug}/attention',
                    ),
                    icon: const Icon(Icons.self_improvement),
                    label: const Text('Be still before God'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseUnavailable extends StatelessWidget {
  const _ReleaseUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This prayer collection could not be opened just now.'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('prayer-release-unavailable-retry'),
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _ReleaseMessage extends StatelessWidget {
  const _ReleaseMessage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(body),
      ],
    );
  }
}
