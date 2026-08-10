class ScripturePassage {
  const ScripturePassage({required this.reference, required this.verses});

  final String reference;
  final List<ScriptureVerse> verses;
}

class ScriptureVerse {
  const ScriptureVerse({required this.number, required this.text});

  final int number;
  final String text;
}
