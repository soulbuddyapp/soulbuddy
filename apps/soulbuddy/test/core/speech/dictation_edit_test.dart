import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/dictation_edit.dart';

void main() {
  test('keeps text typed before dictation started', () {
    // Thirteen characters, so the caret goes past the last one. Landing on 12
    // would split the final 'l' off the word and merge the dictated words in
    // the middle of it.
    final edit = DictationEdit.begin('I am grateful', caret: 13);

    expect(edit.apply(' for today'), 'I am grateful for today');
  });

  test('keeps text after the caret', () {
    final edit = DictationEdit.begin('beforeafter', caret: 6);

    expect(edit.apply('middle'), 'beforemiddleafter');
  });

  test('inserts no space the recogniser did not say', () {
    expect(DictationEdit.begin('', caret: 0).apply('Amen.'), 'Amen.');
    expect(DictationEdit.begin('', caret: 0).apply('one two'), 'one two');
    expect(
      DictationEdit.begin('Grace', caret: 5).apply(' peace'),
      'Grace peace',
    );
  });

  test('revises partial results rather than accumulating them', () {
    final edit = DictationEdit.begin('', caret: 0);

    expect(edit.apply('I pr'), 'I pr');
    expect(edit.apply('I pray'), 'I pray');
    expect(edit.apply('I pray for'), 'I pray for');
  });

  test('starts again from the caret on a second session', () {
    final first = DictationEdit.begin('Grace', caret: 5)..apply(' and peace');
    final second = DictationEdit.begin(first.value, caret: first.value.length)
      ..apply(' Amen');

    expect(second.value, 'Grace and peace Amen');
  });

  test('truncates on a rune boundary without splitting a character', () {
    final edit = DictationEdit.begin('', caret: 0, maxLength: 3);

    expect(edit.apply('naïve prayer'), 'naï');
  });

  test('a character outside the basic plane is not cut in half', () {
    // Six code units here are five characters plus a surrogate pair, so cutting
    // by code unit would leave a half character behind.
    final edit = DictationEdit.begin('', caret: 0, maxLength: 6);

    expect(edit.apply('naïve🙂 prayer'), 'naïve🙂');
  });

  test('truncation is reported, never silent', () {
    final edit = DictationEdit.begin('', caret: 0, maxLength: 4);
    expect(edit.truncated, isFalse);

    // Exactly the limit is not truncation: the words fit whole.
    edit.apply('amen');
    expect(edit.truncated, isFalse);

    edit.apply('far too long');
    expect(edit.truncated, isTrue);
  });

  group('the field is not touched until the recogniser speaks', () {
    test('and the caret starts where dictation began', () {
      final edit = DictationEdit.begin('beforeafter', caret: 6);

      expect(edit.value, 'beforeafter');
      expect(edit.caretOffset, 6);
    });

    test('and a caret past the end of the text is the end of the text', () {
      final edit = DictationEdit.begin('Amen', caret: 99);

      expect(edit.apply(' now'), 'Amen now');
      expect(edit.caretOffset, 8);
    });
  });

  group('caret placement', () {
    test('sits after the dictated words, before the text kept after them', () {
      final edit = DictationEdit.begin('beforeafter', caret: 6)..apply('X');

      expect(edit.value, 'beforeXafter');
      expect(edit.caretOffset, 7);
    });

    test('counts a character outside the basic plane once, not twice', () {
      final edit = DictationEdit.begin('🙂', caret: 2)..apply('Amen');

      expect(edit.value, '🙂Amen');
      expect(edit.caretOffset, 6);
    });

    test('stays inside a field the limit has already cut short', () {
      final edit = DictationEdit.begin('', caret: 0, maxLength: 3)
        ..apply('naïve prayer');

      expect(edit.caretOffset, edit.value.length);
    });
  });

  group('a result left over from the session it replaced', () {
    // A stopped session's final result arrives stamped with the session that
    // replaced it, so the token that fenced it out has already let it through.
    // Those words are already in the field, so applying them repeats them.
    DictationEdit restarted(String superseded) {
      final stopped = DictationEdit.begin('Grace', caret: 5)..apply(superseded);
      return DictationEdit.begin(
        stopped.value,
        caret: stopped.caretOffset,
        superseded: superseded,
      );
    }

    test('is ignored, leaving the field as dictation found it', () {
      final edit = restarted('Amen');

      expect(
        edit.apply('Amen for you'),
        'GraceAmen',
        reason: 'the stopped session already put these words in the field',
      );
      expect(edit.caretOffset, 9, reason: 'the caret has not moved');
      expect(edit.truncated, isFalse);
    });

    test('is ignored in a field that keeps text after the caret', () {
      final stopped = DictationEdit.begin('beforeafter', caret: 6)..apply('X');
      final edit = DictationEdit.begin(
        stopped.value,
        caret: stopped.caretOffset,
        superseded: 'X',
      );

      expect(edit.apply('X'), 'beforeXafter');
    });

    test('is only ever ignored as the first callback of the session', () {
      final edit = restarted('Amen')..apply('Amen');

      expect(
        edit.apply('Amen for you'),
        'GraceAmenAmen for you',
        reason: 'later callbacks are the session speaking, and are trusted',
      );
    });

    test('does not stop a session whose words do not carry it', () {
      final edit = DictationEdit.begin('Grace', caret: 5, superseded: 'Amen');

      expect(edit.apply(' and peace'), 'Grace and peace');
    });
  });
}
