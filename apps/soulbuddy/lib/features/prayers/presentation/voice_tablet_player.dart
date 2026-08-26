import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_session.dart';
import '../domain/voice_tablet.dart';
import '../providers/prayer_practice_providers.dart';
import '../providers/voice_tablet_providers.dart';
import 'voice_tablet_sheet.dart';

class VoiceTabletSection extends ConsumerWidget {
  const VoiceTabletSection({
    required this.source,
    required this.title,
    required this.prayerBody,
    this.onKeepOnAltar,
    super.key,
  });

  final VoiceTabletSource source;
  final String title;
  final String prayerBody;
  final FutureOr<void> Function(VoiceTablet)? onKeepOnAltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablet = ref.watch(voiceTabletForSourceProvider(source));
    return tablet.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => OutlinedButton.icon(
        onPressed: () => ref.invalidate(voiceTabletForSourceProvider(source)),
        icon: const Icon(Icons.refresh),
        label: const Text('Try Voice Tablet again'),
      ),
      data: (value) => value == null
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
              ),
              onPressed: () => showVoiceTabletSheet(
                context,
                source: source,
                title: title,
                prayerBody: prayerBody,
              ),
              icon: const Icon(Icons.mic_none),
              label: const Text('Record in my voice'),
            )
          : VoiceTabletPlayer(tablet: value, onKeepOnAltar: onKeepOnAltar),
    );
  }
}

class VoiceTabletPlayer extends ConsumerStatefulWidget {
  const VoiceTabletPlayer({
    required this.tablet,
    this.onRecordAgain,
    this.onKeepOnAltar,
    this.onPlayed,
    this.onPrayed,
    super.key,
  });

  final VoiceTablet tablet;
  final VoidCallback? onRecordAgain;
  final FutureOr<void> Function(VoiceTablet)? onKeepOnAltar;
  final FutureOr<void> Function(VoiceTabletAudio)? onPlayed;
  final FutureOr<void> Function()? onPrayed;

  @override
  ConsumerState<VoiceTabletPlayer> createState() => _VoiceTabletPlayerState();
}

class _VoiceTabletPlayerState extends ConsumerState<VoiceTabletPlayer> {
  late VoiceTabletAudioKind _selectedKind;
  var _savingPrayer = false;
  var _removing = false;
  PrayerSession? _lastSession;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _selectedKind = VoiceTabletAudioKind.fullPrayer;
  }

  VoiceTabletAudio? get _selectedAudio =>
      _selectedKind == VoiceTabletAudioKind.refrain
      ? widget.tablet.refrainAudio
      : widget.tablet.fullAudio;

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(memoryAudioPlaybackCoordinatorProvider);
    return ClipPath(
      clipper: const _VoiceTabletClipper(),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CovenantPairedSlabMark(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Tablet',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          widget.tablet.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_TabletAction>(
                    tooltip: 'Voice Tablet options',
                    enabled: !_removing,
                    onSelected: _handleMenu,
                    itemBuilder: (_) => [
                      if (widget.onRecordAgain != null)
                        const PopupMenuItem(
                          value: _TabletAction.recordAgain,
                          child: Text('Record again'),
                        ),
                      const PopupMenuItem(
                        value: _TabletAction.remove,
                        child: Text('Remove Voice Tablet'),
                      ),
                    ],
                  ),
                ],
              ),
              const CovenantIncisedDivider(),
              if (widget.tablet.refrainAudio != null) ...[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Full prayer'),
                      selected:
                          _selectedKind == VoiceTabletAudioKind.fullPrayer,
                      onSelected: (_) => _select(
                        VoiceTabletAudioKind.fullPrayer,
                        coordinator.value,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Refrain'),
                      selected: _selectedKind == VoiceTabletAudioKind.refrain,
                      onSelected: (_) => _select(
                        VoiceTabletAudioKind.refrain,
                        coordinator.value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_selectedAudio case final audio?) ...[
                _Waveform(samples: audio.waveform),
                const SizedBox(height: AppSpacing.sm),
                coordinator.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Text(
                    'Playback is unavailable just now.',
                    textAlign: TextAlign.center,
                  ),
                  data: (value) => _PlaybackControls(
                    coordinator: value,
                    audio: audio,
                    onPlayed: widget.onPlayed,
                  ),
                ),
              ] else
                const Text(
                  'This recording is not on this device.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                ),
                onPressed: _savingPrayer ? null : _recordPrayer,
                icon: _savingPrayer
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_lastSession == null ? 'I prayed' : 'Prayed today'),
              ),
              if (_lastSession != null)
                Center(
                  child: TextButton(
                    onPressed: _savingPrayer ? null : _undoPrayer,
                    child: const Text('Undo'),
                  ),
                ),
              if (widget.onKeepOnAltar != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
                  ),
                  onPressed: () => widget.onKeepOnAltar!(widget.tablet),
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Keep on my Altar'),
                ),
              ],
              if (_actionError case final error?) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    VoiceTabletAudioKind kind,
    MemoryAudioPlaybackCoordinator? coordinator,
  ) async {
    if (kind == _selectedKind) return;
    await coordinator?.stop();
    if (mounted) setState(() => _selectedKind = kind);
  }

  Future<void> _recordPrayer() async {
    if (_savingPrayer) return;
    setState(() {
      _savingPrayer = true;
      _actionError = null;
    });
    try {
      if (widget.onPrayed != null) {
        await widget.onPrayed!();
      } else {
        final repository = await ref.read(
          prayerPracticeRepositoryProvider.future,
        );
        final timezone = await ref.read(prayerDeviceTimezoneProvider)();
        final source = widget.tablet.source;
        _lastSession = await repository.recordSession(
          prayer: source.type == VoiceTabletSourceType.personalPrayer
              ? PrayerReference.personal(source.prayerId)
              : PrayerReference.library(source.prayerId),
          revisionId: source.revisionId,
          timezone: timezone,
        );
      }
      if (mounted) setState(() => _savingPrayer = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _actionError = 'Could not record this prayer just now.';
        });
      }
    }
  }

  Future<void> _undoPrayer() async {
    final session = _lastSession;
    if (_savingPrayer || session == null) return;
    setState(() => _savingPrayer = true);
    try {
      final repository = await ref.read(
        prayerPracticeRepositoryProvider.future,
      );
      await repository.retractSession(session.id);
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _lastSession = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingPrayer = false;
          _actionError = 'Could not undo this prayer record just now.';
        });
      }
    }
  }

  Future<void> _handleMenu(_TabletAction action) async {
    if (action == _TabletAction.recordAgain) {
      widget.onRecordAgain?.call();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this Voice Tablet?'),
        content: const Text(
          'Its private recordings will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final repository = await ref.read(voiceTabletRepositoryProvider.future);
      final store = await ref.read(audioAssetStoreProvider.future);
      final keys = await repository.archive(widget.tablet.id);
      for (final key in keys) {
        await store.delete(key);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _removing = false;
          _actionError = 'The Voice Tablet could not be removed just now.';
        });
      }
    }
  }
}

