import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../../persons/providers/person_providers.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/library_prayer.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/recorded_personal_prayer_providers.dart';
import '../../prayers/domain/personal_prayer.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../prayers/providers/voice_tablet_providers.dart';
import '../../prayers/domain/voice_tablet.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/presentation/inline_audio_capture.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../application/sacred_hour_prayer_suggestions.dart';
import '../application/sacred_hour_continuity.dart';
import '../application/sacred_hour_recorded_playback.dart';
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
    this.soundPlayer,
    super.key,
  });

  final String hourId;
  final String? occurrenceKey;
  final MeditationSoundBedPlayer? soundPlayer;

  @override
  ConsumerState<SacredHourSessionScreen> createState() =>
      _SacredHourSessionScreenState();
}

class _SacredHourSessionScreenState
    extends ConsumerState<SacredHourSessionScreen> {
  SacredHourSessionController? _controller;
  SacredHourContinuity? _continuity;
  late final MeditationSoundBedPlayer _backgroundPlayer;
  MeditationSoundBed? _backgroundSound;
  double _backgroundVolume = .15;
  bool _soundPlaying = false;
  bool _prayerPlaying = false;
  MemoryAudioPlaybackCoordinator? _prayerPlayer;
  PrivateAudioTrack? _selectedPrayerTrack;
  SacredHourSoundBedGuard? _soundBedGuard;

  @override
  void initState() {
    super.initState();
    _backgroundPlayer =
        widget.soundPlayer ?? AudioplayersMeditationSoundBedPlayer();
    unawaited(SacredHourSystemNotification.stop());
    unawaited(_restoreBackgroundSound());
  }

  @override
  void dispose() {
    _prayerPlayer?.removeListener(_onPrayerPlaybackChanged);
    _soundBedGuard?.dispose();
    unawaited(_stopBackgroundSound());
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
        if (_controller == null) {
          final key = (
            route: _sessionRoute,
            prayerMinutes: value.prayerMinutes,
          );
          var continuity = ref.read(sacredHourContinuityProvider(key));
          if (continuity.controller.state.phase ==
              SacredHourSessionPhase.dismissed) {
            ref.invalidate(sacredHourContinuityProvider(key));
            continuity = ref.read(sacredHourContinuityProvider(key));
          }
          _continuity = continuity;
          _controller = continuity.controller;
          if (continuity.track != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => unawaited(_restoreSelectedPrayer()),
            );
          }
        }
        final personal = ref.watch(personalPrayersProvider).value ?? const [];
        final library =
            ref
                .watch(prayerLibraryProvider((grounding: null, purpose: null)))
                .value ??
            const [];
        return PracticeAudioScope(
          onVisibilityChanged: (visible) {
            if (!visible) unawaited(_stopBackgroundSound());
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
            beforeReflection: _stopSanctuaryAudio,
            onExit: () => _exit(value),
          ),
        );
      },
    );
  }

  String get _sessionRoute => Uri(
    pathSegments: ['', 'sacred-hours', widget.hourId],
    queryParameters: {
      if (widget.occurrenceKey != null) 'occurrence': widget.occurrenceKey!,
    },
  ).toString();

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
    final spiritual = ref.read(spiritualSessionControllerProvider);
    if (spiritual.state.session?.id.startsWith('sacred-hour:$_sessionRoute:') ??
        false) {
      await spiritual.close();
    }
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

  void _attachPrayerPlayer(
    MemoryAudioPlaybackCoordinator player,
    PrivateAudioTrack track,
  ) {
    _prayerPlayer?.removeListener(_onPrayerPlaybackChanged);
    _soundBedGuard?.dispose();
    _selectedPrayerTrack = track;
    _prayerPlayer = player..addListener(_onPrayerPlaybackChanged);
    _soundBedGuard = SacredHourSoundBedGuard(
      player,
      track.id,
      _stopBackgroundSound,
    );
  }

  Future<void> _restoreSelectedPrayer() async {
    final track = _continuity?.track;
    if (track == null || !mounted) return;
    final player = await ref.read(
      memoryAudioPlaybackCoordinatorProvider.future,
    );
    if (!mounted ||
        !identical(_continuity?.track, track) ||
        _selectedPrayerTrack != null) {
      return;
    }
    _attachPrayerPlayer(player, track);
    _onPrayerPlaybackChanged();
  }

  Future<void> _togglePrayerPlayback() async {
    final player = _prayerPlayer;
    final track = _selectedPrayerTrack;
    if (player == null || track == null) return;
    final spiritual = ref.read(spiritualSessionControllerProvider);
    final sessionId = 'sacred-hour:$_sessionRoute:${track.id}';
    if (_prayerPlaying) {
      if (spiritual.state.session?.id == sessionId) await spiritual.pause();
    } else {
      if (spiritual.state.session?.id == sessionId) {
        await spiritual.resume();
      } else {
        await startSacredHourRecordedPlayback(
          spiritual: spiritual,
          player: player,
          track: track,
          route: _sessionRoute,
          systemPlaybackAvailable: ref.read(systemPlaybackAvailableProvider),
        );
      }
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
    final track = PrivateAudioTrack(
      id: audio.id,
      storageKey: audio.storageKey,
      duration: audio.duration,
    );
    _attachPrayerPlayer(player, track);
    _continuity?.track = track;
    await startSacredHourRecordedPlayback(
      spiritual: ref.read(spiritualSessionControllerProvider),
      player: player,
      track: _selectedPrayerTrack!,
      route: _sessionRoute,
      systemPlaybackAvailable: ref.read(systemPlaybackAvailableProvider),
    );
    _onPrayerPlaybackChanged();
  }

  Future<void> _showPrayerPicker(
    SacredHour hour,
    List<PrayerDisplay> suggestions,
  ) async {
    var addingPrayer = false;
    var recording = false;
    PersonalPrayer? pendingPrayer;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => PopScope(
          canPop: !recording,
          child: SacredHourPrayerPickerSheet(
            hour: hour,
            suggestions: suggestions,
            enabled: !recording,
            onClose: () => Navigator.pop(sheetContext),
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
            onAddPrayer: (_) => updateSheet(() => addingPrayer = true),
            addPrayerControl: addingPrayer
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InlineAudioCapture(
                        label: 'Record prayer',
                        draftSavedElsewhere: pendingPrayer != null,
                        beforeStart: _stopSanctuaryAudio,
                        onBusyChanged: (busy) {
                          if (sheetContext.mounted) {
                            updateSheet(() => recording = busy);
                          }
                        },
                        onDiscarded: () {
                          if (pendingPrayer != null && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Prayer saved. Try adding it again.',
                                ),
                              ),
                            );
                          }
                          pendingPrayer = null;
                        },
                        onSave: (audio) async {
                          final prayer = pendingPrayer ??=
                              await (await ref.read(
                                recordedPersonalPrayerRepositoryProvider.future,
                              )).create(
                                title: String.fromCharCodes(
                                  'Prayer · ${hour.name}'.runes.take(120),
                                ),
                                purpose:
                                    SacredHourPrayerSuggestions.primaryPurpose(
                                      hour,
                                    ),
                                audio: audio,
                              );
                          if (sheetContext.mounted) updateSheet(() {});
                          final repository = await ref.read(
                            sacredHourRepositoryProvider.future,
                          );
                          await repository.save(
                            SacredHourDraft.fromHour(
                              hour,
                              prayer: prayer.reference,
                            ),
                            id: hour.id,
                          );
                          ref.invalidate(personalPrayersProvider);
                          unawaited(_autoPlayChosenPrayer(prayer.reference));
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                      ),
                      if (!recording)
                        TextButton(
                          onPressed: () =>
                              updateSheet(() => addingPrayer = false),
                          child: const Text('Cancel'),
                        ),
                    ],
                  )
                : null,
          ),
        ),
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

  Future<void> _exit(SacredHour hour) async {
    _controller?.markDismissed();
    await _stopSanctuaryAudio();
    await SacredHourSystemNotification.stop();
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    }
  }
}

