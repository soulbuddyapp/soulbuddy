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
///
/// The field underneath is a [TextFormField] when a [validator] is given and a
/// [TextField] otherwise, so a caller inside a [Form] keeps its validation and
/// a caller outside one is not made a form field for nothing.
class SayableField extends ConsumerStatefulWidget {
  const SayableField({
    required this.controller,
    this.labelText,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 2,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.decoration,
    this.validator,
    this.emphasis = SayableEmphasis.compact,
    this.maxLength,
    this.onChanged,
    this.onTruncated,
    super.key,
  });

  /// The field itself. Owned by the caller, because what it holds outlives any
  /// one dictation session.
  final TextEditingController controller;

  final String? labelText;
  final String? hintText;

  /// How tall the field starts, and how tall it may grow.
  final int minLines;
  final int maxLines;

  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Whether the field can be edited. A field that cannot also loses the mic,
  /// since words appearing in a field its owner is locked out of would be
  /// worse than no words at all.
  final bool enabled;

  /// A decoration to start from, for a caller whose field has a border or shape
  /// of its own. The label, the hint and the mic are this widget's and win over
  /// it; everything else is the caller's.
  final InputDecoration? decoration;

  /// Renders a [TextFormField], so a field inside a [Form] still validates.
  /// The text the words were merged into is what is validated, which means a
  /// dictated sentence is held to the same rule as a typed one.
  final String? Function(String?)? validator;

  /// Whether the mic is a suffix on the field or also a labelled action below
  /// it.
  final SayableEmphasis emphasis;

  /// The field's limit. Applied to the whole field, so what is typed counts
  /// towards it too.
  final int? maxLength;

  /// Called for typing and for dictation alike, with the field's whole text.
  ///
  /// A field's own `onChanged` fires for typing only, so a caller gating on it
  /// would never learn that words had arrived: its button would stay disabled
  /// while they were plainly on screen.
  final ValueChanged<String>? onChanged;

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
  /// field. It is dropped when a session this call opened would not start,
  /// where no callback can arrive to be applied.
  DictationEdit? _edit;

  /// A field may not have fewer lines than it starts with, and a caller that
  /// says `minLines: 5` without saying how tall it may grow would otherwise
  /// assert rather than render.
  int get _maxLines =>
      widget.maxLines > widget.minLines ? widget.maxLines : widget.minLines;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `ref` is not available in initState. This is deliberately a one-shot
    // rather than a re-subscription: the provider holds a plain controller that
    // cannot change, and a field that swapped controllers on the fly would
    // leave a session writing into whichever field opened it.
    if (_speech != null) return;
    final speech = ref.watch(speechCaptureControllerProvider)
      ..addListener(_speechChanged);
    _speech = speech;
    // Availability is resolved once for the whole app; asking here is what
    // puts the mic away on a device that cannot recognise.
    unawaited(speech.ensureAvailable());
  }

  @override
  void didUpdateWidget(SayableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A merge belongs to the field and the limit it was captured from. Swapping
    // either under a live session would write the old field's words into the
    // new one, so the merge goes. The session itself keeps running, because it
    // is not this field's to close.
    if (oldWidget.controller != widget.controller ||
        oldWidget.maxLength != widget.maxLength) {
      _edit = null;
    }
  }

  void _speechChanged() {
    // Only the mic, the tint and the notice move with the controller. The
    // field's text is not state here: it belongs to the controller the caller
    // owns.
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
    if (speech == null || !widget.enabled) return;
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
    //
    // A session that *is* running is not this call's to refuse, though. The mic
    // is up from the first frame while availability resolves, so a second tap
    // lands here after the first has already opened the session and been told
    // yes. Discarding the merge then would leave that live session writing
    // into nothing: the stop button on screen, and no words ever arriving.
    if (!started && !speech.isListening) _edit = null;
  }

  void _onWords(String words) {
    final edit = _edit;
    if (!mounted || edit == null) return;
    final text = edit.apply(words);
    // The whole value, not just its text: assigning the text alone drops the
    // selection and leaves the caret nowhere.
    widget.controller.value = TextEditingValue(
      text: text,
      // The merge's own offset, because a caret is counted in code units and a
      // character outside the basic plane is two of them.
      selection: TextSelection.collapsed(offset: edit.caretOffset),
    );
    // Read on every callback rather than settled once: a cut can end when later
    // words fit, and one on a callback nobody read would go unsaid.
    if (edit.truncated) widget.onTruncated?.call();
    // Dictation is a change to the field like any other, and reported after the
    // value is set so a caller reading the controller sees the words.
    widget.onChanged?.call(text);
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
    final theme = Theme.of(context);
    // A caller's decoration is the base — that is what the escape hatch is for
    // — but the label, the hint and the mic are this widget's, and they win,
    // because the mic is why the field exists here.
    final base = widget.decoration ?? const InputDecoration();
    final decoration = base.copyWith(
      labelText: widget.labelText ?? base.labelText,
      hintText: widget.hintText ?? base.hintText,
      alignLabelWithHint: base.alignLabelWithHint ?? _maxLines > 1,
      suffixIcon: canSpeak
          ? IconButton(
              key: const Key('sayable-field-mic'),
              tooltip: listening ? 'Stop dictation' : 'Speak',
              icon: Icon(listening ? Icons.stop : Icons.mic_none),
              onPressed: widget.enabled ? _toggle : null,
            )
          : null,
      // The listening state belongs on the field being dictated into, not in a
      // banner somewhere else. This is the app's own wash for "this is active",
      // the one its focus state uses.
      fillColor: listening
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : base.fillColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SayableInput(
          controller: widget.controller,
          validator: widget.validator,
          minLines: widget.minLines,
          maxLines: _maxLines,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          decoration: decoration,
          onChanged: widget.onChanged,
        ),
        if (widget.emphasis == SayableEmphasis.prominent && canSpeak) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('sayable-field-speak-action'),
              onPressed: _toggle,
              icon: Icon(listening ? Icons.stop : Icons.mic_none),
              label: Text(listening ? 'Stop dictation' : 'Speak'),
            ),
          ),
        ],
        if (notice case final notice?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            notice,
            key: const Key('sayable-field-notice'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// The field, as a form field when there is a validator to run and a plain one
/// when there is not.
///
/// The two lists below are the same on purpose and differ by exactly the
/// validator: a caller that finds one property on a [TextField] and not on the
/// other has found a field that would silently drop it on conversion.
class _SayableInput extends StatelessWidget {
  const _SayableInput({
    required this.controller,
    required this.validator,
    required this.minLines,
    required this.maxLines,
    required this.maxLength,
    required this.textInputAction,
    required this.textCapitalization,
    required this.autofocus,
    required this.enabled,
    required this.decoration,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (validator != null) {
      return TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        enabled: enabled,
        decoration: decoration,
        onChanged: onChanged,
        validator: validator,
      );
    }
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      enabled: enabled,
      decoration: decoration,
      onChanged: onChanged,
    );
  }
}
