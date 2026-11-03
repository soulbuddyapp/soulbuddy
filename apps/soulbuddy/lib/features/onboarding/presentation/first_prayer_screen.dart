import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/audio/application/audio_capture_controller.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/presentation/audio_capture_panel.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../domain/first_prayer_choices.dart';
import '../domain/first_prayer_progress.dart';
import '../providers/first_prayer_providers.dart';
import 'first_prayer_choice_page.dart';
import 'first_prayer_practice_page.dart';
import 'first_prayer_result_page.dart';
import 'first_remembrance_page.dart';

enum FirstPrayerPreviewStep {
  purpose,
  frequency,
  audience,
  language,
  detailChoice,
  detail,
  preparing,
}

class FirstPrayerScreen extends StatefulWidget {
  const FirstPrayerScreen({super.key})
    : previewMode = false,
      initialStep = FirstPrayerPreviewStep.purpose;

  const FirstPrayerScreen.preview({
    this.initialStep = FirstPrayerPreviewStep.purpose,
    super.key,
  }) : previewMode = true;

  final bool previewMode;
  final FirstPrayerPreviewStep initialStep;

  @override
  State<FirstPrayerScreen> createState() => _FirstPrayerScreenState();
}

class _FirstPrayerScreenState extends State<FirstPrayerScreen> {
  late FirstPrayerPreviewStep _step = widget.initialStep;

  void _next(FirstPrayerPreviewStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    if (!widget.previewMode) {
      return Consumer(
        builder: (context, ref, _) {
          final flow = ref.watch(firstPrayerControllerProvider);
          return flow.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FilledButton(
                    onPressed: () =>
                        ref.invalidate(firstPrayerControllerProvider),
                    child: const Text('Try again'),
                  ),
                ),
              ),
            ),
            data: (flow) => _LiveFirstPrayer(flow: flow),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your first prayer'),
        leading: _step == FirstPrayerPreviewStep.purpose
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey(_step), child: _page()),
      ),
    );
  }

  Widget _page() => switch (_step) {
    FirstPrayerPreviewStep.purpose => FirstPrayerChoicePage(
      question: 'What are you bringing to God?',
      choices: const [
        'Stay close',
        'Guidance',
        'Family',
        'Healing',
        'Forgiveness',
        'A difficult time',
      ],
      onChoose: (_) => _next(FirstPrayerPreviewStep.frequency),
    ),
    FirstPrayerPreviewStep.frequency => FirstPrayerChoicePage(
      question: 'How often?',
      choices: const ['Daily', 'Once'],
      onChoose: (_) => _next(FirstPrayerPreviewStep.audience),
    ),
    FirstPrayerPreviewStep.audience => FirstPrayerChoicePage(
      question: 'Who is this for?',
      choices: const ['Me', 'Someone', 'My family', 'Others'],
      onChoose: (_) => _next(FirstPrayerPreviewStep.language),
    ),
    FirstPrayerPreviewStep.language => FirstPrayerChoicePage(
      question: 'Which feels more natural to you?',
      choices: const ['Christian', 'Catholic', 'Jesus', 'All of the above'],
      onChoose: (_) => _next(FirstPrayerPreviewStep.detailChoice),
    ),
    FirstPrayerPreviewStep.detailChoice => FirstPrayerChoicePage(
      question: 'Add anything?',
      choices: const ['Record', 'Not now'],
      onChoose: (choice) {
        if (choice == 'Record') {
          _next(FirstPrayerPreviewStep.detail);
        } else {
          _next(FirstPrayerPreviewStep.preparing);
        }
      },
    ),
    FirstPrayerPreviewStep.detail => FirstPrayerChoicePage(
      question: 'Record your words',
      choices: const ['Record', 'Not now'],
      onChoose: (_) => _next(FirstPrayerPreviewStep.preparing),
    ),
    FirstPrayerPreviewStep.preparing => _PreparingPrayer(onPrepared: () {}),
  };

  void _back() {
    _next(switch (_step) {
      FirstPrayerPreviewStep.purpose => FirstPrayerPreviewStep.purpose,
      FirstPrayerPreviewStep.frequency => FirstPrayerPreviewStep.purpose,
      FirstPrayerPreviewStep.audience => FirstPrayerPreviewStep.frequency,
      FirstPrayerPreviewStep.language => FirstPrayerPreviewStep.audience,
      FirstPrayerPreviewStep.detailChoice => FirstPrayerPreviewStep.language,
      FirstPrayerPreviewStep.detail => FirstPrayerPreviewStep.detailChoice,
      FirstPrayerPreviewStep.preparing => FirstPrayerPreviewStep.detailChoice,
    });
  }
}

