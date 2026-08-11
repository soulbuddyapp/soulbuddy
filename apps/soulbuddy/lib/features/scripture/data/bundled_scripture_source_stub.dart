import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) {
  throw const ScriptureSourceUnavailable();
}

Future<List<String>> loadBundledBooks() {
  throw const ScriptureSourceUnavailable();
}

Future<List<int>> loadBundledChapters({required String book}) {
  throw const ScriptureSourceUnavailable();
}

Future<ScripturePassage> loadBundledVerses({
  required String book,
  required int chapter,
  required int firstVerse,
  required int lastVerse,
}) {
  throw const ScriptureSourceUnavailable();
}
