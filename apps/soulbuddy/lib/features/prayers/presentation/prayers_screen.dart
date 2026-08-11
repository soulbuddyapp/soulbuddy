import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';
import '../providers/prayer_providers.dart';
import 'prayer_library_choices.dart';
import 'prayer_library_filters.dart';
import 'prayer_library_tile.dart';

class PrayersScreen extends ConsumerStatefulWidget {
  const PrayersScreen({super.key});

  @override
  ConsumerState<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends ConsumerState<PrayersScreen> {
  PrayerGrounding? _grounding;
  PrayerPurpose? _purpose;

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
              const PrayerLibraryChoices(),
              const SizedBox(height: AppSpacing.xl),
              PrayerLibraryFilters(
                grounding: _grounding,
                purpose: _purpose,
                onGroundingChanged: (value) =>
                    setState(() => _grounding = value),
                onPurposeChanged: (value) => setState(() => _purpose = value),
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
