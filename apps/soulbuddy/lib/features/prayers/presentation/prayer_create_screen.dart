import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../editorial/data/editorial_prayer_repository.dart';
import '../../onboarding/presentation/first_prayer_speech_page.dart';
import '../domain/library_prayer.dart';
import '../providers/personal_prayer_providers.dart';
import '../providers/prayer_providers.dart';
import 'prayer_library_tile.dart';

class PrayerCreateScreen extends ConsumerStatefulWidget {
  const PrayerCreateScreen({super.key});

  @override
  ConsumerState<PrayerCreateScreen> createState() => _PrayerCreateScreenState();
}

class _PrayerCreateScreenState extends ConsumerState<PrayerCreateScreen> {
  final _wordsController = TextEditingController();
  PrayerPurpose? _purpose;
  _OwnWordsMode? _ownWordsMode;
  var _saving = false;

  @override
  void dispose() {
    _wordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ownWordsMode == _OwnWordsMode.speak) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: FirstPrayerSpeechPage(
            heading: 'Speak your prayer',
            description: 'Say your prayer in your own words.',
            continueLabel: 'Keep my words',
            hintText: 'Your words will appear here',
            fieldKey: const Key('prayer-create-spoken-words'),
            onContinue: _saveOwnWords,
            onWriteInstead: () =>
                setState(() => _ownWordsMode = _OwnWordsMode.write),
            onSkip: () => setState(() => _ownWordsMode = null),
          ),
        ),
      );
    }

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
                  'Choose a reviewed prayer or use your own words.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                                _ownWordsMode = null;
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('prayer-create-write'),
                        onPressed: _saving
                            ? null
                            : () => setState(
                                () => _ownWordsMode = _OwnWordsMode.write,
                              ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Write'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('prayer-create-speak'),
                        onPressed: _saving
                            ? null
                            : () => setState(
                                () => _ownWordsMode = _OwnWordsMode.speak,
                              ),
                        icon: const Icon(Icons.mic_none),
                        label: const Text('Speak'),
                      ),
                    ],
                  ),
                  if (_ownWordsMode == _OwnWordsMode.write) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('prayer-create-own-words'),
                      controller: _wordsController,
                      autofocus: true,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write your prayer in your own words.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _wordsController,
                      builder: (context, value, child) => FilledButton(
                        key: const Key('prayer-create-save-own-words'),
                        onPressed: _saving || value.text.trim().isEmpty
                            ? null
                            : () => _saveOwnWords(value.text),
                        child: Text(_saving ? 'Keeping…' : 'Keep my words'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveOwnWords(String words) async {
    final purpose = _purpose;
    final body = words.trim();
    if (purpose == null || body.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(
        personalPrayerRepositoryProvider.future,
      );
      final prayer = await repository.createOwnWords(
        title: 'My prayer · ${prayerPurposeLabel(purpose)}',
        body: body,
        purpose: purpose,
      );
      if (mounted) context.go('/prayers/saved/${prayer.id}');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your prayer could not be saved just now.'),
          ),
        );
      }
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
              Text(
                prayer.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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

enum _OwnWordsMode { write, speak }
