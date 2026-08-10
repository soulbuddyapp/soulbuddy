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

  ScripturePassage chapter({required String book, required int chapter}) {
    if (chapter < 1) throw ArgumentError.value(chapter, 'chapter');
    final normalized = _bookAliases[book.trim().toLowerCase()] ?? book.trim();
    final books = database.select(
      '''
      SELECT _id, text
      FROM books
      WHERE lower(shortname) = lower(?) OR lower(text) = lower(?)
      LIMIT 1
      ''',
      [normalized, normalized],
    );
    if (books.isEmpty) {
      throw ScriptureReferenceNotFound('$book $chapter');
    }

    final bookRow = books.single;
    final bookId = bookRow['_id'] as int;
    final bookName = bookRow['text'] as String;
    final rows = database.select(
      '''
      SELECT verse_id, text
      FROM verses
      WHERE book_id = ? AND chapter_id = ?
      ORDER BY verse_id
      ''',
      [bookId, chapter],
    );
    if (rows.isEmpty) {
      throw ScriptureReferenceNotFound('$book $chapter');
    }

    return ScripturePassage(
      reference: '$bookName $chapter',
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
}
