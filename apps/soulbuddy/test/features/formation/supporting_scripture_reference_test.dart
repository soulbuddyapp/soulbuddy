import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/formation/application/supporting_scripture_reference.dart';

void main() {
  test('parses a supported further-reading range for the bundled reader', () {
    expect(
      SupportingScriptureReference.tryParse('Psalm 51:1–12'),
      const SupportingScriptureReference(
        label: 'Psalm 51:1–12',
        book: 'Ps',
        chapter: 51,
        firstVerse: 1,
        lastVerse: 12,
      ),
    );
  });

  test('preserves a supported whole-chapter reference', () {
    expect(
      SupportingScriptureReference.tryParse('John 14'),
      const SupportingScriptureReference(
        label: 'John 14',
        book: 'John',
        chapter: 14,
        firstVerse: null,
        lastVerse: null,
      ),
    );
  });

  test('does not create a broken link for an unknown reference', () {
    expect(SupportingScriptureReference.tryParse('A prayerful pause'), isNull);
  });
}
