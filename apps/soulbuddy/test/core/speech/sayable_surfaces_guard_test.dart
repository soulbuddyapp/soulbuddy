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

/// Counts the fields a person types into without speaking: both
/// [TextField] and [TextFormField], neither of which contains the other.
int _bareFields(String path) =>
    _calls(path, 'TextField(') + _calls(path, 'TextFormField(');

/// Every converted say-something surface, with how many sayable and how many
/// bare text fields it should still hold. A bare count that grows means a
/// sentence field has lost its affordance; a sayable count that drops means one
/// has gone back to being a plain field.
///
/// A bare field is either kind of input: a [TextField] or a [TextFormField] are
/// both a sentence field without a mic, and counting only one of them would let
/// the other appear anywhere without the guard noticing.
///
/// Counts are measured, not assumed, so a file that legitimately gained or lost
/// a field of its own is recorded here rather than left to fail.
const _expected = <String, (int sayable, int bare)>{
  'lib/features/commitments/presentation/commitment_journey_screen.dart': (
    1,
    1,
  ),
  'lib/features/onboarding/presentation/first_prayer_speech_page.dart': (1, 0),
  'lib/features/daily_formation/presentation/daily_formation_card.dart': (2, 0),
  'lib/features/record/presentation/encounter_form.dart': (2, 1),
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
          _bareFields(path),
          expected.$2,
          reason: '$path should hold ${expected.$2} bare text fields',
        );
      },
    );
  });

  test('the bare count does not mistake one input kind for the other', () {
    // The helper's whole job is to notice a sentence field that has lost its
    // mic, so it has to see both kinds of input. `TextFormField(` does not
    // contain `TextField(` as a substring, which is exactly why the second kind
    // used to go uncounted: a guard that read zero bare fields while a form
    // field sat in the file was not looking at all.
    expect(_calls('lib/core/speech/sayable_field.dart', 'TextField('), 1);
    expect(_calls('lib/core/speech/sayable_field.dart', 'TextFormField('), 1);
    expect(_bareFields('lib/core/speech/sayable_field.dart'), 2);
  });
}
