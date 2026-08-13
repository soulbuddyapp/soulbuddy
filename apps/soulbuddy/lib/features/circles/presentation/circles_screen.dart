import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../domain/circle.dart';
import '../providers/circle_providers.dart';
import 'create_circle_sheet.dart';

class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(circlesProvider);
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
                  'Circles',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              circles.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _CirclesUnavailable(
                  onRetry: () => retryCircleProviders(ref),
                ),
                data: (items) => items.isEmpty
                    ? _CirclesStartGuide(onCreate: () => _create(context))
                    : _CircleList(
                        circles: items,
                        onCreate: () => _create(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final circleId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => const CreateCircleSheet(),
    );
    if (circleId != null && context.mounted) {
      context.go('/circles/$circleId');
    }
  }
}

class _CirclesStartGuide extends StatelessWidget {
  const _CirclesStartGuide({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GatheredInscriptionMark(
          key: Key('circles-gathered-inscription'),
          height: 64,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A private place to begin',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Keep a prayer need, encouragement, or Scripture here.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: colors.primary),
            const SizedBox(width: AppSpacing.xs),
            const Flexible(child: Text('Only you · saved on this device')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('create-circle'),
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create a Circle'),
        ),
        const SizedBox(
          key: Key('circles-start-guide-end'),
          height: AppSpacing.xs,
        ),
      ],
    );
  }
}

class _CircleList extends StatelessWidget {
  const _CircleList({required this.circles, required this.onCreate});

  final List<Circle> circles;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        key: const Key('create-circle'),
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Create another Circle'),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (var index = 0; index < circles.length; index++) ...[
        Card(
          child: ListTile(
            minTileHeight: 80,
            leading: const CircleAvatar(child: Icon(Icons.people_outline)),
            title: Text(circles[index].name),
            subtitle: const Text('Only you · on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/circles/${circles[index].id}'),
          ),
        ),
        if (index != circles.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _CirclesUnavailable extends StatelessWidget {
  const _CirclesUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Your Circles could not be opened just now.'),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}
