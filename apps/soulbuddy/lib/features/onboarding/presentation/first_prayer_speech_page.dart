import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/speech/sayable_field.dart';

/// Where someone says a prayer, or part of one, in their own words.
///
/// The field is both: it is a text field, so typing needs no separate mode, and
/// the microphone is offered beside it rather than instead of it. Whether the
/// device can recognise is the shared controller's business, so this page never
/// asks, and never says the same thing twice about it.
class FirstPrayerSpeechPage extends StatefulWidget {
  const FirstPrayerSpeechPage({
    required this.onContinue,
    required this.onWriteInstead,
    required this.onSkip,
    this.heading = 'Speak',
    this.description = 'Say a name, need, or a few words.',
    this.continueLabel = 'Use reviewed prayer',
    this.hintText = 'Your words will appear here',
    this.fieldKey = const Key('first-prayer-spoken-detail'),
    super.key,
  });

  final ValueChanged<String> onContinue;

  /// Kept because callers in other features still pass it.
  ///
  /// Nothing on this page offers writing as an alternative to speaking, because
  /// the field is a text field either way and the keyboard's own microphone
  /// works. Removing it is a change to those callers' screens, not to anything
  /// this page does.
  final VoidCallback onWriteInstead;

  final VoidCallback onSkip;
  final String heading;
  final String description;
  final String continueLabel;
  final String hintText;
  final Key fieldKey;

  @override
  State<FirstPrayerSpeechPage> createState() => _FirstPrayerSpeechPageState();
}

class _FirstPrayerSpeechPageState extends State<FirstPrayerSpeechPage> {
  final _words = TextEditingController();

  @override
  void dispose() {
    // Not the microphone: one session belongs to the whole app, so leaving this
    // page must not close a field someone else is dictating into.
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.heading,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.description),
            const SizedBox(height: AppSpacing.lg),
            SayableField(
              key: widget.fieldKey,
              controller: _words,
              hintText: widget.hintText,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              // The first say-something surface someone meets, so the
              // affordance is labelled as well as present.
              emphasis: SayableEmphasis.prominent,
              // A cut is said rather than left to look like a whole answer. This
              // page has no message line of its own, so it goes to the SnackBar,
              // which every screen hosting this page already reports through.
              onTruncated: _reportTruncation,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final words = _words.text.trim();
                if (words.isNotEmpty) widget.onContinue(words);
              },
              child: Text(widget.continueLabel),
            ),
            TextButton(onPressed: widget.onSkip, child: const Text('Not now')),
          ],
        ),
      ),
    ),
  );

  /// Reports a limit that cut a dictated answer short.
  ///
  /// The messenger rather than this page: the page's own state may be gone by
  /// the time the notice would show, and a step change takes it with it.
  void _reportTruncation() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_limitReachedNotice)));
  }
}

/// Shown when the field's limit cut a dictated answer short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.
const String _limitReachedNotice = 'Your answer reached the limit.';
