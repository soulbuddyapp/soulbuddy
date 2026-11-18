import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import '../../prayers/application/bundled_prayer_audio.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../data/person_prayer_audio_repository.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/data/audio_asset_store.dart';
import '../../record/audio/presentation/audio_capture_panel.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../providers/person_prayer_audio_providers.dart';

Future<void> showPersonPrayerRecording(BuildContext context, String personId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: _PersonPrayerRecorder(personId: personId),
      ),
    );

class _PersonPrayerRecorder extends ConsumerStatefulWidget {
  const _PersonPrayerRecorder({required this.personId});
  final String personId;
  @override
  ConsumerState<_PersonPrayerRecorder> createState() =>
      _PersonPrayerRecorderState();
}

class _PersonPrayerRecorderState extends ConsumerState<_PersonPrayerRecorder> {
  bool saving = false;
  String? error;
  RecordedAudioDraft? pendingDraft;
  AudioAssetStore? pendingStore;
  @override
  void dispose() {
    final draft = pendingDraft;
    final store = pendingStore;
    if (draft != null && store != null) {
      unawaited(store.discardTemporary(draft.temporaryKey).catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> save(RecordedAudioDraft draft) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
      pendingDraft = draft;
      pendingStore = ref.read(audioAssetStoreProvider).value;
    });
    try {
      await (await ref.read(
        personPrayerAudioRepositoryProvider.future,
      )).save(widget.personId, draft);
      pendingDraft = null;
      ref.invalidate(personPrayerAudioProvider(widget.personId));
      ref.invalidate(personPrayerAudioPlaybackProvider);
      if (mounted) {
        setState(() => saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save the recording. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(audioCaptureControllerProvider);
    return PopScope(
      canPop: !saving,
      child: Column(
        children: [
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          if (saving) const LinearProgressIndicator(),
          if (pendingDraft != null && !saving && error != null)
            Column(
              children: [
                FilledButton(
                  onPressed: () => save(pendingDraft!),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          Expanded(
            child: pendingDraft != null
                ? const SizedBox.shrink()
                : capture.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(audioCaptureControllerProvider),
                        child: const Text('Try again'),
                      ),
                    ),
                    data: (controller) => AudioCapturePanel(
                      controller: controller,
                      introHeading: 'Record a prayer',
                      introDescription: 'Pray in your own words.',
                      alternativeLabel: 'Not now',
                      onWriteInstead: () => Navigator.pop(context),
                      onContinue: save,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class PersonPrayerAudioSection extends ConsumerStatefulWidget {
  const PersonPrayerAudioSection({
    super.key,
    required this.personId,
    this.autoplay = false,
  });
  final String personId;
  final bool autoplay;
  @override
  ConsumerState<PersonPrayerAudioSection> createState() =>
      _PersonPrayerAudioSectionState();
}

class _PersonPrayerAudioSectionState
    extends ConsumerState<PersonPrayerAudioSection> {
  bool _attempted = false;
  @override
  void didUpdateWidget(covariant PersonPrayerAudioSection old) {
    super.didUpdateWidget(old);
    if (old.personId != widget.personId || (!old.autoplay && widget.autoplay)) {
      _attempted = false;
    }
  }

  Future<void> _startIfAllowed(PersonPrayerAudio audio) async {
    try {
      final environment = ref.read(prayerAudioEnvironmentProvider);
      final route = await environment.currentRoute();
      final allowed = await environment.interruptionsAllowed();
      if (!mounted ||
          !allowBundledReminderAutoplay(
            isIOS: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
            route: route,
            interruptionsAllowed: allowed,
          )) {
        return;
      }
      final player = await ref.read(personPrayerAudioPlaybackProvider.future);
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      await player.playTrack(
        PrivateAudioTrack(
          id: audio.storageKey,
          storageKey: audio.storageKey,
          duration: audio.duration,
        ),
      );
    } catch (_) {
      // The manual play control remains available.
    }
  }

  @override
  Widget build(BuildContext context) {
    final personId = widget.personId;
    final audio = ref.watch(personPrayerAudioProvider(personId));
    return audio.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(personPrayerAudioProvider(personId)),
        child: const Text('Try prayer recording again'),
      ),
      data: (value) {
        if (value != null && widget.autoplay && !_attempted) {
          _attempted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_startIfAllowed(value));
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value != null)
              ref
                  .watch(personPrayerAudioPlaybackProvider)
                  .when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Prayer audio is unavailable.'),
                    data: (player) => PracticeAudioScope(
                      onVisibilityChanged: (visible) {
                        if (!visible &&
                            player.state.assetId == value.storageKey) {
                          unawaited(player.stop());
                        }
                      },
                      child: AnimatedBuilder(
                        animation: player,
                        builder: (context, _) {
                          final playing =
                              player.state.assetId == value.storageKey &&
                              player.state.status ==
                                  MemoryAudioPlaybackStatus.playing;
                          return OutlinedButton.icon(
                            onPressed: () => playing
                                ? player.stop()
                                : player.playTrack(
                                    PrivateAudioTrack(
                                      id: value.storageKey,
                                      storageKey: value.storageKey,
                                      duration: value.duration,
                                    ),
                                  ),
                            icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                            label: Text(
                              playing ? 'Stop prayer' : 'Play prayer',
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            TextButton.icon(
              onPressed: () => showPersonPrayerRecording(context, personId),
              icon: const Icon(Icons.mic_none),
              label: Text(value == null ? 'Record a prayer' : 'Record again'),
            ),
            if (value != null)
              TextButton(
                onPressed: () async {
                  try {
                    final player = ref
                        .read(personPrayerAudioPlaybackProvider)
                        .value;
                    if (player?.state.assetId == value.storageKey) {
                      await player?.stop();
                    }
                    await (await ref.read(
                      personPrayerAudioRepositoryProvider.future,
                    )).remove(personId);
                    ref.invalidate(personPrayerAudioPlaybackProvider);
                    ref.invalidate(personPrayerAudioProvider(personId));
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not remove the recording.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Remove recording'),
              ),
          ],
        );
      },
    );
  }
}
