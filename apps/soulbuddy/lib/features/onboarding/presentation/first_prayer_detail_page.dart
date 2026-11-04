import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/speech/sayable_field.dart';

class FirstPrayerDetailPage extends StatefulWidget {
  const FirstPrayerDetailPage({
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  final ValueChanged<String> onContinue;
  final VoidCallback onSkip;

  @override
  State<FirstPrayerDetailPage> createState() => _FirstPrayerDetailPageState();
}

class _FirstPrayerDetailPageState extends State<FirstPrayerDetailPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What would you like to add?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Said in a person's own words, because that is all this field is
            // for.
            SayableField(
              key: const Key('first-prayer-detail'),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              hintText: 'A name, need, or a few words',
              // A cut is said rather than left to look like a whole answer. The
              // page has no message line of its own, so it goes to the SnackBar,
              // which the onboarding screen hosting this page already reports
              // through.
              onTruncated: _reportTruncation,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => widget.onContinue(_controller.text.trim()),
              child: const Text('Use reviewed prayer'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: widget.onSkip, child: const Text('Not now')),
          ],
        ),
      ),
    ),
  );

  /// Reports a limit that cut a dictated addition short.
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

/// Shown when the field's limit cut a dictated addition short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.
const String _limitReachedNotice = 'Your answer reached the limit.';
