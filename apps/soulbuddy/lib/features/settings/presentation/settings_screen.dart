import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/feedback/completion_feedback.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../persons/providers/person_providers.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../sacred_hours/application/sacred_hour_sound_player.dart';
import '../../sacred_hours/domain/sacred_hour.dart';
import '../../sacred_hours/presentation/sacred_hour_editor_sheet.dart';
import '../../sacred_hours/presentation/sacred_hours_settings_section.dart';
import '../../sacred_hours/providers/sacred_hour_providers.dart';
import 'account_email_link_section.dart';
import 'telegram_link_section.dart';

final privacyPolicyUri = Uri.parse('https://sbuddy.elbiblio.com/privacy');

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternalUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.openUri = _launchExternalUri});

  final ExternalUriLauncher openUri;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppFeedbackResult? _testResult;
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appFeedbackPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ListTile(
                leading: const Icon(Icons.headphones_outlined),
                title: const Text('Orientation'),
                subtitle: const Text(
                  'Listen, read along, and continue your Nuggets',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/orientation'),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _AccountEmailSettingsHost(),
              const SizedBox(height: AppSpacing.lg),
              _TelegramSettingsHost(openUri: widget.openUri),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: preferences.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _SettingsUnavailable(
                      onRetry: () =>
                          ref.invalidate(appFeedbackPreferencesProvider),
                    ),
                    data: (value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SacredHoursSettingsHost(
                          soundsEnabled: value.soundsEnabled,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _SoundTouchSettings(
                          preferences: value,
                          updating: _updating,
                          testResult: _testResult,
                          onHapticsChanged: (enabled) => _update(
                            (repository) =>
                                repository.setHapticsEnabled(enabled),
                          ),
                          onSoundsChanged: (enabled) => _update(
                            (repository) =>
                                repository.setSoundsEnabled(enabled),
                          ),
                          onReducedMotionChanged: (enabled) => _update(
                            (repository) =>
                                repository.setReducedMotion(enabled),
                          ),
                          onTest: () => _testFeedback(value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                subtitle: const Text('How SoulBuddy handles information'),
                trailing: const Icon(Icons.open_in_new),
                onTap: _openPrivacyPolicy,
              ),
              ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: const Text('Audio credits'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/audio-credits'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _update(
    Future<void> Function(AppFeedbackPreferencesRepository) update,
  ) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      final repository = await ref.read(
        appFeedbackPreferencesRepositoryProvider.future,
      );
      await update(repository);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this setting.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await widget.openUri(privacyPolicyUri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy policy could not be opened.')),
      );
    }
  }

  Future<void> _testFeedback(AppFeedbackPreferences preferences) async {
    final result = await ref
        .read(appFeedbackServiceProvider)
        .emit(
          AppFeedbackIntent.prayerCompleted,
          preferences: preferences,
          systemReduceMotion:
              MediaQuery.maybeOf(context)?.disableAnimations ?? false,
        );
    if (mounted) setState(() => _testResult = result);
  }
}

class _AccountEmailSettingsHost extends ConsumerWidget {
  const _AccountEmailSettingsHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AccountEmailLinkSection(
    requestLink: ref.read(accountEmailLinkClientProvider).request,
  );
}

class _TelegramSettingsHost extends ConsumerWidget {
  const _TelegramSettingsHost({required this.openUri});

  final ExternalUriLauncher openUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TelegramLinkSection(
    createLink: ref.read(telegramLinkClientProvider).createLink,
    openUri: openUri,
  );
}

class _SacredHoursSettingsHost extends ConsumerWidget {
  const _SacredHoursSettingsHost({required this.soundsEnabled});

  final bool soundsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(allSacredHoursProvider);
    return hours.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sacred Hours',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Opening your Sacred Hours…'),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sacred Hours',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Sacred Hours could not be opened just now.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(allSacredHoursProvider),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
      data: (value) => SacredHoursSettingsSection(
        hours: value,
        onAdd: () => _openEditor(context, ref, value),
        onEdit: (hour) => _openEditor(context, ref, value, hour: hour),
        onEnabledChanged: (hour, enabled) async {
          final repository = await ref.read(
            sacredHourRepositoryProvider.future,
          );
          await repository.setEnabled(hour.id, enabled);
        },
        onArchive: (hour) => _archive(context, ref, hour),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    List<SacredHour> hours, {
    SacredHour? hour,
  }) async {
    final timezone = await ref.read(prayerDeviceTimezoneProvider)();
    final deliveries =
        ref.read(sacredHourDeliveriesProvider).value ??
        const <SacredHourDelivery>[];
    final delivery = _deliveryFor(deliveries, hour?.id);
    final reviewed =
        ref
            .read(
              reviewedEditorialPrayersProvider((
                purpose: null,
                languagePreference: null,
              )),
            )
            .value ??
        const [];
    final personal =
        ref.read(personalPrayersProvider).value ?? const <PrayerDisplay>[];
    final people = ref.read(prayerPeopleProvider).value ?? const [];
    final player = AudioplayersSacredHourSoundPlayer();
    if (!context.mounted) {
      await player.dispose();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .94,
        child: SacredHourEditorSheet(
          hour: hour,
          timezone: timezone,
          existingHours: hours,
          prayers: [...reviewed.map((item) => item.prayer), ...personal],
          people: people,
          soundsEnabled: soundsEnabled,
          player: player,
          reminderMode:
              delivery?.reminderMode ?? SacredHourReminderMode.precise,
          onRequestPrecise: () async {
            final coordinator = await ref.read(
              sacredHourReminderCoordinatorProvider.future,
            );
            return coordinator.requestPreciseReminders();
          },
          onSave: (value) async {
            final repository = await ref.read(
              sacredHourRepositoryProvider.future,
            );
            final saved = await repository.save(
              SacredHourDraft(
                name: value.name,
                localTime: value.localTime,
                timezone: timezone,
                prayerMinutes: value.prayerMinutes,
                sound: value.sound,
                purpose: hour?.purpose ?? SacredHourPurpose.custom,
                prayer: value.prayer,
                personId: value.personId,
              ),
              id: hour?.id,
            );
            final updatedDeliveries = await repository.watchDeliveries().first;
            final updated = _deliveryFor(updatedDeliveries, saved.id);
            if (updated != null && updated.reminderMode != value.reminderMode) {
              await repository.updateDeviceDelivery(
                saved.id,
                SacredHourDeviceDraft(
                  enabledOnDevice: updated.enabledOnDevice,
                  reminderMode: value.reminderMode,
                  nextOccurrenceAt: updated.nextOccurrenceAt,
                  platformNotificationId: updated.platformNotificationId,
                  scheduledTimezone: updated.scheduledTimezone,
                  snoozedUntil: updated.snoozedUntil,
                  dismissedOccurrenceKey: updated.dismissedOccurrenceKey,
                ),
              );
            }
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    SacredHour hour,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this Sacred Hour?'),
        content: Text('${hour.name} will no longer appear or remind you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = await ref.read(sacredHourRepositoryProvider.future);
    await repository.archive(hour.id);
  }
}

SacredHourDelivery? _deliveryFor(
  List<SacredHourDelivery> deliveries,
  String? hourId,
) {
  if (hourId == null) return null;
  for (final delivery in deliveries) {
    if (delivery.sacredHourId == hourId) return delivery;
  }
  return null;
}

class _SoundTouchSettings extends StatelessWidget {
  const _SoundTouchSettings({
    required this.preferences,
    required this.updating,
    required this.testResult,
    required this.onHapticsChanged,
    required this.onSoundsChanged,
    required this.onReducedMotionChanged,
    required this.onTest,
  });

  final AppFeedbackPreferences preferences;
  final bool updating;
  final AppFeedbackResult? testResult;
  final ValueChanged<bool> onHapticsChanged;
  final ValueChanged<bool> onSoundsChanged;
  final ValueChanged<bool> onReducedMotionChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Sound & touch',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose how SoulBuddy confirms actions on this device.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Haptics'),
                subtitle: const Text('Gentle touch feedback for key actions.'),
                value: preferences.hapticsEnabled,
                onChanged: updating ? null : onHapticsChanged,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('In-app sounds'),
                subtitle: const Text('Quiet tones for saves and completion.'),
                value: preferences.soundsEnabled,
                onChanged: updating ? null : onSoundsChanged,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Reduce motion'),
                subtitle: const Text(
                  'Use immediate state changes instead of movement.',
                ),
                value: preferences.reducedMotion,
                onChanged: updating ? null : onReducedMotionChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: updating ? null : onTest,
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('Test feedback'),
        ),
        if (testResult case final result?) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: CompletionFeedback(
              cue: result.visualCue,
              animate: result.animate,
              semanticLabel: 'Feedback played',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Prayer narration is separate from feedback sounds. It can play only '
          'after you opt in for a saved prayer and open its reminder; system '
          'notifications remain silent.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsUnavailable extends StatelessWidget {
  const _SettingsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Settings could not be opened just now.'),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}
