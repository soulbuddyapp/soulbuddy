import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/providers/encounter_providers.dart';
import '../../scripture/domain/scripture_passage.dart';
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
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ScripturePicker(requestId: requestId),
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

class _ScripturePicker extends ConsumerStatefulWidget {
  const _ScripturePicker({required this.requestId});

  final String? requestId;

  @override
  ConsumerState<_ScripturePicker> createState() => _ScripturePickerState();
}

class _ScripturePickerState extends ConsumerState<_ScripturePicker> {
  bool _loading = true;
  Object? _error;
  List<String> _books = const [];
  List<int> _chapters = const [];
  ScripturePassage? _chapter;
  String? _book;
  int? _chapterNumber;
  int? _firstVerse;
  int? _lastVerse;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final repository = ref.read(scriptureRepositoryProvider);
      final books = await repository.books();
      if (books.isEmpty) throw StateError('The Scripture catalog is empty.');
      _books = books;
      await _selectBook(books.first, notify: false);
    } on Object catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBook(String book, {bool notify = true}) async {
    if (notify) setState(() => _loading = true);
    try {
      final repository = ref.read(scriptureRepositoryProvider);
      final chapters = await repository.chapters(book);
      if (chapters.isEmpty) throw StateError('No chapters are available.');
      _book = book;
      _chapters = chapters;
      await _selectChapter(chapters.first, notify: false);
      _error = null;
    } on Object catch (error) {
      _error = error;
    } finally {
      if (notify && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectChapter(int chapter, {bool notify = true}) async {
    if (notify) setState(() => _loading = true);
    try {
      final passage = await ref
          .read(scriptureRepositoryProvider)
          .chapter(book: _book!, chapter: chapter);
      _chapterNumber = chapter;
      _chapter = passage;
      _firstVerse = passage.verses.first.number;
      _lastVerse = passage.verses.first.number;
      _error = null;
    } on Object catch (error) {
      _error = error;
    } finally {
      if (notify && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ScriptureUnavailable(onRetry: _loadBooks)
            : _buildChoices(context),
      ),
    );
  }

  Widget _buildChoices(BuildContext context) {
    final verses = _chapter!.verses;
    final allowedLastVerses = verses
        .where(
          (verse) =>
              verse.number >= _firstVerse! && verse.number <= _firstVerse! + 19,
        )
        .toList(growable: false);
    return ListView(
      shrinkWrap: true,
      children: [
        Text('Choose Scripture', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'RSVCE Â· Scripture. Choose up to 20 consecutive verses.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _book,
          decoration: const InputDecoration(labelText: 'Book'),
          items: [
            for (final book in _books)
              DropdownMenuItem(value: book, child: Text(book)),
          ],
          onChanged: (book) {
            if (book != null) _selectBook(book);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          initialValue: _chapterNumber,
          decoration: const InputDecoration(labelText: 'Chapter'),
          items: [
            for (final chapter in _chapters)
              DropdownMenuItem(value: chapter, child: Text('$chapter')),
          ],
          onChanged: (chapter) {
            if (chapter != null) _selectChapter(chapter);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _firstVerse,
                decoration: const InputDecoration(labelText: 'First verse'),
                items: [
                  for (final verse in verses)
                    DropdownMenuItem(
                      value: verse.number,
                      child: Text('${verse.number}'),
                    ),
                ],
                onChanged: (verse) {
                  if (verse == null) return;
                  setState(() {
                    _firstVerse = verse;
                    if (_lastVerse! < verse || _lastVerse! > verse + 19) {
                      _lastVerse = verse;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('last-$_firstVerse'),
                initialValue: _lastVerse,
                decoration: const InputDecoration(labelText: 'Last verse'),
                items: [
                  for (final verse in allowedLastVerses)
                    DropdownMenuItem(
                      value: verse.number,
                      child: Text('${verse.number}'),
                    ),
                ],
                onChanged: (verse) => setState(() => _lastVerse = verse),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          verses
              .where(
                (verse) =>
                    verse.number >= _firstVerse! && verse.number <= _lastVerse!,
              )
              .map((verse) => '${verse.number}  ${verse.text}')
              .join('\n\n'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _addPassage, child: const Text('Add passage')),
      ],
    );
  }

  Future<void> _addPassage() async {
    setState(() => _loading = true);
    try {
      final passage = await ref
          .read(scriptureRepositoryProvider)
          .verses(
            book: _book!,
            chapter: _chapterNumber!,
            firstVerse: _firstVerse!,
            lastVerse: _lastVerse!,
          );
      await ref
          .read(personalizedPrayerControllerProvider(widget.requestId).notifier)
          .addScripture(
            book: _book!,
            chapter: _chapterNumber!,
            firstVerse: _firstVerse!,
            lastVerse: _lastVerse!,
            passage: passage,
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _ScriptureUnavailable extends StatelessWidget {
  const _ScriptureUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Scripture could not be opened just now.'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
