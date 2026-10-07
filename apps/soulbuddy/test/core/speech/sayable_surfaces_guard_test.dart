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
  'lib/features/prayers/presentation/prayer_create_screen.dart': (1, 0),
  'lib/features/onboarding/presentation/first_prayer_detail_page.dart': (1, 0),
  'lib/features/onboarding/presentation/first_remembrance_page.dart': (1, 0),
  // Day and Minutes are dropdowns, not sentence fields, so nothing here is left
  // bare: the Notebook is the screen's only field.
  'lib/features/goals/presentation/goal_meditation_screen.dart': (1, 0),
  'lib/features/goals/presentation/daily_practice_sheet.dart': (1, 0),
  'lib/features/goals/presentation/today_prayer_goal_migration_card.dart': (
    1,
    0,
  ),
  // One component behind all six of this screen's labels, not six fields.
  'lib/features/goals/presentation/first_goal_screen.dart': (1, 0),
  // The Goal field labels a row in the list and stays bare.
  'lib/features/goals/presentation/goal_detail_screen.dart': (2, 1),
  'lib/features/remember/presentation/daily_remembrance_screen.dart': (1, 0),
  'lib/features/remember/presentation/memory_detail_screen.dart': (1, 0),
  'lib/features/guards/presentation/guard_configuration_sheet.dart': (1, 0),
  // Circle name and the provider group link stay bare; Category and Visibility
  // are dropdowns and were never sentence fields.
  'lib/features/circles/presentation/create_circle_sheet.dart': (1, 2),
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

  test('a screen that shares one field across labels still counts one', () {
    // `first_goal_screen` passes six different `hintText` values to a single
    // field component. The guard counts constructor calls in source, so the
    // honest figure is one sayable field, not six — and a second call
    // accidentally introduced while converting it would show up here rather
    // than as a row that quietly stops meaning anything.
    expect(
      _calls(
        'lib/features/goals/presentation/first_goal_screen.dart',
        'SayableField(',
      ),
      1,
    );
    expect(
      _calls(
        'lib/features/goals/presentation/first_goal_screen.dart',
        'hintText: widget.hintText,',
      ),
      1,
    );
  });

  test('no sayable surface still spells its own speech plumbing', () {
    // The seam is the whole point of `SayableField`: one recogniser, one
    // controller, one place that asks for the microphone. A surface that names
    // either again is a second seam wearing the first one's clothes, and the
    // counts above would not notice, because it only counts fields.
    for (final path in _expected.keys) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('SpeechToText') || source.contains('onDevice'),
        isFalse,
        reason: '$path must go through SayableField, not its own recogniser',
      );
    }
  });

  test('a field left bare on purpose is still counted as bare', () {
    // Two screens keep a field bare for a reason rather than by accident:
    // `goal_detail_screen` keeps Goal, which labels a row in the list, and
    // `create_circle_sheet` keeps the Circle name, a slot. Both are counted
    // here as well as in `_expected`, so that a bare field quietly gaining a
    // microphone — or a sayable one quietly losing one — is a visible change
    // rather than a row that stops meaning anything.
    expect(
      _bareFields('lib/features/goals/presentation/goal_detail_screen.dart'),
      1,
    );
    expect(
      _bareFields('lib/features/circles/presentation/create_circle_sheet.dart'),
      2,
    );
    expect(
      _calls(
        'lib/features/circles/presentation/create_circle_sheet.dart',
        'SayableField(',
      ),
      1,
    );
  });

  test('a screen with several fields says the notice once', () {
    // Sixteen surfaces use `SayableField` and only three hold more than one
    // field. On those three the unavailable notice used to be said by every
    // field, which put two identical sentences on one screen and worked
    // against the app's restraint.
    //
    // Derived from the counts above rather than listed per file, so it cannot
    // go stale: a surface that gains a second field must silence one of them,
    // and a screen with one field must not silence it at all. Nothing has to
    // remember to update this when the fields change, which is what makes the
    // opt-out safe to hand to a caller who has never heard of it.
    final several = _expected.entries.where((entry) => entry.value.$1 > 1);
    expect(
      several.map((entry) => entry.key),
      [
        'lib/features/daily_formation/presentation/daily_formation_card.dart',
        'lib/features/record/presentation/encounter_form.dart',
        'lib/features/goals/presentation/goal_detail_screen.dart',
      ],
      reason: 'a surface holding several fields is the only case this is for',
    );
    for (final entry in _expected.entries) {
      expect(
        _calls(entry.key, 'showUnavailableNotice: false'),
        entry.value.$1 > 1 ? entry.value.$1 - 1 : 0,
        reason:
            '${entry.key} holds ${entry.value.$1} sayable field(s), so it '
            'silences exactly one notice or none',
      );
    }
  });
}
