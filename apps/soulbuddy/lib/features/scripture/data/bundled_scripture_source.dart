import '../domain/scripture_passage.dart';
import 'bundled_scripture_source_stub.dart'
    if (dart.library.io) 'bundled_scripture_source_io.dart'
    as platform;

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) {
  return platform.loadBundledChapter(book: book, chapter: chapter);
}
