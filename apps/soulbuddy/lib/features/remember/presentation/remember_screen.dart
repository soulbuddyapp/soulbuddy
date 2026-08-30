import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../../core/presentation/feature_page.dart';
import '../../record/providers/encounter_providers.dart';
import '../presentation/daily_remembrance_card.dart';
import '../providers/daily_memory_providers.dart';
import 'encounter_list_tile.dart';
import 'forget_quickly_card.dart';

class RememberScreen extends ConsumerStatefulWidget {
  const RememberScreen({super.key});

  @override
  ConsumerState<RememberScreen> createState() => _RememberScreenState();
}

class _RememberScreenState extends ConsumerState<RememberScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final encounters = ref.watch(encountersProvider);
    final dailyMemory = ref.watch(dailyMemoryProvider);

    return encounters.when(
      loading: () => const FeaturePage(
        title: 'What you have recorded',
        description: 'Opening your records…',
        action: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => FeaturePage(
        title: 'What you have recorded',
        description: 'Your records could not be opened just now.',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(encountersProvider),
          child: const Text('Try again'),
        ),
      ),
      data: (items) {
        final filtered = items
            .where((item) {
              final query = _query.trim().toLowerCase();
              if (query.isEmpty) return true;
              return item.title.toLowerCase().contains(query) ||
                  item.memoryType.name.toLowerCase().contains(query);
            })
            .toList(growable: false);
        if (items.isEmpty) {
          return const _EmptyRemember();
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: filtered.length + 5,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'What you have recorded',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const CovenantIncisedDivider(
                            key: Key('remember-incised-mark'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == 1) {
                    return const ForgetQuicklyCard(expanded: false);
                  }

                  if (index == 2) {
                    return const _CaptureButtons();
                  }

                  if (index == 3) {
                    return dailyMemory.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => TextButton(
                        onPressed: () => retryDailyMemoryProvider(ref),
                        child: const Text('Open today’s remembrance again'),
                      ),
                      data: (daily) => daily == null
                          ? const SizedBox.shrink()
                          : DailyRemembranceCard(dailyMemory: daily),
                    );
                  }

                  if (index == 4) {
                    return TextField(
                      key: const Key('remember-search'),
                      decoration: const InputDecoration(
                        labelText: 'Search your records',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    );
                  }

                  return EncounterListTile(encounter: filtered[index - 5]);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyRemember extends StatelessWidget {
  const _EmptyRemember();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'Remember',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Keep what you do not want to forget.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              const CovenantIncisedDivider(key: Key('remember-incised-mark')),
              const SizedBox(height: AppSpacing.md),
              const Flexible(
                child: SingleChildScrollView(
                  physics: NeverScrollableScrollPhysics(),
                  child: ForgetQuicklyCard(expanded: true),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _CaptureButtons(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CaptureButtons extends StatelessWidget {
  const _CaptureButtons();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          key: const Key('remember-speak'),
          onPressed: () => context.push('/remember/capture?mode=speak'),
          icon: const Icon(Icons.mic_none),
          label: const Text('Speak'),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('remember-write'),
          onPressed: () => context.push('/remember/capture?mode=write'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Write'),
        ),
      ),
    ],
  );
}
