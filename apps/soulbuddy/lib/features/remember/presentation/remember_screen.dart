import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../../core/presentation/feature_page.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import '../../record/providers/encounter_providers.dart';
import '../presentation/daily_remembrance_card.dart';
import '../providers/daily_memory_providers.dart';
import 'encounter_list_tile.dart';
import 'forget_quickly_card.dart';

class RememberScreen extends ConsumerStatefulWidget {
  const RememberScreen({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  ConsumerState<RememberScreen> createState() => _RememberScreenState();
}

class _RememberScreenState extends ConsumerState<RememberScreen> {
  var _query = '';
  late var _filter = switch (widget.initialFilter) {
    'altar' => _RememberFilter.altar,
    'voice' => _RememberFilter.voice,
    _ => _RememberFilter.all,
  };

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
              if (_filter == _RememberFilter.altar && !item.isAltar) {
                return false;
              }
              if (_filter == _RememberFilter.voice &&
                  ref.watch(memoryAudioForEncounterProvider(item.id)).value ==
                      null) {
                return false;
              }
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
                itemCount: filtered.length + 6,
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

                  if (index == 5) {
                    return Semantics(
                      label: 'Filter Memories',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          ChoiceChip(
                            key: const Key('remember-filter-all'),
                            label: const Text('All'),
                            selected: _filter == _RememberFilter.all,
                            onSelected: (_) =>
                                setState(() => _filter = _RememberFilter.all),
                          ),
                          ChoiceChip(
                            key: const Key('remember-filter-altar'),
                            label: const Text('At my Altar'),
                            selected: _filter == _RememberFilter.altar,
                            onSelected: (_) =>
                                setState(() => _filter = _RememberFilter.altar),
                          ),
                          ChoiceChip(
                            key: const Key('remember-filter-voice'),
                            label: const Text('Voice'),
                            selected: _filter == _RememberFilter.voice,
                            onSelected: (_) =>
                                setState(() => _filter = _RememberFilter.voice),
                          ),
                        ],
                      ),
                    );
                  }

                  return EncounterListTile(encounter: filtered[index - 6]);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _RememberFilter { all, altar, voice }

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
              const SizedBox(height: AppSpacing.md),
              const CovenantIncisedDivider(key: Key('remember-incised-mark')),
              const SizedBox(height: AppSpacing.md),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CaptureButtons(),
                      SizedBox(height: AppSpacing.md),
                      ForgetQuicklyCard(expanded: true),
                    ],
                  ),
                ),
              ),
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
  Widget build(BuildContext context) =>
      const InlineMemoryRecorder(buttonKey: Key('remember-speak'));
}
