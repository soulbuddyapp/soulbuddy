import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/speech/sayable_field.dart';
import 'first_prayer_choice_page.dart';

class FirstRemembranceTypePage extends StatelessWidget {
  const FirstRemembranceTypePage({required this.onChoose, super.key});

  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => FirstPrayerChoicePage(
    question: 'Before you leave, record something you would like to remember.',
    choices: const [
      'Encounter',
      'Promise',
      'Scripture or lesson',
      'Nothing today',
    ],
    onChoose: onChoose,
  );
}

class FirstRemembranceWritePage extends StatefulWidget {
  const FirstRemembranceWritePage({
    required this.onSave,
    this.initialBody = '',
    super.key,
  });

  final Future<bool> Function(String body) onSave;
  final String initialBody;

  @override
  State<FirstRemembranceWritePage> createState() =>
      _FirstRemembranceWritePageState();
}

class _FirstRemembranceWritePageState extends State<FirstRemembranceWritePage> {
  late final _controller = TextEditingController(text: widget.initialBody);
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (_saving || body.isEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(body);
      if (mounted && !saved) {
        setState(() => _error = 'Couldn\'t keep this memory. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record it',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            // What someone wants to remember is theirs to say, so it can be
            // spoken. The four choices above it stay choices.
            SayableField(
              key: const Key('first-remembrance-text'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              hintText: 'Write what you want to remember',
              // A cut is said rather than left to look like a whole memory. It
              // goes to the line this page already reports on, which is the
              // only thing here that reports.
              onTruncated: () => setState(() => _error = _limitReachedNotice),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error case final error?) ...[
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Keeping…' : 'Keep this memory'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shown when the field's limit cut a dictated memory short.
///
/// The app's own wording for the same event, reused rather than reworded:
/// `commitment_journey_screen` already tells someone their answer reached the
/// limit when it does. A second phrasing of the same fact would be the small
/// inconsistency the design asked to avoid.
const String _limitReachedNotice = 'Your answer reached the limit.';
