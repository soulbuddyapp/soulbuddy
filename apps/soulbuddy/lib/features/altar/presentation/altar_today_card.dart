import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/voice_tablet.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/voice_tablet_providers.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/presentation/audio_playback_control.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/providers/encounter_providers.dart';
import '../domain/altar_ritual.dart';
import '../providers/altar_ritual_providers.dart';

class AltarTodaySection extends ConsumerWidget {
  const AltarTodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(altarEncountersProvider).value ?? const [];
    final latest = memories.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AltarPrayerTodaySection(showEmpty: latest == null),
        if (latest != null) ...[
          AltarMemoryTodayCard(
            memory: latest,
            onOpen: () => context.push('/remember/${latest.id}'),
          ),
          if (memories.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/remember?filter=altar'),
                child: Text('See all ${memories.length} Altar Memories'),
              ),
            ),
        ],
      ],
    );
  }
}

class _AltarPrayerTodaySection extends ConsumerWidget {
  const _AltarPrayerTodaySection({required this.showEmpty});

  final bool showEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueAltarRitualProvider);
    return due.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) =>
          showEmpty ? const AltarTodayEmptyCard() : const SizedBox.shrink(),
      data: (value) {
        if (value == null) {
          return showEmpty
              ? const AltarTodayEmptyCard()
              : const SizedBox.shrink();
        }
        if (value.item.target.type != AltarTargetType.voiceTablet) {
          return showEmpty
              ? const AltarTodayEmptyCard()
              : const SizedBox.shrink();
        }
        final tablet = ref.watch(
          voiceTabletProvider(value.item.target.targetId),
        );
        return tablet.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _AltarUnavailableCard(),
          data: (voiceTablet) {
            if (voiceTablet == null) return const _AltarUnavailableCard();
            final pendingRitual = ref.watch(pendingAltarOpenProvider);
            if (pendingRitual == value.ritual.id) {
              ref.read(pendingAltarOpenProvider.notifier).clear();
              if (value.autoplayWhenOpened) {
                _autoplayOnce(ref, value, voiceTablet);
              }
            }
            return AltarTodayCard(
              due: value,
              tablet: voiceTablet,
              onListen: () => _listenToAltar(ref, value, voiceTablet),
              onPrayed: () => _recordAltarPrayer(ref, value, voiceTablet),
              onUndo: (sessionId) => _undoAltarPrayer(ref, value, sessionId),
            );
          },
        );
      },
    );
  }

  void _autoplayOnce(WidgetRef ref, DueAltarRitual due, VoiceTablet tablet) {
    final occurrenceKey =
        '${due.ritual.id}@${due.occurrenceAt.toUtc().toIso8601String()}';
    if (!ref.read(altarAutoplayClaimProvider.notifier).claim(occurrenceKey)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_listenToAltar(ref, due, tablet).catchError((_) {}));
    });
  }
}

class AltarReminderOverlayHost extends ConsumerWidget {
  const AltarReminderOverlayHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueAltarRitualProvider).value;
    if (due == null || due.localStatus != AltarRitualLocalStatus.due) {
      return const SizedBox.shrink();
    }
    if (due.item.target.type != AltarTargetType.voiceTablet) {
      return const SizedBox.shrink();
    }
    final tablet = ref
        .watch(voiceTabletProvider(due.item.target.targetId))
        .value;
    if (tablet == null) return const SizedBox.shrink();
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          elevation: 8,
          color: Colors.transparent,
          child: AltarTodayCard(
            due: due,
            tablet: tablet,
            onListen: () => _listenToAltar(ref, due, tablet),
            onPrayed: () => _recordAltarPrayer(ref, due, tablet),
            onUndo: (sessionId) => _undoAltarPrayer(ref, due, sessionId),
          ),
        ),
      ),
    );
  }
}

