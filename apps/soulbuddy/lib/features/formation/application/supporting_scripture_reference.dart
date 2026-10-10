import 'package:flutter/foundation.dart';

/// A further-reading label resolved to the bundled RSVCE reader.
@immutable
class SupportingScriptureReference {
  const SupportingScriptureReference({
    required this.label,
    required this.book,
    required this.chapter,
    required this.firstVerse,
    required this.lastVerse,
  });

  final String label;
  final String book;
  final int chapter;
  final int? firstVerse;
  final int? lastVerse;

  static final _pattern = RegExp(
    r'^((?:[1-3] )?[A-Za-z]+(?: [A-Za-z]+)*) (\d+)(?::(\d+)(?:[–-](\d+))?)?$',
  );

  static const _books = <String, String>{
    'amos': 'Amos',
    'colossians': 'Col',
    'ephesians': 'Eph',
    'galatians': 'Gal',
    'hebrews': 'Heb',
    'isaiah': 'Isa',
    'james': 'James',
    'jeremiah': 'Jer',
    'john': 'John',
    'luke': 'Luke',
    'mark': 'Mark',
    'matthew': 'Matt',
    'micah': 'Mic',
    'psalm': 'Ps',
    'proverbs': 'Prov',
    'romans': 'Rom',
    '1 corinthians': '1 Cor',
    '1 john': '1 John',
    '1 peter': '1 Pet',
    '2 timothy': '2 Tim',
  };

  static SupportingScriptureReference? tryParse(String label) {
    final match = _pattern.firstMatch(label.trim());
    if (match == null) return null;
    final book = _books[match.group(1)!.toLowerCase()];
    final chapter = int.tryParse(match.group(2)!);
    if (book == null || chapter == null || chapter < 1) return null;
    final firstVerse = int.tryParse(match.group(3) ?? '');
    final lastVerse = int.tryParse(match.group(4) ?? '') ?? firstVerse;
    if ((firstVerse != null && firstVerse < 1) ||
        (lastVerse != null && lastVerse < firstVerse!)) {
      return null;
    }
    return SupportingScriptureReference(
      label: label,
      book: book,
      chapter: chapter,
      firstVerse: firstVerse,
      lastVerse: lastVerse,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SupportingScriptureReference &&
      other.label == label &&
      other.book == book &&
      other.chapter == chapter &&
      other.firstVerse == firstVerse &&
      other.lastVerse == lastVerse;

  @override
  int get hashCode => Object.hash(label, book, chapter, firstVerse, lastVerse);
}
