import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../editorial/data/editorial_prayer_repository.dart';
import '../domain/library_prayer.dart';
import '../providers/prayer_providers.dart';
import 'prayer_library_tile.dart';
import 'recorded_prayer_capture.dart';

class PrayerCreateScreen extends ConsumerStatefulWidget {
  const PrayerCreateScreen({
    this.contextTitle,
    this.prayerStarter,
    this.initialPurpose,
    super.key,
  });

  final String? contextTitle;
  final String? prayerStarter;
  final PrayerPurpose? initialPurpose;

  @override
  ConsumerState<PrayerCreateScreen> createState() => _PrayerCreateScreenState();
}

class _PrayerCreateScreenState extends ConsumerState<PrayerCreateScreen> {
  PrayerPurpose? _purpose;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _purpose = widget.initialPurpose;
  }

  @override
  Widget build(BuildContext context) {
    final purpose = _purpose;
    final reviewed = purpose == null
        ? null
        : ref.watch(
            reviewedEditorialPrayersProvider((
              purpose: purpose,
              languagePreference: null,
            )),
          );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : () => context.go('/prayers'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Prayers'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    'For this moment',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Listen or record',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.contextTitle case final title?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: const Text('From your meditation'),
                      subtitle: Text(title),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'What are you praying about?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final value in PrayerPurpose.values)
                      ChoiceChip(
                        key: Key('prayer-create-purpose-${value.wireValue}'),
                        selected: purpose == value,
                        label: Text(prayerPurposeLabel(value)),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _purpose = value;
                              }),
                      ),
                  ],
                ),
                if (reviewed != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  reviewed.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => const Text(
                      'Reviewed prayers are unavailable just now. Your own words remain available.',
                    ),
                    data: (items) => _ReviewedPrayerOptions(items: items),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Your own words',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    key: const Key('prayer-create-speak'),
                    onPressed: _saving ? null : _recordPrayer,
                    icon: const Icon(Icons.mic_none),
                    label: const Text('Record prayer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordPrayer() async {
    final purpose = _purpose;
    if (purpose == null || _saving) return;
    setState(() => _saving = true);
    try {
      final prayer = await showRecordedPrayerCapture(
        context,
        title: 'My prayer · ${prayerPurposeLabel(purpose)}',
        purpose: purpose,
      );
      if (prayer != null && mounted) context.go('/prayers/saved/${prayer.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}

class _ReviewedPrayerOptions extends StatelessWidget {
  const _ReviewedPrayerOptions({required this.items});

  final List<EditorialPrayer> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No reviewed prayer matches this yet. You can use your own words.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Reviewed prayer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < items.length && index < 3; index++) ...[
          _ReviewedPrayerCard(item: items[index]),
          if (index != items.length - 1 && index != 2)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ReviewedPrayerCard extends StatelessWidget {
  const _ReviewedPrayerCard({required this.item});

  final EditorialPrayer item;

  @override
  Widget build(BuildContext context) {
    final prayer = item.prayer;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('prayer-create-reviewed-${prayer.id}'),
        onTap: () => context.go('/prayers/${prayer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prayer.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reviewed · SoulBuddy editorial · v${item.editorial.contentVersion}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
