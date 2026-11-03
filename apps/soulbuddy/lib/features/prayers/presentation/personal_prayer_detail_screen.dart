import 'package:flutter/material.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../altar/presentation/altar_ritual_sheet.dart';
import '../providers/personal_prayer_providers.dart';
import 'prayer_reminder_sheet.dart';
import 'prayer_session_actions.dart';
import 'voice_tablet_player.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../domain/voice_tablet.dart';

class PersonalPrayerDetailScreen extends ConsumerWidget {
  const PersonalPrayerDetailScreen({required this.prayerId, super.key});

  final String prayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenAwake(child: _buildPrayer(context, ref));
  }

  Widget _buildPrayer(BuildContext context, WidgetRef ref) {
    final prayer = ref.watch(personalPrayerProvider(prayerId));
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: prayer.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _PersonalPrayerMessage(
                'This saved prayer could not be opened just now.',
              ),
              data: (value) {
                if (value == null) {
                  return const _PersonalPrayerMessage(
                    'This saved prayer is no longer available.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      'Saved prayer',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SanctuaryReadingHeading(
                      title: value.title,
                      art: SanctuaryArt.prayer,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    VoiceTabletSection(
                      source: VoiceTabletSource.personal(
                        prayerId: value.id,
                        revisionId: value.currentRevisionId,
                      ),
                      title: value.title,
                      prayerBody: value.body,
                      compact: true,
                      showPrayerActions: false,
                      onKeepOnAltar: (tablet) =>
                          showAltarRitualSheet(context, ref, tablet: tablet),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrayerSessionActions(prayer: value),
                    const SizedBox(height: AppSpacing.md),
                    VoiceNotesField(
                      noteContext: (
                        type: 'prayer',
                        id: value.id,
                        field: 'reflection',
                      ),
                      title: 'After prayer',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    PrayerReminderControl(prayer: value, compact: true),
                    if (!value.isAudio && value.body.trim().isNotEmpty)
                      ExpansionTile(
                        title: const Text('Earlier written prayer'),
                        children: [
                          SelectableText(value.body),
                          if (value.action case final action?) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Practice',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SelectableText(action),
                          ],
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalPrayerMessage extends StatelessWidget {
  const _PersonalPrayerMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