Future<void> _listenToAltar(
  WidgetRef ref,
  DueAltarRitual due,
  VoiceTablet tablet,
) async {
  final audio = switch (due.ritual.playbackMode) {
    AltarPlaybackMode.refrain => tablet.refrainAudio,
    AltarPlaybackMode.fullPrayer => tablet.fullAudio,
    AltarPlaybackMode.openQuietly => null,
  };
  if (audio == null) return;
  final coordinator = await ref.read(
    memoryAudioPlaybackCoordinatorProvider.future,
  );
  final track = PrivateAudioTrack(
    id: audio.id,
    storageKey: audio.storageKey,
    duration: audio.duration,
  );
  final spiritual = ref.read(spiritualSessionControllerProvider);
  final sessionId =
      'altar:${due.ritual.id}@${due.occurrenceAt.toUtc().toIso8601String()}';
  late VoidCallback listener;
  var starting = true;
  listener = () {
    final state = coordinator.state;
    if (spiritual.state.session?.id != sessionId) {
      coordinator.removeListener(listener);
      return;
    }
    if (state.assetId != audio.id) {
      if (!starting) {
        coordinator.removeListener(listener);
        spiritual.finishPlayback(sessionId);
      }
      return;
    }
    spiritual.updateProgress(
      sessionId: sessionId,
      position: state.position,
      duration: state.duration,
      status: state.status == MemoryAudioPlaybackStatus.paused
          ? SpiritualSessionStatus.paused
          : state.status == MemoryAudioPlaybackStatus.playing
          ? SpiritualSessionStatus.playing
          : null,
    );
    if (!starting &&
        (state.status == MemoryAudioPlaybackStatus.completed ||
            state.status == MemoryAudioPlaybackStatus.idle ||
            state.status == MemoryAudioPlaybackStatus.error)) {
      coordinator.removeListener(listener);
      spiritual.finishPlayback(sessionId);
    }
  };
  await spiritual.begin(
    SpiritualSession(
      id: sessionId,
      kind: SpiritualSessionKind.altar,
      title: tablet.title,
      route: '/today?focus=altar',
      canPause: true,
      supportsSystemPlayback: true,
      onSeek: coordinator.seek,
      completionLabel: 'I prayed',
      onStart: () async {
        coordinator.addListener(listener);
        try {
          await coordinator.playTrack(track);
        } finally {
          starting = false;
          listener();
        }
      },
      onPause: coordinator.pause,
      onResume: () => coordinator.playTrack(track),
      onComplete: () async {
        coordinator.removeListener(listener);
        if (coordinator.state.assetId == audio.id) await coordinator.stop();
        await _recordAltarPrayer(ref, due, tablet);
      },
      onClose: () async {
        coordinator.removeListener(listener);
        if (coordinator.state.assetId == audio.id) await coordinator.stop();
      },
    ),
  );
}

Future<String> _recordAltarPrayer(
  WidgetRef ref,
  DueAltarRitual due,
  VoiceTablet tablet,
) async {
  final repository = await ref.read(prayerPracticeRepositoryProvider.future);
  final timezone = await ref.read(prayerDeviceTimezoneProvider)();
  final source = tablet.source;
  final session = await repository.recordSession(
    prayer: source.type == VoiceTabletSourceType.personalPrayer
        ? PrayerReference.personal(source.prayerId)
        : PrayerReference.library(source.prayerId),
    revisionId: source.revisionId,
    timezone: timezone,
    idempotencyKey:
        '${due.ritual.id}@${due.occurrenceAt.toUtc().toIso8601String()}',
  );
  final altarRepository = await ref.read(altarRitualRepositoryProvider.future);
  await altarRepository.markPrayed(
    ritualId: due.ritual.id,
    occurrenceAt: due.occurrenceAt,
    localDate: session.localDate,
    prayerSessionId: session.id,
  );
  await altarRepository.advance(
    due.ritual.id,
    afterUtc: due.occurrenceAt.toUtc(),
  );
  return session.id;
}

