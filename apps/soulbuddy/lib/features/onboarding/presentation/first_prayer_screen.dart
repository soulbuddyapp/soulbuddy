import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/audio/application/audio_capture_controller.dart';
import '../../record/audio/domain/memory_audio.dart';
import '../../record/audio/presentation/audio_capture_panel.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../../record/domain/encounter.dart';
import '../domain/first_prayer_choices.dart';
import '../domain/first_prayer_progress.dart';
import '../providers/first_prayer_providers.dart';
import 'first_prayer_choice_page.dart';
import 'first_prayer_detail_page.dart';
import 'first_prayer_practice_page.dart';
import 'first_prayer_result_page.dart';
import 'first_prayer_speech_page.dart';
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
      choices: const ['Speak', 'Write', 'Not now'],
      onChoose: (choice) {
        if (choice == 'Write') {
          _next(FirstPrayerPreviewStep.detail);
        } else {
          _next(FirstPrayerPreviewStep.preparing);
        }
      },
    ),
    FirstPrayerPreviewStep.detail => FirstPrayerDetailPage(
      onContinue: (_) => _next(FirstPrayerPreviewStep.preparing),
      onSkip: () => _next(FirstPrayerPreviewStep.preparing),
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

class _LiveFirstPrayer extends ConsumerWidget {
  const _LiveFirstPrayer({required this.flow});

  final FirstPrayerState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(firstPrayerControllerProvider.notifier);
    final stage = flow.progress.stage;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your first prayer'),
        leading: stage == FirstPrayerStage.purpose
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: stage.index <= FirstPrayerStage.preparing.index
                    ? controller.goBack
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
        actions: [
          TextButton(
            onPressed: () => context.go('/today'),
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
            FirstPrayerStage.detailChoice => FirstPrayerChoicePage(
              question: 'Add anything?',
              choices: const ['Speak', 'Write', 'Not now'],
              onChoose: (choice) {
                if (choice == 'Not now') {
                  controller.usePreparedPrayer();
                } else {
                  controller.openDetail(speak: choice == 'Speak');
                }
              },
            ),
            FirstPrayerStage.detail =>
              flow.detailByVoice
                  ? FirstPrayerSpeechPage(
                      onContinue: (_) => controller.usePreparedPrayer(),
                      onWriteInstead: () => controller.openDetail(speak: false),
                      onSkip: controller.usePreparedPrayer,
                    )
                  : FirstPrayerDetailPage(
                      onContinue: (_) => controller.usePreparedPrayer(),
                      onSkip: controller.usePreparedPrayer,
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
            FirstPrayerStage.remembranceMode => FirstPrayerChoicePage(
              question: 'Speak or write?',
              choices: const ['Speak', 'Write'],
              onChoose: (choice) =>
                  controller.chooseRemembranceMode(speak: choice == 'Speak'),
            ),
            FirstPrayerStage.remembrance =>
              flow.remembranceByVoice
                  ? ref
                        .watch(audioCaptureControllerProvider)
                        .when(
                          data: (audioController) =>
                              _FirstPrayerAudioRemembrance(
                                controller: audioController,
                                initialDraft: flow.remembranceAudio,
                                onWriteInstead: () => controller
                                    .chooseRemembranceMode(speak: false),
                                onSave: (audio) =>
                                    controller.saveRemembrance(audio: audio),
                                onSaved: () {
                                  if (context.mounted) context.go('/today');
                                },
                              ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => Center(
                            child: FilledButton(
                              onPressed: () => controller.chooseRemembranceMode(
                                speak: false,
                              ),
                              child: const Text('Write instead'),
                            ),
                          ),
                        )
                  : FirstRemembranceWritePage(
                      initialBody: flow.progress.remembranceText ?? '',
                      onSave: (body) async {
                        final saved = await controller.saveRemembrance(
                          body: body,
                        );
                        if (saved && context.mounted) context.go('/today');
                        return saved;
                      },
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
    required this.onWriteInstead,
    required this.onSave,
    required this.onSaved,
  });

  final AudioCaptureController controller;
  final MemoryAudioDraft? initialDraft;
  final VoidCallback onWriteInstead;
  final Future<bool> Function(MemoryAudioDraft audio) onSave;
  final VoidCallback onSaved;

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
    _pending = widget.initialDraft;
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
      return AudioCapturePanel(
        controller: widget.controller,
        introHeading: 'Record it',
        introDescription: 'Speak what you would like to remember.',
        onWriteInstead: widget.onWriteInstead,
        onContinue: _save,
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
