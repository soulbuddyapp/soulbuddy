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
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../prayers/providers/voice_tablet_providers.dart';
import '../../prayers/domain/voice_tablet.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../application/sacred_hour_prayer_suggestions.dart';
import '../application/sacred_hour_session_controller.dart';
import '../application/sacred_hour_system_notification.dart';
import '../domain/sacred_hour.dart';
import '../providers/sacred_hour_providers.dart';
import 'sacred_hour_meditation_controls.dart';
import 'sacred_hour_prayer_controls.dart';
import 'sacred_hour_prayer_music_sheet.dart';
import 'sacred_hour_sanctuary_scaffold.dart';

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
  bool _soundPlaying = false;
  bool _prayerPlaying = false;
  MemoryAudioPlaybackCoordinator? _prayerPlayer;
  PrivateAudioTrack? _selectedPrayerTrack;
  String? _notificationHourId;

  @override
  void initState() {
    super.initState();
    _backgroundPlayer = AudioplayersMeditationSoundBedPlayer();
    unawaited(_restoreBackgroundSound());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _prayerPlayer?.removeListener(_onPrayerPlaybackChanged);
    unawaited(_stopSanctuaryAudio());
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
        _startNotification(value);
        final personal = ref.watch(personalPrayersProvider).value ?? const [];
        final library =
            ref
                .watch(prayerLibraryProvider((grounding: null, purpose: null)))
                .value ??
            const [];
        return PracticeAudioScope(
          onVisibilityChanged: (visible) {
            if (!visible) unawaited(_stopSanctuaryAudio());
          },
          child: SacredHourSessionView(
            hour: value,
            controller: _controller!,
            prayerTitle: _prayerTitle(ref, value.prayer),
            soundLabel: _backgroundSound?.label ?? 'Silence',
            soundPlaying: _soundPlaying,
            prayerPlaying: _prayerPlaying,
            onPrayer: () => _showPrayerPicker(
              value,
              SacredHourPrayerSuggestions.forHour(value, [
                ...personal,
                ...library,
              ]),
            ),
            onSound: _showSoundPicker,
            onSoundPlayback: _toggleBackgroundSound,
            onPrayerPlayback: _selectedPrayerTrack == null
                ? null
                : _togglePrayerPlayback,
            onRecordPrayer: () => _recordPrayer(value),
            onRemember: (prompt) => _openReflection(value, prompt),
            onExit: () => _exit(value),
            onPauseChanged: SacredHourSystemNotification.setPaused,
          ),
        );
      },
    );
  }

  void _startNotification(SacredHour hour) {
    if (_notificationHourId == hour.id) return;
    _notificationHourId = hour.id;
    final startedAt =
        _dueAt(hour.id, widget.occurrenceKey) ?? DateTime.now().toUtc();
    unawaited(
      SacredHourSystemNotification.start(
        title: hour.name,
        startedAt: startedAt,
        duration: Duration(minutes: hour.durationMinutes),
        route: Uri(
          pathSegments: ['sacred-hours', hour.id],
          queryParameters: {
            if (widget.occurrenceKey != null)
              'occurrence': widget.occurrenceKey!,
          },
        ).toString(),
      ),
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
    if (mounted) setState(() => _backgroundSound = sound);
    await ref
        .read(meditationSoundPreferencesProvider)
        .save(
          MeditationSoundPreferences(sound: sound, volume: _backgroundVolume),
        );
    if (sound == null) {
      await _stopBackgroundSound();
    } else {
      await _startBackgroundSound();
    }
  }

  Future<void> _startBackgroundSound() async {
    final sound = _backgroundSound;
    if (sound == null) return;
    await _backgroundPlayer.start(sound, volume: _backgroundVolume);
    if (mounted) setState(() => _soundPlaying = true);
  }

  Future<void> _stopBackgroundSound() async {
    await _backgroundPlayer.stop();
    if (mounted) setState(() => _soundPlaying = false);
  }

  Future<void> _toggleBackgroundSound() =>
      _soundPlaying ? _stopBackgroundSound() : _startBackgroundSound();

  Future<void> _stopSanctuaryAudio() async {
    await _prayerPlayer?.stop();
    await _stopBackgroundSound();
  }

  void _onPrayerPlaybackChanged() {
    final player = _prayerPlayer;
    final track = _selectedPrayerTrack;
    if (!mounted || player == null || track == null) return;
    final state = player.state;
    setState(() {
      _prayerPlaying =
          state.assetId == track.id &&
          state.status == MemoryAudioPlaybackStatus.playing;
    });
  }

  Future<void> _togglePrayerPlayback() async {
    final player = _prayerPlayer;
    final track = _selectedPrayerTrack;
    if (player == null || track == null) return;
    if (_prayerPlaying) {
      await player.pause();
    } else {
      await player.playTrack(track);
    }
    _onPrayerPlaybackChanged();
  }

  Future<void> _autoPlayChosenPrayer(PrayerReference reference) async {
    VoiceTabletSource source;
    if (reference.source == PrayerSource.library) {
      source = VoiceTabletSource.library(prayerId: reference.id);
    } else {
      final personal = await ref
          .read(personalPrayerRepositoryProvider.future)
          .then((repository) => repository.watch(reference.id).first);
      final revisionId = personal?.currentRevisionId;
      if (revisionId == null) return;
      source = VoiceTabletSource.personal(
        prayerId: reference.id,
        revisionId: revisionId,
      );
    }
    final tablet = await ref
        .read(voiceTabletRepositoryProvider.future)
        .then((repository) => repository.watchForSource(source).first);
    final audio = tablet?.fullAudio;
    if (!mounted || audio == null) return;
    final player = await ref.read(
      memoryAudioPlaybackCoordinatorProvider.future,
    );
    if (!mounted) return;
    if (!identical(_prayerPlayer, player)) {
      _prayerPlayer?.removeListener(_onPrayerPlaybackChanged);
      _prayerPlayer = player..addListener(_onPrayerPlaybackChanged);
    }
    _selectedPrayerTrack = PrivateAudioTrack(
      id: audio.id,
      storageKey: audio.storageKey,
      duration: audio.duration,
    );
    await player.playTrack(_selectedPrayerTrack!);
    _onPrayerPlaybackChanged();
  }

  Future<void> _showPrayerPicker(
    SacredHour hour,
    List<PrayerDisplay> suggestions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SacredHourPrayerPickerSheet(
        hour: hour,
        suggestions: suggestions,
        onChoosePrayer: (prayer) async {
          await ref
              .read(sacredHourRepositoryProvider.future)
              .then(
                (repository) => repository.save(
                  SacredHourDraft.fromHour(hour, prayer: prayer.reference),
                  id: hour.id,
                ),
              );
          unawaited(_autoPlayChosenPrayer(prayer.reference));
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        onAddPrayer: (purpose) {
          Navigator.pop(sheetContext);
          context.push('/prayers/create?purpose=${purpose.wireValue}');
        },
      ),
    );
  }

  Future<void> _showSoundPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: MeditationSoundPicker(
          selected: _backgroundSound,
          onSelected: _setBackgroundSound,
          onPreview: (sound) =>
              _backgroundPlayer.start(sound, volume: sound.preferredVolume),
        ),
      ),
    );
  }

  void _openReflection(SacredHour hour, String prompt) {
    unawaited(_stopSanctuaryAudio());
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(DateTime.now());
    context.push(
      Uri(
        path: '/remember/capture',
        queryParameters: {
          'mode': 'reflection',
          'source': 'sacred-hour',
          'title': '$prompt · $date',
          'prompt': prompt,
          if (hour.personId != null) 'person': hour.personId,
        },
      ).toString(),
    );
  }

  Future<void> _exit(SacredHour hour) async {
    _controller?.markDismissed();
    await _stopSanctuaryAudio();
    await SacredHourSystemNotification.stop();
    if (mounted) context.go('/today');
  }
}

