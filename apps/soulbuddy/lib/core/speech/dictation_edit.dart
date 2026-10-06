/// A dictation in progress against a field's existing text.
///
/// Recognised words are the whole session so far, not a delta, so every
/// callback replaces the words of the one before it: appending would turn "I
/// pr" followed by "I pray" into "I prI pray". The text either side of the
/// caret is captured once and restored on every callback, which is what makes
/// dictating into a pre-filled or mid-sentence field safe. The field is rebuilt
/// from what was already in it, so no callback can remove text someone typed.
/// No separator is inserted, because the recogniser's own words carry their
/// own spacing.
///
/// A callback can also arrive after its own session ended, stamped with the
/// session that replaced it. [begin]'s [superseded] mitigates that, and cannot
/// settle it; see the note there.
class DictationEdit {
  DictationEdit._({
    required String prefix,
    required String suffix,
    required String superseded,
    required int? limit,
  }) : _prefix = prefix,
       _suffix = suffix,
       _superseded = superseded,
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
  /// caret count towards it too.
  ///
  /// [superseded] is the words the previous session in this same field last
  /// reported, when there was one. A stopped session can deliver its final
  /// result after the next session has started, and nothing here can tell that
  /// result from a real one: the plugin hands results to whichever session is
  /// listening now, so the token that fenced the stopped session out has
  /// already let it through. The only thing that distinguishes the two is that
  /// a leftover result carries the previous session's words forward, and those
  /// words are already in the captured prefix — applying them would say the
  /// sentence twice. So the first callback of a session is ignored when it
  /// does exactly that, and nothing else is.
  ///
  /// This is a mitigation, not a proof. It covers the common shape, where the
  /// stopped session's last words are what its final result extends or repeats,
  /// and it costs at most the loss of one callback: a session's words only
  /// grow, so the next callback restores anything ignored. What it cannot cover
  /// is a leftover result arriving after the session's own first callback, or
  /// one the recogniser revised instead of extended — both are indistinguishable
  /// from a person dictating. A caller that can stop the leftover result being
  /// produced at all, by discarding a stopped session rather than keeping its
  /// last words, should do that instead of relying on this.
  factory DictationEdit.begin(
    String text, {
    required int caret,
    int? maxLength,
    String superseded = '',
  }) {
    final offset = caret.clamp(0, text.length);
    return DictationEdit._(
      prefix: text.substring(0, offset),
      suffix: text.substring(offset),
      superseded: superseded,
      limit: maxLength,
    );
  }

  final String _prefix;
  final String _suffix;
  final String _superseded;

  /// The field's limit, or null when the field has none.
  final int? maxLength;

  /// The whole field text: as it was when dictation began, and then after
  /// every [apply].
  String get value => _value;
  String _value;

  /// Offset in [value] where the dictated words begin, for caret placement.
  int get prefixLength => _prefix.length;

  /// Offset in [value] where the dictated words end, which is where the caret
  /// belongs afterwards: inside [value] even when the limit has cut the field
  /// short, and unchanged when a callback was ignored.
  int get caretOffset => _caretOffset;
  int _caretOffset;

  /// True when the field's limit stopped the words from fitting whole.
  ///
  /// Never silent, because a field that quietly cut a sentence would leave the
  /// person believing it had been saved in full.
  bool get truncated => _truncated;
  bool _truncated = false;

  /// Whether the next callback is the first of this session.
  bool _awaitingFirstCallback = true;

  /// Replaces the dictated words with [words] and returns the whole field text.
  ///
  /// [words] is the whole session's words as they stand, so this replaces the
  /// previous words rather than adding to them.
  String apply(String words) {
    final leftover =
        _awaitingFirstCallback &&
        _superseded.isNotEmpty &&
        words.startsWith(_superseded);
    _awaitingFirstCallback = false;
    // Left exactly as dictation found the field, caret included.
    if (leftover) return _value;

    var merged = '$_prefix$words$_suffix';
    final limit = maxLength;
    _truncated = limit != null && merged.runes.length > limit;
    if (_truncated) merged = String.fromCharCodes(merged.runes.take(limit!));
    _value = merged;
    // A caret past the end of the text is invalid, and the limit can put the
    // words' end past it.
    _caretOffset = (prefixLength + words.length).clamp(0, merged.length);
    return merged;
  }
}
