import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/sacred_surface.dart';
import '../providers/daily_scripture_providers.dart';

class DailyScriptureCard extends ConsumerWidget {
  const DailyScriptureCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripture = ref.watch(dailyScriptureProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SacredSurface(
        marble: true,
        padding: const EdgeInsets.all(16),
        child: scripture.when(
          loading: () => const ListTile(
            dense: true,
            leading: Icon(Icons.auto_stories_outlined),
            title: Text('Daily scripture'),
            trailing: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily scripture'),
            subtitle: const Text('Scripture could not be loaded.'),
            trailing: IconButton(
              tooltip: 'Try again',
              onPressed: () => ref.invalidate(dailyScriptureProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          data: (reading) => InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/scripture/daily'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Daily scripture',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  reading.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  '${reading.reference} · ${reading.translation}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
