import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../persons/providers/person_providers.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../application/sacred_hour_session_controller.dart';
import '../application/sacred_hour_prayer_suggestions.dart';
import '../domain/sacred_hour.dart';
import '../providers/sacred_hour_providers.dart';
import 'sacred_hour_prayer_music_sheet.dart';
import '../../goals/presentation/daily_practice_sheet.dart';

class SacredHourSessionScreen extends ConsumerStatefulWidget {
  const SacredHourSessionScreen({
    required this.hourId,
    this.occurrenceKey,
    super.key,
  });

  final String hourId;
  final String? occurrenceKey;

  @override
  ConsumerState<SacredHourSessionScreen> createState() =>
      _SacredHourSessionScreenState();
}

class _SacredHourSessionScreenState
    extends ConsumerState<SacredHourSessionScreen> {
  SacredHourSessionController? _controller;
  late final MeditationSoundBedPlayer _backgroundPlayer;
  MeditationSoundBed? _backgroundSound;
  double _backgroundVolume = .15;

  @override
  void initState() {
    super.initState();
    _backgroundPlayer = AudioplayersMeditationSoundBedPlayer();
    unawaited(_restoreBackgroundSound());
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_backgroundPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(sacredHourProvider(widget.hourId));
    return hour.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Unavailable(),
      data: (value) {
        if (value == null) return const _Unavailable();
        _controller ??= SacredHourSessionController(
          prayerMinutes: value.prayerMinutes,
        );
        final personal = ref.watch(personalPrayersProvider).value ?? const [];
        final library =
            ref
                .watch(prayerLibraryProvider((grounding: null, purpose: null)))
                .value ??
            const [];
        final suggestions = SacredHourPrayerSuggestions.forHour(value, [
          ...personal,
          ...library,
        ]);
        final prayerTitle = _prayerTitle(ref, value.prayer);
        final personName = value.personId == null
            ? null
            : ref.watch(prayerPersonProvider(value.personId!)).value?.name;
        return PracticeAudioScope(
          onVisibilityChanged: (visible) {
            if (!visible) unawaited(_stopBackgroundSound());
          },
          child: SacredHourSessionView(
            hour: value,
            controller: _controller!,
            prayerTitle: prayerTitle,
            personName: personName,
            onOpenPrayer: value.prayer == null
                ? null
                : () {
                    unawaited(_stopBackgroundSound());
                    _openPrayer(context, value.prayer!);
                  },
            onOpenPerson: value.personId == null
                ? null
                : () {
                    unawaited(_stopBackgroundSound());
                    context.push('/persons/${value.personId}');
                  },
            onRecordPrayer: () => _recordPrayer(value),
            onRemember: (mode) {
              unawaited(_stopBackgroundSound());
              context.push(
                '/remember/capture?mode=$mode&source=sacred-hour'
                '${value.personId == null ? '' : '&person=${value.personId}'}',
              );
            },
            onPrayerMusic: () => _showPrayerMusic(value, suggestions),
            onDailyPractice: () => showDailyPracticeSheet(
              context,
              evening: value.purpose == SacredHourPurpose.evening,
            ),
          ),
        );
      },
    );
  }

  Future<void> _recordPrayer(SacredHour hour) async {
    final prayer = hour.prayer;
    String? prayerSessionId;
    if (prayer != null) {
      String? revisionId;
      if (prayer.source == PrayerSource.personal) {
        final personal = await ref
            .read(personalPrayerRepositoryProvider.future)
            .then((repository) => repository.watch(prayer.id).first);
        revisionId = personal?.currentRevisionId;
      }
      final session = await ref
          .read(prayerPracticeRepositoryProvider.future)
          .then(
            (repository) => repository.recordSession(
              prayer: prayer,
              timezone: hour.timezone,
              revisionId: revisionId,
              idempotencyKey: widget.occurrenceKey,
            ),
          );
      prayerSessionId = session.id;
    }
    if (hour.personId case final personId?) {
      await ref
          .read(personRepositoryProvider.future)
          .then(
            (repository) =>
                repository.recordPrayer(personId, localDate: DateTime.now()),
          );
    }
    final dueAt = _dueAt(hour.id, widget.occurrenceKey) ?? DateTime.now();
    await ref
        .read(sacredHourRepositoryProvider.future)
        .then(
          (repository) => repository.markOccurrence(
            hour.id,
            dueAt,
            SacredHourOccurrenceStatus.completed,
            prayerSessionId: prayerSessionId,
          ),
        );
  }

  Future<void> _restoreBackgroundSound() async {
    try {
      final preferences = await ref
          .read(meditationSoundPreferencesProvider)
          .load();
      if (!mounted) return;
      setState(() {
        _backgroundSound = preferences.sound;
        _backgroundVolume = preferences.volume;
      });
    } catch (error) {
      debugPrint('Sacred Hour background sound unavailable: $error');
    }
  }

  Future<void> _setBackgroundSound(MeditationSoundBed? sound) async {
    if (sound != null && sound != _backgroundSound) {
      _backgroundVolume = sound.preferredVolume;
    }
    setState(() => _backgroundSound = sound);
    try {
      await ref
          .read(meditationSoundPreferencesProvider)
          .save(
            MeditationSoundPreferences(
              sound: _backgroundSound,
              volume: _backgroundVolume,
            ),
          );
      await _startBackgroundSound();
    } catch (error) {
      debugPrint('Sacred Hour background sound unavailable: $error');
    }
  }

  Future<void> _previewBackgroundSound(MeditationSoundBed sound) =>
      _backgroundPlayer.start(sound, volume: sound.preferredVolume);

  Future<void> _startBackgroundSound() {
    final sound = _backgroundSound;
    return sound == null
        ? _backgroundPlayer.stop()
        : _backgroundPlayer.start(sound, volume: _backgroundVolume);
  }

  Future<void> _stopBackgroundSound() => _backgroundPlayer.stop();

  Future<void> _showPrayerMusic(
    SacredHour hour,
    List<PrayerDisplay> suggestions,
  ) async {
    var resumeSound = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SacredHourPrayerMusicSheet(
        hour: hour,
        suggestions: suggestions,
        selectedSound: _backgroundSound,
        onChoosePrayer: (prayer) async {
          await ref
              .read(sacredHourRepositoryProvider.future)
              .then(
                (repository) => repository.save(
                  SacredHourDraft.fromHour(hour, prayer: prayer.reference),
                  id: hour.id,
                ),
              );
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onAddPrayer: (purpose) async {
          resumeSound = false;
          await _stopBackgroundSound();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (mounted) {
            context.push('/prayers/create?purpose=${purpose.wireValue}');
          }
        },
        onSoundSelected: _setBackgroundSound,
        onPreviewSound: _previewBackgroundSound,
      ),
    );
    if (mounted && resumeSound) await _startBackgroundSound();
  }
}

