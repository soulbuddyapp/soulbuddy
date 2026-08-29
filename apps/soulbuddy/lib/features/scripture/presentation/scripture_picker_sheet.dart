import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/scripture_passage.dart';
import '../providers/scripture_providers.dart';

class ScriptureSelection {
  const ScriptureSelection({
    required this.translation,
    required this.book,
    required this.chapter,
    required this.firstVerse,
    required this.lastVerse,
    required this.passage,
  });

  final String translation;
  final String book;
  final int chapter;
  final int firstVerse;
  final int lastVerse;
  final ScripturePassage passage;

  String get reference {
    final verses = firstVerse == lastVerse
        ? '$firstVerse'
        : '$firstVerse-$lastVerse';
    return '$book $chapter:$verses';
  }
}

Future<ScriptureSelection?> showScripturePicker(BuildContext context) {
  return showModalBottomSheet<ScriptureSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const ScripturePickerSheet(),
  );
}

class ScripturePickerSheet extends ConsumerStatefulWidget {
  const ScripturePickerSheet({super.key});

  @override
  ConsumerState<ScripturePickerSheet> createState() =>
      _ScripturePickerSheetState();
}

class _ScripturePickerSheetState extends ConsumerState<ScripturePickerSheet> {
  static const _translation = 'RSVCE';

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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
    if (notify && mounted) setState(() => _loading = true);
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
    if (notify && mounted) setState(() => _loading = true);
    try {
      final passage = await ref
          .read(scriptureRepositoryProvider)
          .chapter(book: _book!, chapter: chapter);
      if (passage.verses.isEmpty) {
        throw StateError('No verses are available.');
      }
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
    final stackVerseFields =
        MediaQuery.sizeOf(context).width < 420 ||
        MediaQuery.textScalerOf(context).scale(14) >= 21;

    final firstVerseField = DropdownButtonFormField<int>(
      key: const Key('scripture-picker-first-verse'),
      initialValue: _firstVerse,
      decoration: const InputDecoration(labelText: 'First verse'),
      items: [
        for (final verse in verses)
          DropdownMenuItem(value: verse.number, child: Text('${verse.number}')),
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
    );
    final lastVerseField = DropdownButtonFormField<int>(
      key: ValueKey('scripture-picker-last-verse-$_firstVerse'),
      initialValue: _lastVerse,
      decoration: const InputDecoration(labelText: 'Last verse'),
      items: [
        for (final verse in allowedLastVerses)
          DropdownMenuItem(value: verse.number, child: Text('${verse.number}')),
      ],
      onChanged: (verse) => setState(() => _lastVerse = verse),
    );

    return ListView(
      shrinkWrap: true,
      children: [
        Text('Choose Scripture', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$_translation · Scripture. Choose up to 20 consecutive verses.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: const Key('scripture-picker-book'),
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
          key: const Key('scripture-picker-chapter'),
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
        if (stackVerseFields) ...[
          firstVerseField,
          const SizedBox(height: AppSpacing.md),
          lastVerseField,
        ] else
          Row(
            children: [
              Expanded(child: firstVerseField),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: lastVerseField),
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
        FilledButton(
          key: const Key('scripture-picker-choose'),
          onPressed: _choose,
          child: const Text('Choose passage'),
        ),
      ],
    );
  }

  Future<void> _choose() async {
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
      if (!mounted) return;
      Navigator.pop(
        context,
        ScriptureSelection(
          translation: _translation,
          book: _book!,
          chapter: _chapterNumber!,
          firstVerse: _firstVerse!,
          lastVerse: _lastVerse!,
          passage: passage,
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
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
