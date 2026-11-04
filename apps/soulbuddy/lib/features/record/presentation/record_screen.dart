import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/feedback/app_feedback.dart';
import '../../../core/feedback/app_feedback_preferences.dart';
import '../../../core/feedback/app_feedback_providers.dart';
import '../../../core/presentation/feature_page.dart';
import '../../../core/storage/persistent_storage.dart';
import '../audio/application/audio_capture_controller.dart';
import '../audio/domain/memory_audio.dart';
import '../audio/domain/memory_soundscape.dart';
import '../audio/presentation/audio_capture_panel.dart';
import '../audio/providers/memory_audio_providers.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../providers/encounter_providers.dart';
import 'encounter_form.dart';
import '../../persons/providers/person_providers.dart';
import '../../persons/domain/prayer_person.dart';

enum _RecordView { capture, form }

// Keep legacy route values so old links continue to their intended task.
enum RecordStartMode { choices, speak, write, reflection, person }

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({
    super.key,
    this.startMode = RecordStartMode.choices,
    this.initialPersonIds = const [],
    this.initialBodyPrompt,
    this.initialTitle,
    this.initialDate,
    this.allowMemoryTypeChoice = false,
    this.privateReflection = false,
    this.onMemorySaved,
    this.onCancel,
  });

  final RecordStartMode startMode;
  final List<String> initialPersonIds;
  final String? initialBodyPrompt;
  final String? initialTitle;
  final DateTime? initialDate;
  final bool allowMemoryTypeChoice;
  final bool privateReflection;
  final ValueChanged<Encounter>? onMemorySaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late var _view = widget.startMode == RecordStartMode.write
      ? _RecordView.form
      : _RecordView.capture;
  late final _memoryType = widget.startMode == RecordStartMode.person
      ? MemoryType.person
      : MemoryType.encounter;
  MemoryAudioDraft? _audioDraft;
  var _leaving = false;

  @override
  Widget build(BuildContext context) {
    final people = _view == _RecordView.form
        ? ref.watch(prayerPeopleProvider).value ?? const <PrayerPerson>[]
        : const <PrayerPerson>[];
    // Keep the recorder alive while the reviewed draft belongs to the form.
    final audioController = _view == _RecordView.capture || _audioDraft != null
        ? ref.watch(audioCaptureControllerProvider)
        : null;
    final panelHandlesBack =
        audioController?.when(
          data: (_) => true,
          loading: () => false,
          error: (_, _) => false,
        ) ??
        false;
    void leaveCapture() {
      final controller = audioController?.value;
      if (controller != null) {
        unawaited(_leaveCapture(controller));
      } else {
        _exit();
      }
    }

    return switch (_view) {
      // Once transferred, the take belongs to the form even while storage is
      // loading or unavailable. Provider retries must not unmount that owner.
      _RecordView.form => EncounterForm(
        memoryType: _memoryType,
        allowMemoryTypeChoice:
            widget.allowMemoryTypeChoice ||
            _audioDraft != null ||
            widget.startMode == RecordStartMode.person,
        initialTitle: widget.initialTitle,
        bodyPrompt: widget.initialBodyPrompt,
        initialWriting: widget.startMode == RecordStartMode.write,
        initialDate: widget.initialDate,
        audio: _audioDraft,
        people: people,
        initialPersonIds: widget.initialPersonIds,
        initialSensitive: widget.privateReflection,
        initialRecallEnabled: !widget.privateReflection,
        onCancel: _cancelForm,
        onSave: _saveEncounter,
      ),
      _RecordView.capture => PopScope(
        canPop: panelHandlesBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !panelHandlesBack) leaveCapture();
        },
        child: audioController!.when(
          data: (controller) => AudioCapturePanel(
            controller: controller,
            handlesSystemBack: true,
            enableSoundscape: true,
            introHeading: widget.startMode == RecordStartMode.reflection
                ? 'Record reflection'
                : 'Record a memory',
            introDescription: widget.initialTitle,
            onBack: () => _leaveCapture(controller),
            onContinue: (draft) => setState(() {
              _audioDraft = draft;
              _view = _RecordView.form;
            }),
          ),
          loading: () => _RecordLoading(onClose: leaveCapture),
          error: (error, stackTrace) => _RecordUnavailable(
            onRetry: () => ref.invalidate(audioCaptureControllerProvider),
            onClose: leaveCapture,
          ),
        ),
      ),
    };
  }

  Future<void> _saveEncounter(EncounterDraft draft) async {
    if (ref.read(encounterRepositoryProvider).hasError) {
      ref.invalidate(encounterRepositoryProvider);
    }
    final repository = await ref.read(encounterRepositoryProvider.future);
    final saved = await repository.create(draft);
    if (draft.audio case final audio?
        when audio.soundscape != MemorySoundscape.quiet) {
      unawaited(_saveSoundscapePreference(saved.id, audio));
    }
    unawaited(requestPersistentStorage());
    if (!mounted) return;
    final preferences =
        ref.read(appFeedbackPreferencesProvider).value ??
        AppFeedbackPreferences.defaults;
    unawaited(
      ref
          .read(appFeedbackServiceProvider)
          .emit(
            AppFeedbackIntent.saved,
            preferences: preferences,
            systemReduceMotion:
                MediaQuery.maybeOf(context)?.disableAnimations ?? false,
          ),
    );
    _audioDraft = null;
    final onMemorySaved = widget.onMemorySaved;
    if (onMemorySaved != null) {
      onMemorySaved(saved);
    } else {
      context.go('/remember/${saved.id}');
    }
  }

  Future<void> _saveSoundscapePreference(
    String encounterId,
    MemoryAudioDraft audio,
  ) async {
    try {
      final savedAudio = await ref.read(
        memoryAudioForEncounterProvider(encounterId).future,
      );
      if (savedAudio == null) return;
      await ref
          .read(memorySoundscapePreferencesProvider)
          .save(
            savedAudio.id,
            MemorySoundscapeSettings(
              soundscape: audio.soundscape,
              volume: audio.soundscapeVolume,
            ),
          );
      ref.invalidate(memorySoundscapeSettingsProvider(savedAudio.id));
    } on Object {
      // The audio entry is durable even when its optional sound preference fails.
    }
  }

  Future<void> _leaveCapture(AudioCaptureController controller) async {
    if (_leaving || controller.state.commandInFlight) return;
    _leaving = true;
    try {
      var phase = controller.state.phase;
      if (phase == AudioCapturePhase.recording) {
        await controller.handleInterruption();
        if (!mounted) return;
        phase = controller.state.phase;
        if (phase == AudioCapturePhase.failure) return;
      }
      if (phase == AudioCapturePhase.failure &&
          controller.state.review == null &&
          controller.hasPendingRecording) {
        return;
      }
      if (controller.hasPendingRecording) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard recording?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep recording'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      await controller.cancel();
      if (!mounted || controller.hasPendingRecording) return;
      _exit();
    } finally {
      _leaving = false;
    }
  }

  void _exit() {
    if (!mounted) return;
    if (widget.onCancel case final onCancel?) {
      onCancel();
    } else {
      context.go('/remember');
    }
  }

  void _cancelForm() {
    // The form discards its transferred temporary draft before returning.
    if (!mounted) return;
    if (widget.startMode == RecordStartMode.write && _audioDraft == null) {
      _exit();
      return;
    }
    setState(() {
      _audioDraft = null;
      _view = _RecordView.capture;
    });
  }
}

class _RecordUnavailable extends StatelessWidget {
  const _RecordUnavailable({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => FeaturePage(
    title: 'Recording unavailable',
    description: 'Try again.',
    action: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        TextButton(onPressed: onClose, child: const Text('Close')),
      ],
    ),
  );
}

class _RecordLoading extends StatelessWidget {
  const _RecordLoading({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
        ),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    ),
  );
}
