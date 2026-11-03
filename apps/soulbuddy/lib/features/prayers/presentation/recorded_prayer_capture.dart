import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../record/audio/application/audio_capture_controller.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/presentation/audio_capture_panel.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../domain/library_prayer.dart';
import '../domain/personal_prayer.dart';
import '../domain/voice_tablet.dart';
import '../providers/recorded_personal_prayer_providers.dart';
import '../providers/voice_tablet_providers.dart';

Future<PersonalPrayer?> showRecordedPrayerCapture(
  BuildContext context, {
  String title = 'My prayer',
  PrayerPurpose purpose = PrayerPurpose.daily,
}) => showModalBottomSheet<PersonalPrayer>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  useSafeArea: true,
  builder: (_) => _RecordedPrayerCapture(title: title, purpose: purpose),
);

class _RecordedPrayerCapture extends ConsumerStatefulWidget {
  const _RecordedPrayerCapture({required this.title, required this.purpose});
  final String title;
  final PrayerPurpose purpose;

  @override
  ConsumerState<_RecordedPrayerCapture> createState() => _RecordedPrayerCaptureState();
}

class _RecordedPrayerCaptureState extends ConsumerState<_RecordedPrayerCapture> {
  late final _title = TextEditingController();
  RecordedAudioDraft? _draft;
  bool _saving = false;
  bool _closing = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save(RecordedAudioDraft draft) async {
    if (_saving) return;
    setState(() { _draft = draft; _saving = true; _error = null; });
    try {
      final repository = await ref.read(recordedPersonalPrayerRepositoryProvider.future);
      final title = _title.text.trim();
      final prayer = await repository.create(
        title: title.isEmpty ? String.fromCharCodes(widget.title.runes.take(80)) : title,
        audio: draft,
        purpose: widget.purpose,
      );
      _draft = null;
      if (mounted) Navigator.pop(context, prayer);
    } catch (_) {
      if (mounted) setState(() => _error = 'Recording kept. Try saving again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_saving || _closing) return;
    final controller = ref.read(
      voiceTabletAudioCaptureControllerProvider(VoiceTabletAudioKind.fullPrayer),
    ).value;
    if (controller?.state.commandInFlight == true) return;
    _closing = true;
    try {
      await controller?.handleInterruption();
      if (controller?.state.phase == AudioCapturePhase.failure &&
          controller?.hasPendingRecording == true &&
          controller?.state.review == null) {
        // An unsuccessful pause may leave the microphone active. The capture
        // surface keeps its explicit discard/retry controls visible.
        return;
      }
      if (_draft != null || controller?.hasPendingRecording == true) {
        if (!mounted) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard recording?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
            ],
          ),
        );
        if (discard != true) return;
      }
      if (_draft case final draft?) {
        final store = await ref.read(audioAssetStoreProvider.future);
        await store.discardTemporary(draft.temporaryKey);
        _draft = null;
      } else if (controller?.hasPendingRecording == true) {
        if (controller!.state.review != null) {
          await controller.discard();
        } else {
          await controller.cancel();
        }
        if (controller.hasPendingRecording) {
          throw StateError('Recording cleanup is incomplete');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Recording could not be discarded. Retry.');
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(
      voiceTabletAudioCaptureControllerProvider(VoiceTabletAudioKind.fullPrayer),
    );
    final panelHandlesBack = _draft == null && capture.when(
      data: (_) => true,
      loading: () => false,
      error: (_, _) => false,
    );
    return PopScope(
      canPop: panelHandlesBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !panelHandlesBack) unawaited(_close());
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .94,
        child: _draft != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_saving) const CircularProgressIndicator(),
                    if (_error != null) Text(_error!),
                    if (!_saving) ...[
                      FilledButton(onPressed: () => _save(_draft!), child: const Text('Retry save')),
                      TextButton(onPressed: _close, child: const Text('Discard')),
                    ],
                  ],
                ),
              )
            : capture.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: TextButton(onPressed: _close, child: const Text('Recording unavailable · Close'))),
                data: (controller) => AudioCapturePanel(
                  controller: controller,
                  handlesSystemBack: true,
                  introHeading: 'Record prayer',
                  introDescription: 'Private · on this device',
                  introContent: TextField(
                    controller: _title,
                    maxLength: 80,
                    maxLines: 1,
                    decoration: InputDecoration(labelText: 'Title · optional', hintText: widget.title),
                  ),
                  enableSoundscape: true,
                  continueLabel: 'Save prayer',
                  onBack: _close,
                  onContinue: (draft) => unawaited(_save(draft)),
                ),
              ),
      ),
    );
  }
}
