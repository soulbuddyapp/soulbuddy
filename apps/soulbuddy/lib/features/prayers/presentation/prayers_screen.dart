import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';
import '../providers/prayer_providers.dart';
import '../providers/prayer_release_providers.dart';
import 'prayer_library_filters.dart';
import 'prayer_library_intro.dart';
import 'prayer_library_tile.dart';
import 'weekly_prayer_release_card.dart';

class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
  PrayerGrounding? _grounding;
  PrayerPurpose? _purpose;
  var _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final filter = (grounding: _grounding, purpose: _purpose);
    final library = ref.watch(prayerLibraryProvider(filter));

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  'Prayers',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Find words for this moment and carry one into today.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                key: const Key('meditation-section-card'),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  leading: const Icon(Icons.self_improvement, size: 32),
                  title: const Text('Meditation'),
                  subtitle: const Text(
                    'Guided Scripture, reflection, prayer, and eight calming soundscapes.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/prayers/meditation'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrayerLibraryIntro(
                onForThisMoment: () => context.go('/prayers/create'),
              ),
              const SizedBox(height: AppSpacing.md),
              // One compact discovery row, only when a published release exists.
              _WeeklyReleaseDiscovery(onOpen: (slug) => _openRelease(slug)),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: ExpansionTile(
                  key: const Key('prayer-filter-disclosure'),
                  initiallyExpanded: _filtersExpanded,
                  onExpansionChanged: (value) =>
                      setState(() => _filtersExpanded = value),
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('Refine the library'),
                  subtitle: Text(_filterSummary),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    PrayerLibraryFilters(
                      grounding: _grounding,
                      purpose: _purpose,
                      onGroundingChanged: (value) =>
                          setState(() => _grounding = value),
                      onPurposeChanged: (value) =>
                          setState(() => _purpose = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              library.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => _LibraryUnavailable(
                  onRetry: () => retryPrayerLibraryProviders(ref, filter),
                ),
                data: (prayers) {
                  if (prayers.isEmpty) {
                    return _EmptyLibrary(onClear: _clearFilters);
                  }
                  return Column(
                    children: [
                      for (var index = 0; index < prayers.length; index++) ...[
                        PrayerLibraryTile(
                          prayer: prayers[index],
                          onTap: () =>
                              context.go('/prayers/${prayers[index].id}'),
                        ),
                        if (index != prayers.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _grounding = null;
      _purpose = null;
    });
  }

  void _openRelease(String slug) {
    context.go('/prayers/releases/$slug');
  }

  String get _filterSummary {
    final labels = <String>[
      if (_grounding != null) prayerGroundingLabel(_grounding!),
      if (_purpose != null) prayerPurposeLabel(_purpose!),
    ];
    return labels.isEmpty ? 'All prayers' : labels.join(' · ');
  }
}

/// A single published release, mirrored locally so it can be shown offline.
class _WeeklyReleaseDiscovery extends ConsumerWidget {
  const _WeeklyReleaseDiscovery({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Refresh discovery on prayer-tab entry; a failure keeps the cached copy.
    ref.watch(prayerReleaseRefreshProvider);
    final releases = ref.watch(discoveredPrayerReleasesProvider);

    return releases.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (items) {
        // A single row only: the most recent release is the one on offer.
        final release = items.isEmpty ? null : items.first;
        if (release == null) return const SizedBox.shrink();

        return WeeklyPrayerReleaseCard(
          release: release,
          onOpen: () => onOpen(release.slug),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No prayer matches these choices yet.'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onClear, child: const Text('Clear filters')),
      ],
    );
  }
}

class _LibraryUnavailable extends StatelessWidget {
  const _LibraryUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('The prayer library could not be opened just now.'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