class _LiveFirstPrayer extends ConsumerStatefulWidget {
  const _LiveFirstPrayer({required this.flow});

  final FirstPrayerState flow;

  @override
  ConsumerState<_LiveFirstPrayer> createState() => _LiveFirstPrayerState();
}

class _LiveFirstPrayerState extends ConsumerState<_LiveFirstPrayer> {
  bool _recordingBusy = false;

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final controller = ref.read(firstPrayerControllerProvider.notifier);
    final stage = flow.progress.stage;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your first prayer'),
        leading: stage == FirstPrayerStage.purpose
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed:
                    !_recordingBusy &&
                        stage.index <= FirstPrayerStage.preparing.index
                    ? controller.goBack
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
        actions: [
          TextButton(
            onPressed: _recordingBusy ? null : () => context.go('/today'),
            child: const Text('Go to Today'),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey(stage),
          child: switch (stage) {
            FirstPrayerStage.purpose => FirstPrayerChoicePage(
              question: 'What are you bringing to God?',
              choices: FirstPrayerPurpose.values
                  .map((value) => value.label)
                  .toList(growable: false),
              onChoose: (label) => controller.choosePurpose(
                FirstPrayerPurpose.values.firstWhere(
                  (value) => value.label == label,
                ),
              ),
            ),
            FirstPrayerStage.frequency => FirstPrayerChoicePage(
              question: 'How often?',
              choices: FirstPrayerFrequency.values
                  .map((value) => value.label)
                  .toList(growable: false),
              onChoose: (label) => controller.chooseFrequency(
                FirstPrayerFrequency.values.firstWhere(
                  (value) => value.label == label,
                ),
              ),
            ),
            FirstPrayerStage.audience => FirstPrayerChoicePage(
              question: 'Who is this for?',
              choices: FirstPrayerAudience.values
                  .map((value) => value.label)
                  .toList(growable: false),
              onChoose: (label) => controller.chooseAudience(
                FirstPrayerAudience.values.firstWhere(
                  (value) => value.label == label,
                ),
              ),
            ),
            FirstPrayerStage.language => FirstPrayerChoicePage(
              question: 'Which feels more natural to you?',
              choices: PrayerLanguagePreference.values
                  .map((value) => value.label)
                  .toList(growable: false),
              onChoose: (label) => controller.chooseLanguage(
                PrayerLanguagePreference.values.firstWhere(
                  (value) => value.label == label,
                ),
              ),
            ),
            FirstPrayerStage.detailChoice ||
            FirstPrayerStage.detail => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add anything?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  VoiceNotesField(
                    noteContext: (
                      type: 'first_prayer',
                      id: 'onboarding',
                      field: 'intention',
                    ),
                    title: 'My intention',
                    onBusyChanged: (busy) =>
                        setState(() => _recordingBusy = busy),
                    onRecorded: (_) => controller.usePreparedPrayer(),
                  ),
                  TextButton(
                    onPressed: _recordingBusy
                        ? null
                        : controller.usePreparedPrayer,
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
            FirstPrayerStage.preparing => _PreparingPrayer(
              onPrepared: controller.usePreparedPrayer,
            ),
            FirstPrayerStage.prayer =>
              flow.result == null
                  ? _PreparingPrayer(onPrepared: controller.usePreparedPrayer)
                  : FirstPrayerResultPage(
                      prayer: flow.result!,
                      onPray: () => controller.keepPrayer(recordPractice: true),
                      onKeep: () =>
                          controller.keepPrayer(recordPractice: false),
                    ),
            FirstPrayerStage.practice => FirstPrayerPracticePage(
              action: flow.result?.action,
              onContinue: controller.continueFromPractice,
            ),
            FirstPrayerStage.remembranceType => FirstRemembranceTypePage(
              onChoose: (choice) async {
                if (choice == 'Nothing today') {
                  await controller.complete();
                  if (context.mounted) context.go('/today');
                  return;
                }
                await controller.chooseRemembranceType(switch (choice) {
                  'Promise' => MemoryType.promise,
                  'Scripture or lesson' => MemoryType.lesson,
                  _ => MemoryType.encounter,
                });
              },
            ),
            FirstPrayerStage.remembranceMode || FirstPrayerStage.remembrance =>
              ref
                  .watch(audioCaptureControllerProvider)
                  .when(
                    data: (audioController) => _FirstPrayerAudioRemembrance(
                      controller: audioController,
                      initialDraft: flow.remembranceAudio,
                      onBusyChanged: (busy) =>
                          setState(() => _recordingBusy = busy),
                      onSave: (audio) => controller.saveRemembrance(
                        body: flow.progress.remembranceText ?? '',
                        audio: audio,
                      ),
                      onSaved: () {
                        if (context.mounted) context.go('/today');
                      },
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: FilledButton(
                        onPressed: () =>
                            ref.invalidate(audioCaptureControllerProvider),
                        child: const Text('Retry recording'),
                      ),
                    ),
                  ),
          },
        ),
      ),
    );
  }
}

