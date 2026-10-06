import 'package:flutter/material.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../altar/presentation/altar_ritual_sheet.dart';
import '../domain/library_prayer.dart';
import '../domain/prayer_reference.dart';
import '../providers/prayer_providers.dart';
import '../providers/prayer_release_providers.dart';
import 'prayer_library_tile.dart';
import 'use_today_confirmation_sheet.dart';
import 'voice_tablet_player.dart';
import '../domain/voice_tablet.dart';

class PrayerDetailScreen extends ConsumerStatefulWidget {
  const PrayerDetailScreen({required this.prayerId, super.key});

  final String prayerId;

  @override
  ConsumerState<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends ConsumerState<PrayerDetailScreen> {
  var _updatingHelpful = false;

  @override
  Widget build(BuildContext context) {
    final prayer = ref.watch(prayerProvider(widget.prayerId));

    return prayer.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DetailUnavailable(
        onBack: () => context.go('/prayers'),
        onRetry: () => retryPrayerDetailProviders(ref, widget.prayerId),
      ),
      data: (value) {
        if (value == null) {
          return _PrayerMissing(onBack: () => context.go('/prayers'));
        }
        return ScreenAwake(child: _buildPrayer(context, value));
      },
    );
  }

  Widget _buildPrayer(BuildContext context, LibraryPrayer prayer) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/prayers'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Prayers'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SanctuaryReadingHeading(
                title: prayer.title,
                art: SanctuaryArt.prayer,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${prayerPurposeLabel(prayer.purpose)} \u00B7 '
                '${prayerGroundingLabel(prayer.grounding)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                prayer.body,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.65),
              ),
              if (prayer.action case final action?) ...[
                const SizedBox(height: AppSpacing.xl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.componentRadius,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested action',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(action),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    key: const Key('helpful-toggle'),
                    onPressed: _updatingHelpful
                        ? null
                        : () => _setHelpful(prayer),
                    icon: _updatingHelpful
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            prayer.viewerMarkedHelpful
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                    label: Text('Helpful \u00B7 ${prayer.helpfulCount}'),
                  ),
                  FilledButton(
                    key: const Key('use-today'),
                    onPressed: () => _showUseToday(prayer),
                    child: const Text('Use today'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              VoiceTabletSection(
                source: VoiceTabletSource.library(prayerId: prayer.id),
                title: prayer.title,
                prayerBody: prayer.body,
                onKeepOnAltar: (tablet) =>
                    showAltarRitualSheet(context, ref, tablet: tablet),
              ),
              // Only a release item with the repetition practice offers the
              // counted Prayer of attention.
              ..._attentionAction(context),
            ],
          ),
        ),
      ),
    );
  }

  /// `Be still before God` appears only where an `affirmation_repetition`
  /// profile is available for this prayer.
  List<Widget> _attentionAction(BuildContext context) {
    final item = ref
        .watch(prayerReleaseItemContentProvider(widget.prayerId))
        .value;
    if (item == null || item.practice == null) return const [];

    return [
      const SizedBox(height: AppSpacing.lg),
      FilledButton.tonalIcon(
        key: const Key('prayer-detail-attention'),
        onPressed: () =>
            context.go('/prayers/releases/${item.releaseSlug}/attention'),
        icon: const Icon(Icons.self_improvement),
        label: const Text('Be still before God'),
      ),
    ];
  }

  Future<void> _setHelpful(LibraryPrayer prayer) async {
    setState(() => _updatingHelpful = true);
    try {
      final repository = await ref.read(prayerRepositoryProvider.future);
      await repository.setHelpful(
        prayer.id,
        value: !prayer.viewerMarkedHelpful,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update Helpful. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingHelpful = false);
    }
  }

  Future<void> _showUseToday(LibraryPrayer prayer) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => UseTodayConfirmationSheet(
        prayer: prayer,
        onConfirm: (includeAction) =>
            _selectForToday(prayer, includeAction: includeAction),
      ),
    );
    if (saved == true && mounted) context.go('/today');
  }

  Future<void> _selectForToday(
    LibraryPrayer prayer, {
    required bool includeAction,
  }) async {
    final repository = await ref.read(prayerRepositoryProvider.future);
    await repository.selectForToday(
      PrayerReference.library(prayer.id),
      includeAction: includeAction,
    );
  }
}

class _DetailUnavailable extends StatelessWidget {
  const _DetailUnavailable({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _DetailMessage(
      title: 'Prayer unavailable',
      body: 'This prayer could not be opened just now.',
      actions: [
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        TextButton(onPressed: onBack, child: const Text('Back to Prayers')),
      ],
    );
  }
}

class _PrayerMissing extends StatelessWidget {
  const _PrayerMissing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _DetailMessage(
      title: 'Prayer not found',
      body: 'It may no longer be in the library.',
      actions: [
        OutlinedButton(onPressed: onBack, child: const Text('Back to Prayers')),
      ],
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
