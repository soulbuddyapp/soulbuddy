import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/providers/encounter_providers.dart';
import '../data/circle_directory_repository.dart';
import '../domain/circle.dart';
import '../domain/legacy_circle.dart';
import '../providers/circle_providers.dart';
import 'create_circle_sheet.dart';

class CirclesScreen extends ConsumerStatefulWidget {
  const CirclesScreen({super.key});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen> {
  final _searchController = TextEditingController();
  CircleCategory? _category;
  String? _search;
  String? _cursor;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CircleDiscoveryQuery get _query => CircleDiscoveryQuery(
    category: _category,
    search: _search,
    cursor: _cursor,
  );

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(circleDiscoveryProvider(_query));
    final owned = ref.watch(ownedCirclesProvider);
    final legacy = ref.watch(legacyCirclesProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Text('Circles', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Find people to walk with.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final category in CircleCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (selected) => setState(() {
                        _category = selected ? category : null;
                        _cursor = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('circle-search-field'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search Circles',
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _applySearch,
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (_) => _applySearch(),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('create-circle'),
                onPressed: _createCircle,
                icon: const Icon(Icons.add),
                label: const Text('Create a Circle'),
              ),
              const SizedBox(height: AppSpacing.xl),
              legacy.when(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _LegacyMigrationSection(
                        items: items,
                        onKeep: _keepLegacy,
                        onCopy: _copyLegacy,
                        onDiscard: _discardLegacy,
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              owned.when(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _CircleSection(
                        title: 'Your Circles',
                        items: items,
                        onOpen: _openExternal,
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              Text('Discover', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              discovery.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _DirectoryUnavailable(
                  onRetry: () => ref.invalidate(circleDiscoveryProvider(_query)),
                ),
                data: (page) => _DiscoveryPage(
                  page: page,
                  cursor: _cursor,
                  onOpen: _openExternal,
                  onNext: page.nextCursor == null
                      ? null
                      : () => setState(() => _cursor = page.nextCursor),
                  onFirst: _cursor == null
                      ? null
                      : () => setState(() => _cursor = null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applySearch() {
    setState(() {
      final value = _searchController.text.trim();
      _search = value.isEmpty ? null : value;
      _cursor = null;
    });
  }

  Future<void> _createCircle() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CreateCircleSheet(),
    );
    if (id != null && mounted) context.go('/circles/$id');
  }

  Future<void> _openExternal(Circle circle) async {
    final uri = circle.openUri;
    if (uri == null) return;
    final opened = await ref.read(circleExternalLauncherProvider)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this Circle.')),
      );
    }
  }

  Future<void> _keepLegacy(LegacyCircleSummary circle) async {
    try {
      final service = await ref.read(legacyCircleMigrationServiceProvider.future);
      final kept = await service.keepAsPrivateRecord(circle.id);
      if (kept == null) return;
      ref.invalidate(legacyCirclesProvider);
      ref.invalidate(encountersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kept as a private Record.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not keep these messages yet.')),
        );
      }
    }
  }

  Future<void> _copyLegacy(LegacyCircleSummary circle) async {
    try {
      final service = await ref.read(legacyCircleMigrationServiceProvider.future);
      final text = await service.copyText(circle.id);
      if (text == null) return;
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied. The local Circle is still here.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy these messages yet.')),
        );
      }
    }
  }

  Future<void> _discardLegacy(LegacyCircleSummary circle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard local Circle?'),
        content: Text(
          'This permanently removes ${circle.messageCount} saved local messages from ${circle.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repository = await ref.read(
        legacyCircleMigrationRepositoryProvider.future,
      );
      await repository.discard(circle.id);
      ref.invalidate(legacyCirclesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not discard this local Circle yet.')),
        );
      }
    }
  }
}

class _CircleSection extends StatelessWidget {
  const _CircleSection({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<Circle> items;
  final ValueChanged<Circle> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      for (final circle in items) ...[
        _CircleCard(circle: circle, onOpen: () => onOpen(circle)),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.lg),
    ],
  );
}

class _DiscoveryPage extends StatelessWidget {
  const _DiscoveryPage({
    required this.page,
    required this.cursor,
    required this.onOpen,
    required this.onNext,
    required this.onFirst,
  });

  final CirclePage page;
  final String? cursor;
  final ValueChanged<Circle> onOpen;
  final VoidCallback? onNext;
  final VoidCallback? onFirst;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text('No Circles match this search.', textAlign: TextAlign.center),
      );
    }
    return Column(
      children: [
        for (final circle in page.items) ...[
          _CircleCard(circle: circle, onOpen: () => onOpen(circle)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onFirst != null)
              TextButton(onPressed: onFirst, child: const Text('First results')),
            if (onNext != null)
              TextButton(onPressed: onNext, child: const Text('Next results')),
          ],
        ),
      ],
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle, required this.onOpen});

  final Circle circle;
  final VoidCallback onOpen;

  String? get _ownerState {
    if (!circle.isOwner) return null;
    if (!circle.directoryListed) return 'Not listed';
    return switch (circle.status) {
      CircleStatus.draft => 'Draft',
      CircleStatus.paused => 'Paused',
      CircleStatus.suspended => 'Suspended',
      CircleStatus.archived => 'Archived',
      CircleStatus.active => null,
    };
  }

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => context.go('/circles/${circle.publicId}'),
      borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(circle.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                circle.category.label,
                circle.provider?.label ?? 'External',
                if (_ownerState case final state?) state,
              ].join(' · '),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(circle.description),
            if (circle.memberCount case final count?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('$count members'),
            ],
            if (circle.canOpen) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Circle'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _LegacyMigrationSection extends StatelessWidget {
  const _LegacyMigrationSection({
    required this.items,
    required this.onKeep,
    required this.onCopy,
    required this.onDiscard,
  });

  final List<LegacyCircleSummary> items;
  final ValueChanged<LegacyCircleSummary> onKeep;
  final ValueChanged<LegacyCircleSummary> onCopy;
  final ValueChanged<LegacyCircleSummary> onDiscard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Saved on this device', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.xs),
      const Text(
        'These are from the old local Circles. Nothing here will be sent to Telegram or WhatsApp.',
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final circle in items) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(circle.name, style: Theme.of(context).textTheme.titleMedium),
                Text('${circle.messageCount} saved local messages'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (circle.messageCount > 0)
                      TextButton(
                        onPressed: () => onKeep(circle),
                        child: const Text('Keep as private Record'),
                      ),
                    if (circle.messageCount > 0)
                      TextButton(
                        onPressed: () => onCopy(circle),
                        child: const Text('Copy'),
                      ),
                    TextButton(
                      onPressed: () => onDiscard(circle),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.lg),
    ],
  );
}

class _DirectoryUnavailable extends StatelessWidget {
  const _DirectoryUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Column(
      children: [
        const Icon(Icons.wifi_off_outlined, size: 40),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Circles need a connection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Your private Goals and Records still work offline.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
