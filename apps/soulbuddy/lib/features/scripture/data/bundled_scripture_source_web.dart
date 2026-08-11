import 'package:flutter/services.dart';
import 'package:sqlite3/wasm.dart';

import '../../../core/async/retryable_future_cache.dart';
import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';

final _repository = RetryableFutureCache<_WebScriptureRepository>();

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) async {
  try {
    final repository = await _repository.get(_openRepository);
    return repository.chapter(book: book, chapter: chapter);
  } on ScriptureReferenceNotFound {
    rethrow;
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}

Future<List<String>> loadBundledBooks() async {
  try {
    return (await _repository.get(_openRepository)).books();
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}

Future<List<int>> loadBundledChapters({required String book}) async {
  try {
    return (await _repository.get(_openRepository)).chapters(book);
  } on ScriptureReferenceNotFound {
    rethrow;
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}

Future<ScripturePassage> loadBundledVerses({
  required String book,
  required int chapter,
  required int firstVerse,
  required int lastVerse,
}) async {
  try {
    return (await _repository.get(_openRepository)).verses(
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
    );
  } on ScriptureReferenceNotFound {
    rethrow;
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}

Future<_WebScriptureRepository> _openRepository() async {
  final asset = await rootBundle.load('assets/scripture/rsvce.db');
  final bytes = Uint8List.sublistView(asset);
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  final fileSystem = InMemoryFileSystem(name: 'soulbuddy-scripture');
  final opened = fileSystem.xOpen(
    Sqlite3Filename('/rsvce.db'),
    SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE,
  );
  opened.file.xWrite(bytes, 0);
  opened.file.xClose();
  sqlite.registerVirtualFileSystem(fileSystem);

  final database = sqlite.open(
    '/rsvce.db',
    mode: OpenMode.readOnly,
    vfs: fileSystem.name,
  );
  return _WebScriptureRepository(database);
}

class _WebScriptureRepository {
  const _WebScriptureRepository(this.database);

  static const _bookAliases = <String, String>{
    'jn': 'John',
    'mt': 'Matt',
    'mk': 'Mark',
    'lk': 'Luke',
  };

  final CommonDatabase database;

  List<String> books() => List.unmodifiable(
    database
        .select('SELECT text FROM books ORDER BY _id')
        .map((row) => (row['text'] as String).trim()),
  );

  List<int> chapters(String book) {
    final row = _findBook(book);
    return List.unmodifiable(
      database
          .select(
            '''
            SELECT DISTINCT chapter_id FROM verses
            WHERE book_id = ? ORDER BY chapter_id
            ''',
            [row['_id']],
          )
          .map((item) => item['chapter_id'] as int),
    );
  }

  ScripturePassage chapter({required String book, required int chapter}) {
    return _load(book: book, chapter: chapter);
  }

  ScripturePassage verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) {
    if (firstVerse < 1 || lastVerse < firstVerse) {
      throw ArgumentError('Verse bounds must be positive and ordered.');
    }
    return _load(
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
    );
  }

  ScripturePassage _load({
    required String book,
    required int chapter,
    int? firstVerse,
    int? lastVerse,
  }) {
    if (chapter < 1) throw ArgumentError.value(chapter, 'chapter');
    final bookRow = _findBook(book);
    final bookId = bookRow['_id'] as int;
    final bookName = bookRow['text'] as String;
    final parameters = <Object?>[bookId, chapter];
    final bounds = firstVerse == null ? '' : 'AND verse_id BETWEEN ? AND ?';
    if (firstVerse != null) parameters.addAll([firstVerse, lastVerse]);
    final rows = database.select('''
      SELECT verse_id, text FROM verses
      WHERE book_id = ? AND chapter_id = ? $bounds
      ORDER BY verse_id
      ''', parameters);
    if (rows.isEmpty) {
      throw ScriptureReferenceNotFound('$book $chapter');
    }
    final reference = switch ((firstVerse, lastVerse)) {
      (null, null) => '$bookName $chapter',
      (final int first, final int last) when first == last =>
        '$bookName $chapter:$first',
      (final int first, final int last) => '$bookName $chapter:$firstâ€“$last',
      _ => '$bookName $chapter',
    };
    return ScripturePassage(
      reference: reference,
      verses: rows
          .map(
            (row) => ScriptureVerse(
              number: row['verse_id'] as int,
              text: (row['text'] as String).trim(),
            ),
          )
          .toList(growable: false),
    );
  }

  Row _findBook(String book) {
    final normalized = _bookAliases[book.trim().toLowerCase()] ?? book.trim();
    final rows = database.select(
      '''
      SELECT _id, text FROM books
      WHERE lower(shortname) = lower(?) OR lower(text) = lower(?)
      LIMIT 1
      ''',
      [normalized, normalized],
    );
    if (rows.isEmpty) {
      throw ScriptureReferenceNotFound(book);
    }
    return rows.single;
  }
}
