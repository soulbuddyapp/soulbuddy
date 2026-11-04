/// A dictation in progress against a field's existing text.
///
/// Recognised words are the whole session so far, not a delta, so every
/// callback replaces the words of the one before it: appending would turn "I
/// pr" followed by "I pray" into "I prI pray". The text either side of the
/// caret is captured once and restored on every callback, which is what makes
/// dictating into a pre-filled or mid-sentence field safe. The field is rebuilt
/// from what was in it when dictation started, so no callback can remove text
/// someone typed before then. No separator is inserted, because the
/// recogniser's own words carry their own spacing.
///
/// What a callback cannot do is keep text typed *during* the session: the text
/// either side of the caret is the text from [begin], so a keystroke while the
/// microphone is open is overwritten by the next callback. A caller that
/// intends to let someone keep typing mid-dictation has to end the session
/// first, which is the honest reading of a field that takes the caret.
///
/// This is only the merge. A callback belonging to a session that has already
/// ended is dropped by [SpeechCaptureController], which is the layer that knows
/// a session ended; see the note on its `listen`.
class DictationEdit {
  DictationEdit._({
    required String prefix,
    required String suffix,
    required int? limit,
  }) : _prefix = prefix,
       _suffix = suffix,
       maxLength = limit,
       // Nothing has been dictated yet, so the field is what it was and the
       // caret is where dictation began.
       _value = '$prefix$suffix',
       _caretOffset = prefix.length;

  /// Captures the field as it stands when dictation starts, and stays the
  /// baseline every callback is applied to.
  ///
  /// [caret] is the offset the dictated words go in at. A caret can outlive its
  /// text, so an offset outside [text] is treated as the nearest end.
  ///
  /// [maxLength] is the field's limit, applied to the whole field rather than
  /// to the dictated words alone, so what is typed and what is kept after the
  /// caret count towards it too. A field already over its limit when dictation
  /// starts is not reported as truncated until a callback lands, because until
  /// then nothing has been cut.
  ///
  /// Note what a limit does to text that was already there: applying even empty
  /// words will cut a field that has outgrown its limit, since the limit
  /// applies to the whole field. That is reported by [truncated] like any other
  /// cut, but it is a way to lose typed text, so a caller passing a limit
  /// should expect it to hold the field to that limit while dictating too.
  factory DictationEdit.begin(
    String text, {
    required int caret,
    int? maxLength,
  }) {
    final offset = _caretBoundary(text, caret);
    return DictationEdit._(
      prefix: text.substring(0, offset),
      suffix: text.substring(offset),
      limit: maxLength,
    );
  }

  /// Moves [caret] to a boundary no character straddles, so the prefix and
  /// suffix are each whole text and the merged field cannot come out with a
  /// half character in it.
  static int _caretBoundary(String text, int caret) {
    final offset = caret.clamp(0, text.length);
    // A caret reported in the middle of a surrogate pair would cut one
    // character into two. Flutter reports whole characters, so this is
    // defence in depth for a caller that computes the offset itself. Stepped
    // back rather than forward, so the character the person was pointing at
    // stays on the side the caret was already on.
    if (offset > 0 &&
        offset < text.length &&
        _isLowSurrogate(text.codeUnitAt(offset))) {
      return offset - 1;
    }
    return offset;
  }

  static bool _isLowSurrogate(int codeUnit) =>
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  final String _prefix;
  final String _suffix;

  /// The field's limit, or null when the field has none.
  final int? maxLength;

  /// The whole field text: as it was when dictation began, and then after
  /// every [apply].
  String get value => _value;
  String _value;

  /// Offset in [value] where the dictated words end, which is where the caret
  /// belongs afterwards: inside [value] even when the limit has cut the field
  /// short.
  int get caretOffset => _caretOffset;
  int _caretOffset;

  /// True when the field's limit stopped the words from fitting whole.
  ///
  /// Never silent, because a field that quietly cut a sentence would leave the
  /// person believing it had been saved in full. A cut also ends the
  /// expectation: the words in [value] are no longer what was recognised, so
  /// the field cannot be extended by speaking on without losing what it holds.
  bool get truncated => _truncated;
  bool _truncated = false;

  /// Replaces the dictated words with [words] and returns the whole field text.
  ///
  /// [words] is the whole session's words as they stand, so this replaces the
  /// previous words rather than adding to them.
  String apply(String words) {
    var merged = '$_prefix$words$_suffix';
    final limit = maxLength;
    _truncated = limit != null && merged.runes.length > limit;
    if (_truncated) merged = String.fromCharCodes(merged.runes.take(limit!));
    _value = merged;
    // A caret past the end of the text is invalid, and the limit can put the
    // words' end past it. A character outside the basic plane is two code
    // units, so counting in code units is what keeps the caret off the space
    // between its halves.
    _caretOffset = (_prefix.length + words.length).clamp(0, merged.length);
    return merged;
  }
}