class SacredHourSessionView extends StatefulWidget {
  const SacredHourSessionView({
    required this.hour,
    required this.controller,
    required this.onRecordPrayer,
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
    this.beforeReflection,
    super.key,
  });

  final SacredHour hour;
  final SacredHourSessionController controller;
  final Future<void> Function() onRecordPrayer;
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
  final Future<void> Function()? beforeReflection;

  @override
  State<SacredHourSessionView> createState() => _SacredHourSessionViewState();
}

class _SacredHourSessionViewState extends State<SacredHourSessionView> {
  Timer? _ticker;
  var _saving = false;
  var _promptIndex = 0;
  String? _reflectionPrompt;
  bool _recordingBusy = false;

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
    onExit: _recordingBusy ? null : widget.onExit,
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

  Widget _meditationDock(BuildContext context) => Column(
    key: const Key('sacred-hour-meditation-dock'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SacredHourMeditationControls(
        prompt: _workPrompts[_promptIndex],
        onReflect: _recordingBusy
            ? null
            : () => setState(
                () => _reflectionPrompt = _workPrompts[_promptIndex],
              ),
        onAnotherReflection: _recordingBusy
            ? null
            : () => setState(
                () => _promptIndex = (_promptIndex + 1) % _workPrompts.length,
              ),
      ),
      if (_reflectionPrompt case final prompt?)
        InlineMemoryRecorder(
          enableSoundscape: false,
          label: 'Record reflection',
          initialTitle:
              '$prompt · ${MaterialLocalizations.of(context).formatShortDate(DateTime.now())}',
          initialPersonIds: widget.hour.personId == null
              ? const []
              : [widget.hour.personId!],
          privateReflection: true,
          beforeStart: widget.beforeReflection,
          onBusyChanged: (busy) {
            if (mounted) {
              setState(() {
                _recordingBusy = busy;
                if (!busy) _reflectionPrompt = null;
              });
            }
          },
        ),
    ],
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
