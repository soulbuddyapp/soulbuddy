import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
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
            TextField(
              key: const Key('first-remembrance-text'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write what you want to remember',
              ),
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