class _FirstPrayerAudioRemembrance extends StatefulWidget {
  const _FirstPrayerAudioRemembrance({
    required this.controller,
    required this.initialDraft,
    required this.onSave,
    required this.onSaved,
    required this.onBusyChanged,
  });

  final AudioCaptureController controller;
  final MemoryAudioDraft? initialDraft;
  final Future<bool> Function(MemoryAudioDraft audio) onSave;
  final VoidCallback onSaved;
  final ValueChanged<bool> onBusyChanged;

  @override
  State<_FirstPrayerAudioRemembrance> createState() =>
      _FirstPrayerAudioRemembranceState();
}

class _FirstPrayerAudioRemembranceState
    extends State<_FirstPrayerAudioRemembrance> {
  MemoryAudioDraft? _pending;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_captureChanged);
    _pending = widget.initialDraft;
  }

  void _captureChanged() {
    final capture = widget.controller;
    widget.onBusyChanged(
      capture.hasPendingRecording || capture.state.commandInFlight,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_captureChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FirstPrayerAudioRemembrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialDraft;
    if (next != null && next.temporaryKey != _pending?.temporaryKey) {
      _pending = next;
    }
  }

  Future<void> _save(MemoryAudioDraft audio) async {
    if (_saving) return;
    setState(() {
      _pending = audio;
      _saving = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    final saved = await widget.onSave(audio);
    if (!mounted) return;
    if (saved) {
      widget.onSaved();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Couldn\'t keep this memory. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    if (pending == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record a memory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AudioCapturePanel(
              controller: widget.controller,
              inline: true,
              startLabel: 'Record',
              onContinue: _save,
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?)
                Text(error, textAlign: TextAlign.center)
              else
                const Text('Keep this recording', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : () => _save(pending),
                child: Text(_saving ? 'Keeping…' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingPrayer extends StatelessWidget {
  const _PreparingPrayer({required this.onPrepared});

  final VoidCallback onPrepared;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Preparing your prayer…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onPrepared,
              child: const Text('Choose a prepared prayer'),
            ),
          ],
        ),
      ),
    ),
  );
}
