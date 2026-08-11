import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/library_prayer.dart';

class UseTodayConfirmationSheet extends StatefulWidget {
  const UseTodayConfirmationSheet({
    required this.prayer,
    required this.onConfirm,
    super.key,
  });

  final LibraryPrayer prayer;
  final Future<void> Function(bool includeAction) onConfirm;

  @override
  State<UseTodayConfirmationSheet> createState() =>
      _UseTodayConfirmationSheetState();
}

class _UseTodayConfirmationSheetState extends State<UseTodayConfirmationSheet> {
  late var _includeAction = widget.prayer.action != null;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Use this prayer today?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.prayer.action case final action?) ...[
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Include the suggested action'),
                  subtitle: Text(action),
                  value: _includeAction,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() => _includeAction = value ?? false);
                        },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('confirm-use-today'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving\u2026' : 'Use today'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onConfirm(_includeAction);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this prayer. Try again.')),
      );
    }
  }
}
