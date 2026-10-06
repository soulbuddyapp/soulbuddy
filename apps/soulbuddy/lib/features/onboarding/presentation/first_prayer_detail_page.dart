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
            // for. There is no message line on this page to report a cut on, so
            // the limit shows itself through the field's own counter.
            SayableField(
              key: const Key('first-prayer-detail'),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              hintText: 'A name, need, or a few words',
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
}
