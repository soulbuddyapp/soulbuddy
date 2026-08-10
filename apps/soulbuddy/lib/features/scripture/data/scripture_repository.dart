import '../domain/scripture_passage.dart';

abstract interface class ScriptureRepository {
  Future<ScripturePassage> chapter({
    required String book,
    required int chapter,
  });

  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  });
}

class ScriptureReferenceNotFound implements Exception {
  const ScriptureReferenceNotFound(this.reference);

  final String reference;

  @override
  String toString() => 'Scripture reference not found: $reference';
}

class ScriptureSourceUnavailable implements Exception {
  const ScriptureSourceUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'The local Scripture source is unavailable.';
}
