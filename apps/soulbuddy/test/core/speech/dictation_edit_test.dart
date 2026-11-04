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

  group('the caret dictation began at', () {
    test('is the start of the text when given a negative offset', () {
      final edit = DictationEdit.begin('Amen', caret: -4)..apply(' now');

      expect(
        edit.value,
        ' nowAmen',
        reason: 'the offset is clamped rather than trusted',
      );
      expect(edit.caretOffset, 4);
    });

    test('is moved off the middle of a surrogate pair', () {
      // A caret inside a character would split it into two halves in the
      // merged field, which no text field can show.
      final edit = DictationEdit.begin('🙂Amen', caret: 1)..apply('X');

      expect(edit.value, 'X🙂Amen');
      expect(edit.caretOffset, 1);
    });

    test('is left alone at the end of the text', () {
      final edit = DictationEdit.begin('🙂', caret: 2)..apply('Amen');

      expect(edit.value, '🙂Amen');
      expect(edit.caretOffset, 6);
    });
  });

  group('a limit', () {
    test('cuts the field back and reports it', () {
      final edit = DictationEdit.begin('', caret: 0, maxLength: 3)
        ..apply('naïve prayer');

      expect(edit.value, 'naï');
      expect(edit.truncated, isTrue);
    });

    test('stops being reported once the words fit again', () {
      final edit = DictationEdit.begin('', caret: 0, maxLength: 8)
        ..apply('far too long');
      expect(edit.truncated, isTrue);

      // A recogniser can revise its last words into something shorter, and the
      // field is whole again, so it must stop claiming to have been cut.
      edit.apply('short');

      expect(edit.value, 'short');
      expect(
        edit.truncated,
        isFalse,
        reason: 'nothing is cut now, so nothing should be reported',
      );
    });

    test('cuts text that was already in the field, and says so', () {
      final edit = DictationEdit.begin('Grace', caret: 5, maxLength: 3);

      // The limit applies to the whole field, so words or no words it applies.
      // Losing typed text is worth a report rather than a shrug.
      edit.apply('');

      expect(edit.value, 'Gra');
      expect(edit.truncated, isTrue);
    });

    test('leaves a field already over it uncut until a callback lands', () {
      final edit = DictationEdit.begin(
        'Grace and peace',
        caret: 16,
        maxLength: 4,
      );

      expect(edit.value, 'Grace and peace');
      expect(
        edit.truncated,
        isFalse,
        reason: 'nothing has been cut yet, so nothing is reported',
      );
    });
  });
}
