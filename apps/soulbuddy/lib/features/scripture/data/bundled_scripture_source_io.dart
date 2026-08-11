import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';
import 'sqlite_scripture_repository.dart';

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) => _withRepository(
  (repository) => repository.chapter(book: book, chapter: chapter),
);

Future<List<String>> loadBundledBooks() =>
    _withRepository((repository) => repository.books());

Future<List<int>> loadBundledChapters({required String book}) =>
    _withRepository((repository) => repository.chapters(book));

Future<ScripturePassage> loadBundledVerses({
  required String book,
  required int chapter,
  required int firstVerse,
  required int lastVerse,
}) => _withRepository(
  (repository) => repository.verses(
    book: book,
    chapter: chapter,
    firstVerse: firstVerse,
    lastVerse: lastVerse,
  ),
);

Future<T> _withRepository<T>(
  Future<T> Function(SqliteScriptureRepository repository) operation,
) async {
  try {
    final directory = await getApplicationSupportDirectory();
    final databaseFile = File(path_helper.join(directory.path, 'rsvce-v1.db'));
    if (!databaseFile.existsSync()) {
      final asset = await rootBundle.load('assets/scripture/rsvce.db');
      final bytes = Uint8List.sublistView(asset);
      await databaseFile.writeAsBytes(bytes, flush: true);
    }

    final repository = SqliteScriptureRepository.open(databaseFile.path);
    try {
      return await operation(repository);
    } finally {
      repository.close();
    }
  } on ScriptureReferenceNotFound {
    rethrow;
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}
