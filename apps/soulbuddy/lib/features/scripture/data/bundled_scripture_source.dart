import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';
import 'bundled_scripture_source_stub.dart'
    if (dart.library.io) 'bundled_scripture_source_io.dart'
    if (dart.library.js_interop) 'bundled_scripture_source_web.dart'
    as platform;

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) {
  return platform.loadBundledChapter(book: book, chapter: chapter);
}

class BundledScriptureRepository implements ScriptureRepository {
  const BundledScriptureRepository();

  @override
  Future<List<String>> books() => platform.loadBundledBooks();

  @override
  Future<List<int>> chapters(String book) =>
      platform.loadBundledChapters(book: book);

  @override
  Future<ScripturePassage> chapter({
    required String book,
    required int chapter,
  }) => platform.loadBundledChapter(book: book, chapter: chapter);

  @override
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  }) => platform.loadBundledVerses(
    book: book,
    chapter: chapter,
    firstVerse: firstVerse,
    lastVerse: lastVerse,
  );
}
