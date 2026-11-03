import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/presentation/sanctuary_backdrop.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../record/providers/voice_note_providers.dart';
import '../application/commitment_journey_flow.dart';
import '../data/commitment_practice_catalog_repository.dart';
import '../data/commitment_journey_progress_repository.dart';
import '../data/commitment_journey_practice_draft_repository.dart';
import '../domain/commitment.dart';
import '../providers/commitment_providers.dart';
import 'commitment_audio_reader.dart';
import 'commitment_invitation_view.dart';
import 'commitment_personal_prayer_picker.dart';

class CommitmentJourneyScreen extends ConsumerStatefulWidget {
  const CommitmentJourneyScreen({super.key});
  @override
  ConsumerState<CommitmentJourneyScreen> createState() =>
      _CommitmentJourneyScreenState();
}

class _CommitmentJourneyScreenState
    extends ConsumerState<CommitmentJourneyScreen>
    with WidgetsBindingObserver {
  CommitmentJourneyProgress _progress = const CommitmentJourneyProgress();
  List<CommitmentPracticeDraft> _practices = [];
  List<CommitmentPracticeSuggestion> _suggestions = [];
  final _needs = List.generate(3, (_) => TextEditingController());
  final _calling = TextEditingController();
  final _name = TextEditingController();
  final _declaration = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Future<void> _writes = Future.value();
  bool _loading = true, _busy = false, _leaving = false;
  bool _recordingBusy = false;
  bool get _blocked => _busy || _recordingBusy;
  bool _loaded = false;
  bool _finalizing = false;
  String? _error;
  late final Future<CommitmentJourneyProgressRepository> _draftRepository;
  late final Future<CommitmentJourneyPracticeDraftRepository>
  _practiceRepository;
  @override
  void initState() {
    super.initState();
    _draftRepository = ref.read(
      commitmentJourneyProgressRepositoryProvider.future,
    );
    _practiceRepository = ref.read(
      commitmentPracticeDraftRepositoryProvider.future,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final primary = await (await ref.read(
        commitmentRepositoryProvider.future,
      )).watchPrimary().first;
      if (!mounted) return;
      if (primary != null) {
        context.go('/commitments/${primary.id}');
        return;
      }
      final saved = await (await ref.read(
        commitmentJourneyProgressRepositoryProvider.future,
      )).load();
      final practices = await (await ref.read(
        commitmentPracticeDraftRepositoryProvider.future,
      )).load();
      final zone = await ref.read(prayerDeviceTimezoneProvider)();
      List<CommitmentPracticeSuggestion> suggestions = [];
      try {
        suggestions = await const CommitmentPracticeCatalogRepository().load();
      } catch (_) {
        /* Own practices remain available. */
      }
      if (!mounted) return;
      var value = saved.progress ?? const CommitmentJourneyProgress();
      value = value.copyWith(
        timezone: value.timezone ?? zone,
        frequency: value.frequency ?? CommitmentMeditationFrequency.daily,
        localTime: value.localTime ?? '07:00',
        durationMinutes: value.durationMinutes ?? 10,
        reminderMode: value.reminderMode ?? CommitmentReminderMode.off,
        guideId: value.guideId ?? CommitmentGuideId.surrender,
      );
      value = value.copyWith(stage: commitmentResumeStage(value, practices));
      _needs[0].text = value.keyNeedOne ?? '';
      _needs[1].text = value.keyNeedTwo ?? '';
      _needs[2].text = value.keyNeedThree ?? '';
      _calling.text = value.calling ?? '';
      _name.text = value.name ?? '';
      _declaration.text = value.declarationDraft ?? '';
      setState(() {
        _progress = value;
        _practices = practices;
        _suggestions = suggestions;
        _loading = false;
        _loaded = true;
        if (saved.discardedFields.isNotEmpty) {
          _error = 'Some draft answers need attention.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Draft unavailable. Please retry.';
        });
      }
    }
  }

  CommitmentJourneyProgress _snapshot() => _progress.copyWith(
    keyNeedOne: _needs[0].text,
    keyNeedTwo: _needs[1].text,
    keyNeedThree: _needs[2].text,
    calling: _calling.text,
    name: _name.text,
    declarationDraft: _declaration.text,
  );
  void _changed() {
    if (_busy || _finalizing || !_loaded) return;
    _progress = _snapshot();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_save()),
    );
    setState(() {});
  }

  Future<bool> _save() async {
    if (_finalizing || !_loaded) return false;
    _debounce?.cancel();
    final progress = _snapshot();
    final practices = List<CommitmentPracticeDraft>.of(_practices);
    var success = true;
    final draftRepo = _draftRepository;
    final practiceRepo = _practiceRepository;
    _writes = _writes.then((_) async {
      try {
        await (await practiceRepo).save(practices);
        await (await draftRepo).save(progress);
      } catch (_) {
        success = false;
        if (mounted) {
          setState(() => _error = 'Draft could not be saved. Please retry.');
        }
      }
    });
    await _writes;
    if (mounted) ref.invalidate(commitmentJourneyProgressProvider);
    return success;
  }

  Future<void> _leave() async {
    if (_blocked || _leaving) return;
    if (!_loaded) {
      context.go('/goals');
      return;
    }
    _leaving = true;
    _progress = _progress.copyWith(deferred: true);
    if (await _save() && mounted) {
      context.go('/goals');
    } else {
      _leaving = false;
    }
  }

  Future<void> _advance({bool back = false}) async {
    if (_blocked || !_loaded) return;
    final value = _snapshot();
    if (!back && !commitmentStageValid(value.stage, value, _practices)) {
      setState(
        () => _error = value.stage == CommitmentJourneyStage.declaration
            ? 'Review your declaration before continuing.'
            : 'Complete the required answers.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (await _save() && mounted) {
      final index = value.stage.index + (back ? -1 : 1);
      if (index >= 0 && index < CommitmentJourneyStage.summary.index + 1) {
        _progress = value.copyWith(
          stage: CommitmentJourneyStage.values[index],
          invitationCompleted: true,
          deferred: false,
        );
        await _save();
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish() async {
    if (_blocked) return;
    if (!_progress.declarationReviewed) {
      setState(() => _error = 'Review your declaration before saving.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _save()) return;
      _finalizing = true;
      final result = await (await ref.read(
        commitmentFinalizerProvider.future,
      )).finalize(_snapshot());
      if (!mounted) return;
      ref.invalidate(commitmentJourneyProgressProvider);
      context.go('/commitments/${result.commitmentId}');
    } catch (_) {
      if (mounted) {
        setState(() {
          _finalizing = false;
          _error = 'Commitment could not be saved. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _loaded &&
        !_busy &&
        !_leaving &&
        !_finalizing) {
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_loaded && !_busy && !_leaving && !_finalizing) unawaited(_save());
    _debounce?.cancel();
    for (final c in [..._needs, _calling, _name, _declaration]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Widget _recordedField(
    TextEditingController controller,
    String field,
    String title,
  ) {
    final noteContext = (type: 'commitment', id: 'journey:primary', field: field);
    final notes = ref.watch(voiceNotesProvider(noteContext));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((notes.value?.isEmpty ?? true) && controller.text.isNotEmpty)
            SelectableText(controller.text),
          VoiceNotesField(
            key: ValueKey('commitment-record-$field'),
            noteContext: noteContext,
            title: title,
            enabled: !_blocked,
            onBusyChanged: _recordingChanged,
            onRecorded: (memory) {
              controller.text = memory.title;
              _progress = _progress.copyWith(declarationReviewed: false);
              _changed();
            },
          ),
        ],
      ),
    );
  }

  void _recordingChanged(bool busy) {
    if (mounted) setState(() => _recordingBusy = busy);
  }

  Widget _declarationReview() => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    value: _progress.declarationReviewed,
    title: const Text('This reflects my intention'),
    onChanged: (value) {
      _progress = _progress.copyWith(declarationReviewed: value ?? false);
      _changed();
    },
  );

  Widget _titleField(TextEditingController controller, String title) => TextField(
    controller: controller,
    enabled: !_blocked,
    maxLines: 1,
    maxLength: 120,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(labelText: title),
    onChanged: (_) => _changed(),
  );

  Widget _heading(String title, [String? text]) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (text != null) ...[
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ],
    ),
  );
  Future<void> _ownPractice() async {
    final c = TextEditingController();
    final practiceId = const Uuid().v7();
    var recorded = false;
    var category = CommitmentPracticeCategory.joyPleasure;
    final result = await showDialog<CommitmentPracticeDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Daily practice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  autofocus: true,
                  maxLength: 120,
                  maxLines: 1,
                  decoration: const InputDecoration(labelText: 'Practice title'),
                ),
                VoiceNotesField(
                  noteContext: (
                    type: 'commitment',
                    id: 'journey:primary',
                    field: 'practice:$practiceId',
                  ),
                  title: 'Daily practice',
                  onBusyChanged: _recordingChanged,
                  onRecorded: (memory) => update(() {
                    recorded = true;
                    if (c.text.trim().isEmpty) c.text = memory.title;
                  }),
                ),
                DropdownButtonFormField<CommitmentPracticeCategory>(
                  initialValue: category,
                  isExpanded: true,
                  items: CommitmentPracticeCategory.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(commitmentCategoryLabel(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => category = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: !recorded ? null : () {
                if (c.text.trim().isNotEmpty) {
                  Navigator.pop(
                    ctx,
                    CommitmentPracticeDraft(
                      id: practiceId,
                      category: category,
                      body: c.text.trim(),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    // The dialog's closing animation may still reference the controller.
    if (!mounted || result == null) return;
    if (_practices.length < 12) {
      _practices = [..._practices, result];
      _progress = _progress.copyWith(declarationReviewed: false);
      _changed();
    }
  }

  Widget _body() {
    switch (_progress.stage) {
      case CommitmentJourneyStage.invitation:
        return CommitmentInvitationView(
          onContinue: _advance,
          onReadiness: () => context.push('/welcome/commitment/readiness'),
        );
      case CommitmentJourneyStage.quietPlace:
        return _heading(
          'A moment with God',
          'Find a quiet place',
        );
      case CommitmentJourneyStage.needs:
        return Column(
          children: [
            _heading(
              'What do you need from God?',
              'Record three needs',
            ),
            for (var i = 0; i < 3; i++)
              _recordedField(_needs[i], 'needs-${i + 1}', 'Need ${i + 1}'),
          ],
        );
      case CommitmentJourneyStage.calling:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              'What is your calling?',
              'Record your calling',
            ),
            _recordedField(_calling, 'calling', 'Calling'),
          ],
        );
      case CommitmentJourneyStage.practices:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              'Small, faithful choices',
              'Choose your daily practices',
            ),
            Text('${_practices.length} of 12 practices'),
            for (final p in _practices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.body),
                subtitle: Text(commitmentCategoryLabel(p.category)),
                trailing: IconButton(
                  tooltip: 'Remove practice',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _practices = _practices.where((v) => v.id != p.id).toList();
                    _progress = _progress.copyWith(declarationReviewed: false);
                    _changed();
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _practices.length < 12 ? _ownPractice : null,
              icon: const Icon(Icons.mic_none),
              label: const Text('Record my own'),
            ),
            for (final category in CommitmentPracticeCategory.values)
              ExpansionTile(
                title: Text(commitmentCategoryLabel(category)),
                children: [
                  for (final s in _suggestions.where(
                    (v) => v.category == category,
                  ))
                    CheckboxListTile(
                      title: Text(s.text),
                      value: _practices.any((p) => p.suggestionId == s.id),
                      onChanged: (checked) {
                        if (checked == true && _practices.length < 12) {
                          _practices = [
                            ..._practices,
                            CommitmentPracticeDraft(
                              id: const Uuid().v7(),
                              category: category,
                              body: s.text,
                              suggestionId: s.id,
                              source:
                                  CommitmentPracticeSource.reviewedSuggestion,
                            ),
                          ];
                        } else if (checked == false) {
                          _practices = _practices
                              .where((p) => p.suggestionId != s.id)
                              .toList();
                        }
                        _progress = _progress.copyWith(
                          declarationReviewed: false,
                        );
                        _changed();
                      },
                    ),
                ],
              ),
          ],
        );
      case CommitmentJourneyStage.declaration:
        return Column(
          children: [
            _heading('My declaration'),
            _recordedField(_declaration, 'declaration', 'Declaration'),
            _declarationReview(),
          ],
        );
      case CommitmentJourneyStage.guide:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('A prayerful beginning'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CommitmentGuideId.values
                  .map(
                    (v) => ChoiceChip(
                      label: Text(commitmentGuideLabel(v)),
                      selected: _progress.guideId == v,
                      onSelected: (_) {
                        _progress = _progress.copyWith(guideId: v);
                        _changed();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            CommitmentAudioReader(
              key: ValueKey(_progress.guideId),
              assetId: 'guide_${_progress.guideId!.wireValue}_v1',
            ),
            const SizedBox(height: 20),
            CommitmentPersonalPrayerPicker(
              selectedPrayerId: _progress.personalPrayerId,
              selectedRevisionId: _progress.personalPrayerRevisionId,
              onChanged: (id, revision) {
                _progress = _progress.copyWith(
                  personalPrayerId: id,
                  personalPrayerRevisionId: revision,
                );
                _changed();
              },
            ),
          ],
        );
      case CommitmentJourneyStage.schedule:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('A regular time with God'),
            CommitmentScheduleFields(
              progress: _progress,
              onChanged: (v) {
                _progress = v;
                _changed();
              },
            ),
          ],
        );
      case CommitmentJourneyStage.name:
        return Column(
          children: [
            _heading('Name your commitment'),
            _titleField(_name, 'Commitment name'),
          ],
        );
      case CommitmentJourneyStage.summary:
      case CommitmentJourneyStage.finalizing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(_name.text),
            _recordedField(_calling, 'calling', 'Calling'),
            for (var i = 0; i < _needs.length; i++)
              _recordedField(_needs[i], 'needs-${i + 1}', 'Need ${i + 1}'),
            ExpansionTile(
              title: const Text('Daily practices'),
              initiallyExpanded: true,
              children: [
                for (final practice in _practices)
                  VoiceNotesField(
                    noteContext: (
                      type: 'commitment', id: 'journey:primary',
                      field: 'practice:${practice.id}',
                    ),
                    title: _shortLabel(practice.body),
                    enabled: !_blocked,
                    onBusyChanged: _recordingChanged,
                    onRecorded: (_) {
                      _progress = _progress.copyWith(declarationReviewed: false);
                      _changed();
                    },
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('My declaration'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _recordedField(_declaration, 'declaration', 'Declaration'),
                ),
              ],
            ),
            _declarationReview(),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                '${_progress.localTime} · ${_progress.durationMinutes} minutes',
              ),
              subtitle: Text(
                '${commitmentGuideLabel(_progress.guideId!)} · ${_progress.timezone}',
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        if (_progress.stage.index > 0) {
          unawaited(_advance(back: true));
        } else {
          unawaited(_leave());
        }
      }
    },
    child: ScreenAwake(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SanctuaryBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _blocked
                              ? null
                              : () => _progress.stage.index > 0
                                    ? _advance(back: true)
                                    : _leave(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            'My commitment',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _blocked ? null : _leave,
                          child: const Text('Not now'),
                        ),
                      ],
                    ),
                    if (!_loading)
                      LinearProgressIndicator(
                        value: (_progress.stage.index + 1) / 10,
                      ),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              controller: _scroll,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  if (!_loaded)
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _loading = true);
                                        unawaited(_load());
                                      },
                                      child: const Text('Retry'),
                                    )
                                  else
                                    AbsorbPointer(
                                      absorbing: _blocked,
                                      child: _body(),
                                    ),
                                  if (_loaded &&
                                      _progress.stage !=
                                          CommitmentJourneyStage
                                              .invitation) ...[
                                    const SizedBox(height: 28),
                                    FilledButton(
                                      onPressed: _blocked
                                          ? null
                                          : _progress.stage ==
                                                CommitmentJourneyStage.summary
                                          ? _finish
                                          : _advance,
                                      child: Text(
                                        _blocked
                                            ? 'Saving…'
                                            : _progress.stage ==
                                                  CommitmentJourneyStage.summary
                                            ? 'Save commitment'
                                            : 'Continue',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String commitmentCategoryLabel(CommitmentPracticeCategory v) => switch (v) {
  CommitmentPracticeCategory.joyPleasure => 'Joy/Pleasure',
  CommitmentPracticeCategory.explorationAdventure => 'Exploration/Adventure',
  CommitmentPracticeCategory.attentionSelfEsteem => 'Attention/Self-Esteem',
};
String commitmentGuideLabel(CommitmentGuideId v) => switch (v) {
  CommitmentGuideId.surrender => 'Surrender',
  CommitmentGuideId.direction => 'Direction',
  CommitmentGuideId.peace => 'Peace',
};

class CommitmentScheduleFields extends StatelessWidget {
  const CommitmentScheduleFields({
    required this.progress,
    required this.onChanged,
    super.key,
  });
  final CommitmentJourneyProgress progress;
  final ValueChanged<CommitmentJourneyProgress> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<CommitmentMeditationFrequency>(
        isExpanded: true,
        initialValue: progress.frequency,
        decoration: const InputDecoration(labelText: 'Rhythm'),
        items: const [
          DropdownMenuItem(
            value: CommitmentMeditationFrequency.daily,
            child: Text('Daily'),
          ),
          DropdownMenuItem(
            value: CommitmentMeditationFrequency.selectedDays,
            child: Text('Selected days'),
          ),
        ],
        onChanged: (v) {
          if (v != null) {
            onChanged(
              progress.copyWith(
                frequency: v,
                weekdaysMask: v == CommitmentMeditationFrequency.daily
                    ? null
                    : 31,
              ),
            );
          }
        },
      ),
      if (progress.frequency == CommitmentMeditationFrequency.selectedDays)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  ),
                  selected: ((progress.weekdaysMask ?? 0) & (1 << i)) != 0,
                  onSelected: (_) => onChanged(
                    progress.copyWith(
                      weekdaysMask: (progress.weekdaysMask ?? 0) ^ (1 << i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(progress.localTime ?? '07:00'),
        subtitle: Text(progress.timezone ?? ''),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () async {
          final parts = (progress.localTime ?? '07:00').split(':');
          final value = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            ),
          );
          if (value != null) {
            onChanged(
              progress.copyWith(
                localTime:
                    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
              ),
            );
          }
        },
      ),
      DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: progress.durationMinutes,
        decoration: const InputDecoration(labelText: 'Meditation duration'),
        items: [5, 10, 15, 20, 30]
            .map((v) => DropdownMenuItem(value: v, child: Text('$v minutes')))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(progress.copyWith(durationMinutes: v));
        },
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<CommitmentReminderMode>(
        isExpanded: true,
        initialValue: progress.reminderMode,
        decoration: const InputDecoration(labelText: 'Reminder on this device'),
        items: const [
          DropdownMenuItem(
            value: CommitmentReminderMode.off,
            child: Text('Off'),
          ),
          DropdownMenuItem(
            value: CommitmentReminderMode.silent,
            child: Text('Silent'),
          ),
          DropdownMenuItem(
            value: CommitmentReminderMode.voice,
            child: Text('Spoken invitation'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(progress.copyWith(reminderMode: v));
        },
      ),
    ],
  );
}

String _shortLabel(String value) => String.fromCharCodes(value.trim().runes.take(120));