class SacredHourSessionView extends StatefulWidget {
  const SacredHourSessionView({
    required this.hour,
    required this.controller,
    required this.onRecordPrayer,
    required this.onRemember,
    this.prayerTitle,
    this.personName,
    this.onOpenPrayer,
    this.onOpenPerson,
    this.onPrayerMusic,
    this.onDailyPractice,
    super.key,
  });

  final SacredHour hour;
  final SacredHourSessionController controller;
  final Future<void> Function() onRecordPrayer;
  final ValueChanged<String> onRemember;
  final String? prayerTitle;
  final String? personName;
  final VoidCallback? onOpenPrayer;
  final VoidCallback? onOpenPerson;
  final VoidCallback? onPrayerMusic;
  final VoidCallback? onDailyPractice;

  @override
  State<SacredHourSessionView> createState() => _SacredHourSessionViewState();
}

class _SacredHourSessionViewState extends State<SacredHourSessionView> {
  Timer? _ticker;
  var _quiet = false;
  var _selectedPrompt = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.beginPrayer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      appBar: AppBar(title: Text(widget.hour.name)),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: state.phase == SacredHourSessionPhase.prayer
                  ? _prayerPhase(context)
                  : _workPhase(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _prayerPhase(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = widget.controller.remaining;
    final totalSeconds = (remaining.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds.remainder(60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Begin with prayer', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: theme.textTheme.displaySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.prayerTitle case final title?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(title),
            trailing: TextButton(
              onPressed: widget.onOpenPrayer,
              child: const Text('Open prayer'),
            ),
          ),
        if (widget.personName case final name?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text('Pray for $name'),
            trailing: TextButton(
              onPressed: widget.onOpenPerson,
              child: const Text('Open'),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('sacred-hour-prayer-music'),
          onPressed: widget.onPrayerMusic,
          icon: const Icon(Icons.music_note_outlined),
          label: const Text('Prayer and music'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => setState(() => _quiet = !_quiet),
          icon: const Icon(Icons.self_improvement_outlined),
          label: Text(_quiet ? 'Stay here quietly' : 'Quiet prayer'),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.onDailyPractice != null)
          OutlinedButton.icon(
            onPressed: widget.onDailyPractice,
            icon: const Icon(Icons.spa_outlined),
            label: Text(
              widget.hour.purpose == SacredHourPurpose.evening
                  ? 'Evening reflection'
                  : 'Daily practice',
            ),
          ),
        FilledButton(
          onPressed: widget.controller.state.prayerRecorded
              ? null
              : () => widget.controller.recordPrayer(widget.onRecordPrayer),
          child: Text(
            widget.controller.state.prayerRecorded
                ? 'Prayer recorded'
                : 'I prayed',
          ),
        ),
      ],
    );
  }

  Widget _workPhase(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'God speaks to us in meditation',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Listen to know if your prayer needs something from you',
        ),
        if (widget.onDailyPractice != null)
          TextButton.icon(
            onPressed: widget.onDailyPractice,
            icon: const Icon(Icons.spa_outlined),
            label: Text(widget.hour.purpose == SacredHourPurpose.evening
                ? 'Evening reflection' : 'Daily practice'),
          ),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < _workPrompts.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ChoiceChip(
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(_workPrompts[index], maxLines: 2, softWrap: true),
              ),
              selected: _selectedPrompt == index,
              onSelected: (_) => setState(() => _selectedPrompt = index),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Remember what I understood', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => widget.onRemember('speak'),
                icon: const Icon(Icons.mic_none),
                label: const Text('Speak'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onRemember('write'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _workPrompts = [
  'Why might God have placed me in this work?',
  'Who can I serve through it today?',
  'What needs patience, courage, honesty, or care?',
  'What may God be teaching me here?',
];

String? _prayerTitle(WidgetRef ref, PrayerReference? prayer) {
  if (prayer == null) return null;
  return switch (prayer.source) {
    PrayerSource.library => ref.watch(prayerProvider(prayer.id)).value?.title,
    PrayerSource.personal =>
      ref.watch(personalPrayerProvider(prayer.id)).value?.title,
  };
}

void _openPrayer(BuildContext context, PrayerReference prayer) {
  final path = prayer.source == PrayerSource.personal
      ? '/prayers/saved/${prayer.id}'
      : '/prayers/${prayer.id}';
  context.push(path);
}

DateTime? _dueAt(String hourId, String? occurrenceKey) {
  if (occurrenceKey == null) return null;
  final prefix = '$hourId@';
  if (!occurrenceKey.startsWith(prefix)) return null;
  return DateTime.tryParse(occurrenceKey.substring(prefix.length));
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('This Sacred Hour is unavailable.')),
  );
}
