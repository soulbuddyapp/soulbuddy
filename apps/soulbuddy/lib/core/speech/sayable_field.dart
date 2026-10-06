import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_spacing.dart';
import 'dictation_edit.dart';
import 'speech_capture_controller.dart';
import 'speech_capture_providers.dart';

/// How loudly the dictation affordance presents itself.
enum SayableEmphasis {
  /// A mic in the field's own suffix. Every in-scope surface but the first,
  /// where the affordance is already in the habit of the screen around it.
  compact,

  /// A labelled action under the field as well, for the first say-something
  /// surface someone meets.
  prominent,
}

/// A field someone can write in and speak into.
///
/// Writing is never taken away. The field stays editable at every moment,
/// including while the microphone is open, and speech only ever adds to what is
/// already there. Where speech cannot run, the field is unchanged and the
/// notice says so, which is the same answer everywhere in the app because the
/// notice lives with the controller.
///
/// Words are merged through [DictationEdit] rather than appended, so text typed
/// before dictation and text after the caret both survive. What cannot survive
/// is a keystroke *during* a session: the merge is rebuilt from what the field
/// held when dictation began, so the next callback overwrites what was typed
/// into it. That is why the listening state is shown rather than hidden, and
/// why typing is left possible.
///
/// The controller is the app's one [SpeechCaptureController], read from
/// [speechCaptureControllerProvider] and owned by it. This widget neither
/// constructs one nor takes a recogniser: two controllers would mean an
/// initialisation each, with whichever registered last taking the seam's
/// callbacks, and one field's teardown ending another's session.
class SayableField extends ConsumerStatefulWidget {
  const SayableField({
    required this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 2,
    this.textInputAction,
    this.emphasis = SayableEmphasis.compact,
    this.maxLength,
    this.onTruncated,
    super.key,
  });

  /// The field itself. Owned by the caller, because what it holds outlives any
  /// one dictation session.
  final TextEditingController controller;

  final String? labelText;
  final String? hintText;

  /// How tall the field may grow. It starts at one line.
  final int maxLines;

  final TextInputAction? textInputAction;

  /// Whether the mic is a suffix on the field or also a labelled action below
  /// it.
  final SayableEmphasis emphasis;

  /// The field's limit. Applied to the whole field, so what is typed counts
  /// towards it too.
  final int? maxLength;

  /// Called on every callback whose words the limit cut short, so a caller can
  /// say so rather than let a shortened sentence look saved in full.
  final VoidCallback? onTruncated;

  @override
  ConsumerState<SayableField> createState() => _SayableFieldState();
}

class _SayableFieldState extends ConsumerState<SayableField> {
  SpeechCaptureController? _speech;

  /// The merge this field is in the middle of.
  ///
  /// Deliberately kept past a stop: the controller lets a stopped session's
  /// final result through, so a word caught mid-sentence still belongs in the
  /// field. It is dropped only when a session would not open, where no callback
  /// can arrive to be applied.
  DictationEdit? _edit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `ref` is not available in initState. The provider does not change, so
    // the controller and this field's subscription are taken once.
    if (_speech != null) return;
    final speech = ref.watch(speechCaptureControllerProvider)
      ..addListener(_speechChanged);
    _speech = speech;
    // Availability is resolved once for the whole app; asking here is what
    // puts the mic away on a device that cannot recognise.
    unawaited(speech.ensureAvailable());
  }

  void _speechChanged() {
    // Only the mic and the notice move with the controller. The field's text
    // is not state here: it belongs to the controller the caller owns.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // The provider owns the controller's lifetime, so only this field's
    // subscription goes. Disposing the controller here would close a
    // microphone another field is dictating into, and `stop` cannot be awaited
    // from `dispose`.
    _speech?.removeListener(_speechChanged);
    super.dispose();
  }

  Future<void> _toggle() async {
    final speech = _speech;
    if (speech == null) return;
    if (speech.isListening) {
      // Leaves the merge alone: the words are already in the field and a final
      // result can still arrive for them.
      await speech.stop();
      return;
    }
    final field = widget.controller;
    final selection = field.selection;
    // A caret can outlive its text, which is what an unselected field is.
    final caret = selection.isValid ? selection.baseOffset : field.text.length;
    final edit = DictationEdit.begin(
      field.text,
      caret: caret,
      maxLength: widget.maxLength,
    );
    _edit = edit;
    // Nothing is cleared to make room. The captured prefix surviving is the
    // whole design, and the field is never reset by dictation starting.
    final started = await speech.listen(onWords: _onWords);
    // A session that would not open leaves the field exactly as it was, still
    // editable, and says nothing about the device: only the notice does, and it
    // is the controller's.
    if (!started) _edit = null;
  }

  void _onWords(String words) {
    final edit = _edit;
    if (!mounted || edit == null) return;
    // The whole value, not just its text: assigning the text alone drops the
    // selection and leaves the caret nowhere.
    widget.controller.value = TextEditingValue(
      text: edit.apply(words),
      // The merge's own offset, because a caret is counted in code units and a
      // character outside the basic plane is two of them.
      selection: TextSelection.collapsed(offset: edit.caretOffset),
    );
    // Read on every callback rather than settled once: a cut can end when later
    // words fit, and one on a callback nobody read would go unsaid.
    if (edit.truncated) widget.onTruncated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final speech = _speech;
    final notice = speech?.notice;
    // Keyed off the notice rather than off availability. The two disagree only
    // if the seam breaks its contract, and retiring the mic for the session is
    // the safe way for that to fail.
    final canSpeak = notice == null;
    final listening = speech?.isListening ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          // Left editable while listening: speech only adds, and what is typed
          // during a session is the person's own to lose sight of.
          minLines: 1,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            alignLabelWithHint: widget.maxLines > 1,
            suffixIcon: canSpeak
                ? IconButton(
                    key: const Key('sayable-field-mic'),
                    tooltip: listening ? 'Stop dictation' : 'Speak',
                    icon: Icon(listening ? Icons.stop : Icons.mic_none),
                    onPressed: _toggle,
                  )
                : null,
          ),
        ),
        if (widget.emphasis == SayableEmphasis.prominent && canSpeak)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('sayable-field-speak-action'),
              onPressed: _toggle,
              icon: Icon(listening ? Icons.stop : Icons.mic_none),
              label: Text(listening ? 'Stop dictation' : 'Speak'),
            ),
          ),
        if (notice case final notice?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            notice,
            key: const Key('sayable-field-notice'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
