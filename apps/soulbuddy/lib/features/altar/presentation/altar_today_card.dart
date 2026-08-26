import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/covenant_marks.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/voice_tablet.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/voice_tablet_providers.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../domain/altar_ritual.dart';
import '../providers/altar_ritual_providers.dart';

class AltarTodaySection extends ConsumerWidget {
  const AltarTodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueAltarRitualProvider);
    return due.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const AltarTodayEmptyCard(),
      data: (value) {
        if (value == null) return const AltarTodayEmptyCard();
        if (value.item.target.type != AltarTargetType.voiceTablet) {
          return const AltarTodayEmptyCard();
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_listen(ref, value, voiceTablet));
              });
            }
            return AltarTodayCard(
              due: value,
              tablet: voiceTablet,
              onListen: () => _listen(ref, value, voiceTablet),
              onPrayed: () => _recordPrayer(ref, value, voiceTablet),
            );
          },
        );
      },
    );
  }

  Future<void> _listen(
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
    await coordinator.playTrack(
      PrivateAudioTrack(
        id: audio.id,
        storageKey: audio.storageKey,
        duration: audio.duration,
      ),
    );
  }

  Future<void> _recordPrayer(
    WidgetRef ref,
    DueAltarRitual due,
    VoiceTablet tablet,
  ) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final timezone = await ref.read(prayerDeviceTimezoneProvider)();
    final source = tablet.source;
    await repository.recordSession(
      prayer: source.type == VoiceTabletSourceType.personalPrayer
          ? PrayerReference.personal(source.prayerId)
          : PrayerReference.library(source.prayerId),
      revisionId: source.revisionId,
      timezone: timezone,
    );
    final altarRepository = await ref.read(
      altarRitualRepositoryProvider.future,
    );
    await altarRepository.advance(
      due.ritual.id,
      afterUtc: due.occurrenceAt.toUtc(),
    );
  }
}

class AltarTodayCard extends StatefulWidget {
  const AltarTodayCard({
    required this.due,
    required this.tablet,
    required this.onListen,
    required this.onPrayed,
    super.key,
  });

  final DueAltarRitual due;
  final VoiceTablet tablet;
  final FutureOr<void> Function() onListen;
  final FutureOr<void> Function() onPrayed;

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
    setState(() {
      _recording = true;
      _error = null;
    });
    try {
      await widget.onPrayed();
      if (mounted) setState(() => _prayed = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not record this prayer just now.');
      }
    } finally {
      if (mounted) setState(() => _recording = false);
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
