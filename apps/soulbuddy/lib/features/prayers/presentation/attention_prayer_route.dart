import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/affirmation_prayer.dart';
import '../domain/prayer_release.dart';
import '../providers/prayer_release_providers.dart';
import 'affirmation_prayer_session_screen.dart';

/// Resolves the added release item that carries the repetition practice and
/// opens the counted Prayer of attention.
///
/// Only an added item with a valid `affirmation_repetition` profile can open
/// this route.
class AttentionPrayerRoute extends ConsumerStatefulWidget {
  const AttentionPrayerRoute({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<AttentionPrayerRoute> createState() =>
      _AttentionPrayerRouteState();
}

class _AttentionPrayerRouteState extends ConsumerState<AttentionPrayerRoute> {
  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    // A stable id keeps a save retry from becoming a second session.
    _sessionId = const Uuid().v7();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(prayerReleaseContentProvider(widget.slug));

    return content.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          const Scaffold(body: _AttentionUnavailable()),
      data: (items) {
        PrayerReleaseItemContent? eligible;
        for (final item in items) {
          if (item.practice == null) continue;
          eligible ??= item;
        }

        if (eligible == null) {
          return const Scaffold(body: _AttentionUnavailable());
        }

        final item = eligible;
        final practice = item.practice;
        final itemId = item.itemId;
        if (practice == null || itemId == null) {
          return const Scaffold(body: _AttentionUnavailable());
        }

        AffirmationPrayerProfile profile;
        try {
          profile = AffirmationPrayerProfile.fromPractice(practice);
        } on FormatException {
          return const Scaffold(body: _AttentionUnavailable());
        }

        return AffirmationPrayerSessionScreen(
          // The screen is keyed so a route change never reuses a session's
          // in-progress text or count.
          key: ValueKey('${widget.slug}:${item.sortOrder}:$_sessionId'),
          profile: profile,
          releaseItemId: itemId,
          libraryPrayerId: item.libraryPrayerId,
          sessionId: _sessionId,
        );
      },
    );
  }
}

class _AttentionUnavailable extends StatelessWidget {
  const _AttentionUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This prayer is not available for counted prayer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('attention-prayer-unavailable-back'),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
