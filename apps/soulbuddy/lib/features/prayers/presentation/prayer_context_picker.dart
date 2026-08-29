import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/providers/encounter_providers.dart';
import '../../scripture/presentation/scripture_picker_sheet.dart';
import '../providers/personal_prayer_providers.dart';

abstract final class PrayerContextPicker {
  static Future<void> showEncounter(
    BuildContext context, {
    required String? requestId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _EncounterPicker(requestId: requestId),
    );
  }

  static Future<void> showScripture(
    BuildContext context, {
    required String? requestId,
  }) async {
    final selection = await showScripturePicker(context);
    if (selection == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await container
        .read(personalizedPrayerControllerProvider(requestId).notifier)
        .addScripture(
          book: selection.book,
          chapter: selection.chapter,
          firstVerse: selection.firstVerse,
          lastVerse: selection.lastVerse,
          passage: selection.passage,
        );
  }
}

class _EncounterPicker extends ConsumerWidget {
  const _EncounterPicker({required this.requestId});

  final String? requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounters = ref.watch(encountersProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose an Encounter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Private details stay hidden until selected.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: encounters.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Text('Encounters could not be opened just now.'),
                data: (items) => items.isEmpty
                    ? const Text('No Encounters have been recorded yet.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final encounter = items[index];
                          return ListTile(
                            minTileHeight: AppSpacing.minimumTouchTarget,
                            title: Text(encounter.title),
                            subtitle: Text(encounter.occurredOn),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () async {
                              await ref
                                  .read(
                                    personalizedPrayerControllerProvider(
                                      requestId,
                                    ).notifier,
                                  )
                                  .addEncounter(encounter);
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