class SacredHourSessionView extends StatefulWidget {
  const SacredHourSessionView({
    required this.hour,
    required this.controller,
    required this.onRecordPrayer,
    required this.onRemember,
    required this.onExit,
    required this.onPrayer,
    required this.onSound,
    required this.onSoundPlayback,
    required this.soundLabel,
    required this.soundPlaying,
    required this.prayerPlaying,
    this.prayerTitle,
    this.onPrayerPlayback,
    this.onPauseChanged,
    super.key,
  });

  final SacredHour hour;
  final SacredHourSessionController controller;
  final Future<void> Function() onRecordPrayer;
  final ValueChanged<String> onRemember;
  final VoidCallback onExit;
  final VoidCallback onPrayer;
  final VoidCallback onSound;
  final VoidCallback onSoundPlayback;
  final String soundLabel;
  final bool soundPlaying;
  final bool prayerPlaying;
  final String? prayerTitle;
  final VoidCallback? onPrayerPlayback;
  final ValueChanged<bool>? onPauseChanged;

  @override
  State<SacredHourSessionView> createState() => _SacredHourSessionViewState();
}

class _SacredHourSessionViewState extends State<SacredHourSessionView> {
  Timer? _ticker;
  var _saving = false;
  var _promptIndex = 0;

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
  Widget build(BuildContext context) => SacredHourSanctuaryScaffold(
    onExit: widget.onExit,
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: widget.controller.state.phase == SacredHourSessionPhase.prayer
          ? _prayerDock(context)
          : _meditationDock(context),
    ),
  );

  Widget _prayerDock(BuildContext context) {
    final seconds = (widget.controller.remaining.inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    return Column(
      key: const Key('sacred-hour-prayer-dock'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We belong to God.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$minutes:${seconds.remainder(60).toString().padLeft(2, '0')}',
          semanticsLabel: 'Prayer time remaining',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SacredHourPrayerControls(
          prayerLabel: widget.prayerTitle ?? 'Choose prayer',
          soundLabel: widget.soundLabel,
          prayerPlaying: widget.prayerPlaying,
          soundPlaying: widget.soundPlaying,
          completing: _saving,
          onPrayer: widget.onPrayer,
          onPrayerPlayback: widget.onPrayerPlayback,
          onSound: widget.onSound,
          onSoundPlayback: widget.onSoundPlayback,
          onPrayed: _recordPrayer,
        ),
      ],
    );
  }

  Widget _meditationDock(BuildContext context) => SacredHourMeditationControls(
    key: const Key('sacred-hour-meditation-dock'),
    prompt: _workPrompts[_promptIndex],
    onReflect: () => widget.onRemember(_workPrompts[_promptIndex]),
    onAnotherReflection: () =>
        setState(() => _promptIndex = (_promptIndex + 1) % _workPrompts.length),
  );

  Future<void> _recordPrayer() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.recordPrayer(widget.onRecordPrayer);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

DateTime? _dueAt(String hourId, String? occurrenceKey) {
  if (occurrenceKey == null) return null;
  final prefix = '$hourId@';
  if (!occurrenceKey.startsWith(prefix)) return null;
  return DateTime.tryParse(occurrenceKey.substring(prefix.length));
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Sacred Hour unavailable.')));
}
