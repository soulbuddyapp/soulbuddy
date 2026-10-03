import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/telegram_link_client.dart';

class TelegramLinkSection extends StatefulWidget {
  const TelegramLinkSection({
    super.key,
    required this.createLink,
    required this.openUri,
  });

  final Future<TelegramLink> Function() createLink;
  final Future<bool> Function(Uri uri) openUri;

  @override
  State<TelegramLinkSection> createState() => _TelegramLinkSectionState();
}

class _TelegramLinkSectionState extends State<TelegramLinkSection> {
  bool _connecting = false;
  String? _notice;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Telegram',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _connecting ? null : _connect,
            icon: const Icon(Icons.send_outlined),
            label: _connecting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect Telegram'),
          ),
          if (_notice case final notice?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              notice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _notice = null;
    });
    try {
      final link = await widget.createLink();
      if (link.startUrl == null || !await widget.openUri(link.startUrl!)) {
        if (mounted) setState(() => _notice = 'Telegram could not be opened.');
        return;
      }
      if (mounted) setState(() => _notice = 'Telegram opened.');
    } on TelegramLinkException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } on StateError {
      if (mounted) setState(() => _notice = 'Telegram is unavailable.');
    } catch (_) {
      if (mounted) setState(() => _notice = 'Telegram could not be connected.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}