class _PlaybackControls extends StatefulWidget {
  const _PlaybackControls({
    required this.coordinator,
    required this.audio,
    required this.onPlayed,
  });

  final MemoryAudioPlaybackCoordinator coordinator;
  final VoiceTabletAudio audio;
  final FutureOr<void> Function(VoiceTabletAudio)? onPlayed;

  @override
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls> {
  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _PlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeListener(_changed);
      widget.coordinator.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.coordinator.state;
    final selected = state.assetId == widget.audio.id;
    final playing =
        selected && state.status == MemoryAudioPlaybackStatus.playing;
    final position = selected ? state.position : Duration.zero;
    return Column(
      children: [
        Semantics(
          label: '${_spoken(position)} of ${_spoken(widget.audio.duration)}',
          child: Slider(
            value: position.inMilliseconds
                .clamp(0, widget.audio.duration.inMilliseconds)
                .toDouble(),
            max: widget.audio.duration.inMilliseconds.toDouble(),
            onChanged: selected
                ? (value) => widget.coordinator.seek(
                    Duration(milliseconds: value.round()),
                  )
                : null,
          ),
        ),
        Text(
          '${_clock(position)} / ${_clock(widget.audio.duration)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
          ),
          onPressed: () => _toggle(playing, state),
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          label: Text(playing ? 'Pause' : 'Listen'),
        ),
        if (selected && state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(bool playing, MemoryAudioPlaybackState state) async {
    if (playing) {
      await widget.coordinator.pause();
      return;
    }
    if (state.assetId == widget.audio.id &&
        state.status == MemoryAudioPlaybackStatus.paused) {
      await widget.coordinator.playTrack(_track(widget.audio));
    } else {
      await widget.coordinator.playTrack(_track(widget.audio));
    }
    await widget.onPlayed?.call(widget.audio);
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.samples});

  final List<double> samples;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final sample in samples.take(48))
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 6 + sample * 36,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.72),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _VoiceTabletClipper extends CustomClipper<Path> {
  const _VoiceTabletClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(6, 4)
    ..lineTo(size.width * 0.28, 0)
    ..lineTo(size.width * 0.66, 3)
    ..lineTo(size.width - 5, 1)
    ..lineTo(size.width, size.height * 0.38)
    ..lineTo(size.width - 2, size.height - 7)
    ..lineTo(size.width * 0.72, size.height)
    ..lineTo(size.width * 0.31, size.height - 3)
    ..lineTo(3, size.height)
    ..lineTo(0, size.height * 0.43)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

PrivateAudioTrack _track(VoiceTabletAudio audio) => PrivateAudioTrack(
  id: audio.id,
  storageKey: audio.storageKey,
  duration: audio.duration,
);

String _clock(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spoken(Duration value) =>
    '${value.inMinutes} minutes ${value.inSeconds % 60} seconds';

enum _TabletAction { recordAgain, remove }
