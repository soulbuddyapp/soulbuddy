import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/telegram_link_client.dart';
import 'telegram_launch_guide.dart';

class TelegramLinkSection extends StatefulWidget {
  const TelegramLinkSection({
    super.key,
    required this.createLink,
    required this.checkStatus,
    required this.openUri,
  });

  final Future<TelegramLink> Function() createLink;
  final Future<TelegramLinkState> Function(String linkId) checkStatus;
  final Future<bool> Function(Uri uri) openUri;

  @override
  State<TelegramLinkSection> createState() => _TelegramLinkSectionState();
}

class _TelegramLinkSectionState extends State<TelegramLinkSection> {
  bool _connecting = false;
  String? _notice;
  TelegramLink? _link;

  @override
  Widget build(BuildContext context) {
    if (_link case final link?) {
      return TelegramLaunchGuide(
        link: link,
        openUri: widget.openUri,
        checkStatus: widget.checkStatus,
        onExpired: () => setState(() => _link = null),
      );
    }
    return Card(
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
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _notice = null;
    });
    try {
      final link = await widget.createLink();
      if (mounted) setState(() => _link = link);
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
