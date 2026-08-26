import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../providers/first_prayer_providers.dart';

class FirstPrayerResultPage extends StatefulWidget {
  const FirstPrayerResultPage({
    required this.prayer,
    required this.onPray,
    required this.onKeep,
    super.key,
  });

  final FirstPrayerResult prayer;
  final Future<bool> Function() onPray;
  final Future<bool> Function() onKeep;

  @override
  State<FirstPrayerResultPage> createState() => _FirstPrayerResultPageState();
}

class _FirstPrayerResultPageState extends State<FirstPrayerResultPage> {
  var _saving = false;
  String? _error;

  Future<void> _submit(Future<bool> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await action();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) _error = 'Couldn\'t keep this prayer. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.prayer.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.prayer.body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_error case final error?) ...[
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: _saving ? null : () => _submit(widget.onPray),
              child: const Text('Pray now'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _saving ? null : () => _submit(widget.onKeep),
              child: const Text('Keep this prayer'),
            ),
          ],
        ),
      ),
    ),
  );
}
