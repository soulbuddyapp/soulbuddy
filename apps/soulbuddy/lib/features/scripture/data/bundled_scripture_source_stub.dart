import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) {
  throw const ScriptureSourceUnavailable();
}