Future<void> _undoAltarPrayer(
  WidgetRef ref,
  DueAltarRitual due,
  String sessionId,
) async {
  final repository = await ref.read(prayerPracticeRepositoryProvider.future);
  await repository.retractSession(sessionId);
  final altarRepository = await ref.read(altarRitualRepositoryProvider.future);
  await altarRepository.retractPrayer(
    ritualId: due.ritual.id,
    occurrenceAt: due.occurrenceAt,
  );
}

class AltarMemoryTodayCard extends ConsumerWidget {
  const AltarMemoryTodayCard({
    required this.memory,
    required this.onOpen,
    super.key,
  });

  final Encounter memory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref
        .watch(memoryAudioForEncounterProvider(memory.id))
        .whenOrNull(data: (value) => value);
    return Card(
      key: const Key('altar-memory-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                        'At your Altar',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        memory.sensitive
                            ? 'Private Altar Memory'
                            : memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (audio != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AudioPlaybackControl(
                audio: audio,
                compact: true,
                label: 'Voice Memory',
                playLabel: 'Listen',
                sessionKind: SpiritualSessionKind.altar,
                sessionRoute: '/remember/${memory.id}',
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('open-altar-memory'),
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Memory'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AltarTodayCard extends StatefulWidget {
  const AltarTodayCard({
    required this.due,
    required this.tablet,
    required this.onListen,
    required this.onPrayed,
    this.onUndo,
    super.key,
  });

  final DueAltarRitual due;
  final VoiceTablet tablet;
  final FutureOr<void> Function() onListen;
  final FutureOr<String?> Function() onPrayed;
  final FutureOr<void> Function(String sessionId)? onUndo;

  @override
  State<AltarTodayCard> createState() => _AltarTodayCardState();
}

class _AltarTodayCardState extends State<AltarTodayCard> {
  var _listening = false;
  var _recording = false;
  var _prayed = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final canListen =
        widget.due.ritual.playbackMode != AltarPlaybackMode.openQuietly &&
        widget.due.hasLocalAudio;
    return ClipPath(
      clipper: const _AltarCardClipper(),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CovenantPairedSlabMark(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'At your Altar',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          widget.tablet.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (canListen) ...[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('altar-listen'),
                        onPressed: _listening ? null : _listen,
                        icon: Icon(
                          _listening ? Icons.graphic_eq : Icons.play_arrow,
                        ),
                        label: Text(_listening ? 'Opening…' : 'Listen'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('altar-prayed'),
                      onPressed: _recording || _prayed ? null : _pray,
                      icon: Icon(
                        _prayed ? Icons.check : Icons.front_hand_outlined,
                      ),
                      label: Text(
                        _prayed
                            ? 'Prayed today'
                            : _recording
                            ? 'Recording…'
                            : 'I prayed',
                      ),
                    ),
                  ),
                ],
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
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

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _error = null;
    });
    try {
      await widget.onListen();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play this prayer.');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _pray() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _recording = true;
      _error = null;
    });
    try {
      final sessionId = await widget.onPrayed();
      if (mounted) setState(() => _prayed = true);
      if (sessionId != null && widget.onUndo != null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Prayer recorded.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(_undo(sessionId)),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not record this prayer just now.');
      }
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _undo(String sessionId) async {
    try {
      await widget.onUndo?.call(sessionId);
      if (mounted) setState(() => _prayed = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not undo this record.');
    }
  }
}

class AltarTodayEmptyCard extends StatelessWidget {
  const AltarTodayEmptyCard({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const CovenantPairedSlabMark(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'At your Altar',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Text('Keep a prayer or memory before you.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AltarUnavailableCard extends StatelessWidget {
  const _AltarUnavailableCard();

  @override
  Widget build(BuildContext context) => const AltarTodayEmptyCard();
}

class _AltarCardClipper extends CustomClipper<Path> {
  const _AltarCardClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(4, 2)
    ..lineTo(size.width * 0.36, 0)
    ..lineTo(size.width - 3, 3)
    ..lineTo(size.width, size.height - 5)
    ..lineTo(size.width * 0.62, size.height)
    ..lineTo(2, size.height - 2)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
