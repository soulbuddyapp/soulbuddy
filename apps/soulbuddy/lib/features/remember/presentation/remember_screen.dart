import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/feature_page.dart';
import '../../record/providers/encounter_providers.dart';
import 'encounter_list_tile.dart';

class RememberScreen extends ConsumerWidget {
  const RememberScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounters = ref.watch(encountersProvider);

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
        if (items.isEmpty) {
          return const FeaturePage(
            title: 'What you have recorded',
            description:
                'When something happens that you do not want to forget, record it.',
          );
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.md,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'What you have recorded',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    );
                  }

                  return EncounterListTile(encounter: items[index - 1]);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
