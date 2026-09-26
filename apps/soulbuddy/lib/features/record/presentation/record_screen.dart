import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
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
import '../data/encounter_repository.dart';
import '../domain/encounter_draft.dart';
import '../domain/encounter.dart';
import '../providers/encounter_providers.dart';
import 'encounter_form.dart';
import '../../persons/providers/person_providers.dart';
import '../../persons/domain/prayer_person.dart';

enum _RecordView { choices, memoryTypes, capture, form }

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
  });

  final RecordStartMode startMode;
  final List<String> initialPersonIds;
  final String? initialBodyPrompt;
  final String? initialTitle;
  final DateTime? initialDate;
  final bool allowMemoryTypeChoice;
  final bool privateReflection;
  final ValueChanged<Encounter>? onMemorySaved;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late var _view = switch (widget.startMode) {
    RecordStartMode.choices => _RecordView.choices,
    RecordStartMode.speak => _RecordView.capture,
    RecordStartMode.write => _RecordView.memoryTypes,
    RecordStartMode.reflection => _RecordView.form,
    RecordStartMode.person => _RecordView.form,
  };
  late var _memoryType = widget.startMode == RecordStartMode.person
      ? MemoryType.person
      : MemoryType.encounter;
  MemoryAudioDraft? _audioDraft;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(encounterRepositoryProvider);
    final people = _view == _RecordView.form
        ? ref.watch(prayerPeopleProvider).value ?? const <PrayerPerson>[]
        : const <PrayerPerson>[];
    final audioController = _view == _RecordView.capture || _audioDraft != null
        ? ref.watch(audioCaptureControllerProvider)
        : null;

    return switch (_view) {
      _RecordView.form => repository.when(
        data: (value) => EncounterForm(
          memoryType: _memoryType,
          allowMemoryTypeChoice:
              widget.allowMemoryTypeChoice ||
              _audioDraft != null ||
              widget.startMode == RecordStartMode.person,
          initialTitle: _audioDraft == null
              ? widget.initialTitle
              : widget.initialTitle ?? _voiceMemoryTitle(DateTime.now()),
          initialDate: widget.initialDate,
          audio: _audioDraft,
          people: people,
          initialPersonIds: widget.initialPersonIds,
          bodyLabel: widget.initialBodyPrompt == null
              ? null
              : 'Your reflection',
          bodyPrompt: widget.initialBodyPrompt,
          initialSensitive: widget.privateReflection,
          initialRecallEnabled: !widget.privateReflection,
          onCancel: () => _cancelForm(audioController?.value),
          onSave: (draft) => _saveEncounter(value, draft),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _RecordUnavailable(
          onRetry: () => ref.invalidate(encounterRepositoryProvider),
        ),
      ),
      _RecordView.capture => audioController!.when(
        data: (controller) => AudioCapturePanel(
          controller: controller,
          enableSoundscape: true,
          onBack: () => _leaveCapture(controller),
          onWriteInstead: () => _leaveCapture(controller, write: true),
          onContinue: (draft) => setState(() {
            _audioDraft = draft;
            _memoryType = MemoryType.encounter;
            _view = _RecordView.form;
          }),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _RecordUnavailable(
          onRetry: () => ref.invalidate(audioCaptureControllerProvider),
        ),
      ),
      _RecordView.memoryTypes => _memoryTypes(),
      _RecordView.choices => FeaturePage(
        title: 'Remember',
        description: 'Keep what you do not want to forget.',
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              key: const Key('record-speak'),
              constraints: const BoxConstraints(minHeight: 52),
              child: FilledButton.icon(
                onPressed: () => setState(() => _view = _RecordView.capture),
                icon: const Icon(Icons.mic_none),
                label: const Text('Speak'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              key: const Key('record-write'),
              constraints: const BoxConstraints(minHeight: 52),
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _view = _RecordView.memoryTypes),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write'),
              ),
            ),
          ],
        ),
      ),
    };
  }

  Future<void> _saveEncounter(
    EncounterRepository repository,
    EncounterDraft draft,
  ) async {
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
      // The Memory is already durable. A background preference must never make
      // the successful save look as though it failed or invite a duplicate.
    }
  }

  void _open(MemoryType type) => setState(() {
    _memoryType = type;
    _view = _RecordView.form;
  });

  Widget _memoryTypes() => FeaturePage(
    title: 'What do you want to remember?',
    description: 'Choose the kind of memory. You can still add your own words.',
    action: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final choice in _memoryChoices) ...[
          _RecordChoice(
            label: choice.$2,
            icon: choice.$3,
            onPressed: () => _open(choice.$1),
          ),
          if (choice != _memoryChoices.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    ),
  );

  Future<void> _leaveCapture(
    AudioCaptureController controller, {
    bool write = false,
  }) async {
    final phase = controller.state.phase;
    if (phase == AudioCapturePhase.review) {
      await controller.discard();
    } else if (phase == AudioCapturePhase.recording ||
        phase == AudioCapturePhase.paused ||
        phase == AudioCapturePhase.failure) {
      await controller.cancel();
    }
    if (!mounted) return;
    setState(() {
      _audioDraft = null;
      _view = write ? _RecordView.memoryTypes : _RecordView.choices;
    });
  }

  Future<void> _cancelForm(AudioCaptureController? controller) async {
    if (_audioDraft != null && controller != null) {
      await controller.discard();
    }
    if (!mounted) return;
    setState(() {
      _audioDraft = null;
      _view = _RecordView.choices;
    });
  }
}

const _memoryChoices = [
  (MemoryType.encounter, 'Encounter', Icons.auto_awesome_outlined),
  (MemoryType.promise, 'Promise', Icons.handshake_outlined),
  (MemoryType.leftBehind, 'What I left behind', Icons.arrow_forward_outlined),
  (MemoryType.revelation, 'Revelation', Icons.lightbulb_outline),
  (MemoryType.scripture, 'Scripture', Icons.menu_book_outlined),
  (MemoryType.person, 'Person', Icons.person_outline),
  (MemoryType.family, 'Family', Icons.family_restroom_outlined),
  (MemoryType.lesson, 'Lesson', Icons.school_outlined),
  (MemoryType.testimony, 'Testimony', Icons.record_voice_over_outlined),
];

String _voiceMemoryTitle(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Voice memory · ${value.day} ${months[value.month - 1]}';
}

class _RecordChoice extends StatelessWidget {
  const _RecordChoice({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: Key('record-choice-${label.toLowerCase()}'),
      constraints: const BoxConstraints(minHeight: 52),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

class _RecordUnavailable extends StatelessWidget {
  const _RecordUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Remember is unavailable',
      description:
          'Your writing is still on this device. Try opening it again.',
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('Try again'),
      ),
    );
  }
}
