import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Counts occurrences of a constructor call in a source file.
int _calls(String path, String needle) {
  final source = File(path).readAsStringSync();
  var count = 0;
  var index = source.indexOf(needle);
  while (index != -1) {
    count++;
    index = source.indexOf(needle, index + needle.length);
  }
  return count;
}

/// Every converted say-something surface, with how many sayable and how many
/// bare text fields it should still hold. A bare count that grows means a
/// sentence field has lost its affordance; a sayable count that drops means one
/// has gone back to being a plain field.
///
/// Counts are measured, not assumed, so a file that legitimately gained or lost
/// a field of its own is recorded here rather than left to fail.
const _expected = <String, (int sayable, int bare)>{
  'lib/features/commitments/presentation/commitment_journey_screen.dart': (
    1,
    1,
  ),
  'lib/features/onboarding/presentation/first_prayer_speech_page.dart': (1, 0),
};

void main() {
  _expected.forEach((path, expected) {
    test(
      '$path keeps ${expected.$1} sayable and ${expected.$2} bare fields',
      () {
        expect(
          _calls(path, 'SayableField('),
          expected.$1,
          reason: '$path should hold ${expected.$1} sayable fields',
        );
        expect(
          _calls(path, 'TextField('),
          expected.$2,
          reason: '$path should hold ${expected.$2} bare text fields',
        );
      },
    );
  });
}
