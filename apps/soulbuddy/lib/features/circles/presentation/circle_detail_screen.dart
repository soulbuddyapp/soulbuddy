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

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({required this.circleId, super.key});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circle = ref.watch(circleProvider(circleId));
    final legacy = ref.watch(legacyCircleArchiveProvider(circleId));
    if (circle.hasError && legacy.value != null) {
      return _LegacyCircleDetail(archive: legacy.requireValue);
    }
    return circle.when(
      loading: () => const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => legacy.when(
        data: (archive) => archive == null
            ? const _CircleUnavailable()
            : _LegacyCircleDetail(archive: archive),
        loading: () => const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const _CircleUnavailable(),
      ),
      data: (value) => value == null
          ? legacy.when(
              data: (archive) => archive == null
                  ? const _CircleUnavailable()
                  : _LegacyCircleDetail(archive: archive),
              loading: () => const SafeArea(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const _CircleUnavailable(),
            )
          : _ExternalCircleDetail(circle: value),
    );
  }
}

class _ExternalCircleDetail extends ConsumerWidget {
  const _ExternalCircleDetail({required this.circle});

  final Circle circle;

  bool get _canMutate =>
      circle.status != CircleStatus.suspended &&
      circle.status != CircleStatus.archived;

  String get _lifecycleLabel => switch (circle.status) {
    CircleStatus.draft => 'Publish Circle',
    CircleStatus.active => 'Pause Circle',
    CircleStatus.paused => 'Resume Circle',
    CircleStatus.suspended => 'Circle suspended',
    CircleStatus.archived => 'Circle archived',
  };

  CircleStatus? get _nextLifecycleStatus => switch (circle.status) {
    CircleStatus.draft => CircleStatus.active,
    CircleStatus.active => CircleStatus.paused,
    CircleStatus.paused => CircleStatus.active,
    CircleStatus.suspended || CircleStatus.archived => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to Circles',
                  onPressed: () => context.go('/circles'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    circle.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${circle.category.label} · ${circle.provider?.label ?? 'External'}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(circle.description),
            if (circle.isOwner && !circle.directoryListed) ...[
              const SizedBox(height: AppSpacing.md),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.visibility_off_outlined),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Not listed in SoulBuddy discovery. Your external group is unchanged. Changing visibility will not relist it.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.open_in_new),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Conversation happens in ${circle.provider?.label ?? 'the external group'}. SoulBuddy keeps this Circle’s purpose and settings, not its chat.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (circle.canOpen)
              FilledButton.icon(
                key: const Key('open-external-circle'),
                onPressed: () => _open(context, ref),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Circle'),
              ),
            if (circle.isOwner) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _canMutate ? () => _edit(context, ref) : null,
                child: const Text('Edit Circle'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('circle-lifecycle-action'),
                onPressed: _nextLifecycleStatus == null
                    ? null
                    : () => _changeLifecycle(context, ref),
                child: Text(_lifecycleLabel),
              ),
              TextButton(
                onPressed: _canMutate ? () => _archive(context, ref) : null,
                child: const Text('Archive Circle'),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => _report(context, ref),
                child: const Text('Report directory listing'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final uri = circle.openUri;
    if (uri == null) return;
    if (!await ref.read(circleExternalLauncherProvider)(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this Circle.')),
      );
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CreateCircleSheet(initialCircle: circle),
    );
    if (saved != null) ref.invalidate(circleProvider(circle.publicId));
  }

  Future<void> _changeLifecycle(BuildContext context, WidgetRef ref) async {
    final nextStatus = _nextLifecycleStatus;
    if (nextStatus == null) return;
    try {
      final repository = await ref.read(circleDirectoryRepositoryProvider.future);
      await repository.update(
        circle.publicId,
        CircleUpdate(status: nextStatus),
      );
      ref.invalidate(circleProvider(circle.publicId));
      ref.invalidate(ownedCirclesProvider);
      ref.invalidate(circleDiscoveryProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change this Circle yet.')),
        );
      }
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Circle?'),
        content: const Text(
          'The external group is not deleted. SoulBuddy will stop listing this Circle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repository = await ref.read(circleDirectoryRepositoryProvider.future);
      await repository.update(
        circle.publicId,
        const CircleUpdate(status: CircleStatus.archived),
      );
      ref.invalidate(ownedCirclesProvider);
      ref.invalidate(circleDiscoveryProvider);
      if (context.mounted) context.go('/circles');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not archive this Circle yet.')),
        );
      }
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report listing'),
        children: [
          for (final item in const [
            ('spam', 'Spam'),
            ('unsafe', 'Unsafe'),
            ('misleading', 'Misleading'),
            ('other', 'Other'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item.$1),
              child: Text(item.$2),
            ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final repository = await ref.read(circleDirectoryRepositoryProvider.future);
      await repository.report(circle.publicId, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report received.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send this report yet.')),
        );
      }
    }
  }
}

class _LegacyCircleDetail extends ConsumerWidget {
  const _LegacyCircleDetail({required this.archive});

  final LegacyCircleArchive archive;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              archive.summary.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This is an old Circle saved only on this device. It will never be uploaded to an external group automatically.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (archive.messages.isNotEmpty) ...[
              FilledButton(
                onPressed: () => _keep(context, ref),
                child: const Text('Keep messages as private Record'),
              ),
              OutlinedButton(
                onPressed: () => _copy(context, ref),
                child: const Text('Copy messages'),
              ),
            ],
            TextButton(
              onPressed: () => context.go('/circles'),
              child: const Text('Back to Circles'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _keep(BuildContext context, WidgetRef ref) async {
    try {
      final service = await ref.read(legacyCircleMigrationServiceProvider.future);
      final encounter = await service.keepAsPrivateRecord(archive.summary.id);
      if (encounter == null) return;
      ref.invalidate(legacyCirclesProvider);
      ref.invalidate(encountersProvider);
      if (context.mounted) context.go('/record');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not keep these messages yet.')),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    try {
      final service = await ref.read(legacyCircleMigrationServiceProvider.future);
      final text = await service.copyText(archive.summary.id);
      if (text == null) return;
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied. The local Circle is still here.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not copy these messages yet.')),
        );
      }
    }
  }
}

class _CircleUnavailable extends StatelessWidget {
  const _CircleUnavailable();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Circle unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This listing is not available, or Circles cannot connect right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.go('/circles'),
              child: const Text('Back to Circles'),
            ),
          ],
        ),
      ),
    ),
  );
}
