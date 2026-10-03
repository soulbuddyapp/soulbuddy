import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/telegram_link_client.dart';

class TelegramLaunchGuide extends StatelessWidget {
  const TelegramLaunchGuide({
    super.key,
    required this.link,
    required this.openUri,
  });

  final TelegramLink link;
  final Future<bool> Function(Uri uri) openUri;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Telegram', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          const Text('1. Open SoulBuddy on Telegram'),
          const SizedBox(height: AppSpacing.sm),
          const Text('2. Select Start'),
          const SizedBox(height: AppSpacing.sm),
          const Text('3. Return after the confirmation message'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: link.startUrl == null
                ? null
                : () => openUri(link.startUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Telegram'),
          ),
        ],
      ),
    ),
  );
}
