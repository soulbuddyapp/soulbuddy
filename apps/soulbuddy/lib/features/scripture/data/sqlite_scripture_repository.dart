import 'package:sqlite3/sqlite3.dart';

import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';

class SqliteScriptureRepository implements ScriptureRepository {
  SqliteScriptureRepository._(this._database);

  static const _bookAliases = <String, String>{
    'jn': 'John',
    'mt': 'Matt',
    'mk': 'Mark',
    'lk': 'Luke',
  };

  final Database _database;

  static SqliteScriptureRepository open(String path) {
    try {
      return SqliteScriptureRepository._(
        sqlite3.open(path, mode: OpenMode.readOnly),
      );
    } on Object catch (error) {
      throw ScriptureSourceUnavailable(error);
    }
  }

  @override
  Future<ScripturePassage> chapter({
    required String book,
    required int chapter,
  }) {
    return _load(book: book, chapter: chapter);
  }

  @override
  Future<ScripturePassage> verses({
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

  Future<ScripturePassage> _load({
    required String book,
    required int chapter,
    int? firstVerse,
    int? lastVerse,
  }) async {
    if (chapter < 1) throw ArgumentError.value(chapter, 'chapter');

    final normalized = _bookAliases[book.trim().toLowerCase()] ?? book.trim();
    final books = _database.select(
      '''
      SELECT _id, text, shortname
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
    final parameters = <Object?>[bookId, chapter];
    final bounds = firstVerse == null ? '' : 'AND verse_id BETWEEN ? AND ?';
    if (firstVerse != null) parameters.addAll([firstVerse, lastVerse]);

    final rows = _database.select('''
      SELECT verse_id, text
      FROM verses
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
      (final int first, final int last) => '$bookName $chapter:$first–$last',
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

  void close() => _database.dispose();
}
