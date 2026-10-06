import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/telegram_link_client.dart';

class TelegramLaunchGuide extends StatefulWidget {
  const TelegramLaunchGuide({
    super.key,
    required this.link,
    required this.openUri,
    required this.checkStatus,
    required this.onExpired,
  });

  final TelegramLink link;
  final Future<bool> Function(Uri uri) openUri;
  final Future<TelegramLinkState> Function(String linkId) checkStatus;
  final VoidCallback onExpired;

  @override
  State<TelegramLaunchGuide> createState() => _TelegramLaunchGuideState();
}

class _TelegramLaunchGuideState extends State<TelegramLaunchGuide>
    with WidgetsBindingObserver {
  bool _checking = false;
  TelegramLinkState _state = TelegramLinkState.pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_checking || _state != TelegramLinkState.pending) return;
    setState(() => _checking = true);
    try {
      final state = await widget.checkStatus(widget.link.id);
      if (mounted) setState(() => _state = state);
    } on TelegramLinkException {
      // Keep the pending state so a temporary network failure can be retried.
    } on StateError {
      // Keep the pending state so a restored session can be checked again.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == TelegramLinkState.connected;
    final expired = _state == TelegramLinkState.expired;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Telegram', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            if (connected)
              const Text('Telegram connected.')
            else if (expired) ...[
              const Text('The secure link expired.'),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: widget.onExpired,
                child: const Text('Start a new link'),
              ),
            ] else ...[
              const Text('1. Open SoulBuddy on Telegram'),
              const SizedBox(height: AppSpacing.sm),
              const Text('2. Select Start'),
              const SizedBox(height: AppSpacing.sm),
              const Text('3. Confirm connection'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: widget.link.startUrl == null
                    ? null
                    : () => widget.openUri(widget.link.startUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Telegram'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _checking ? null : _checkStatus,
                child: _checking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm connection'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
