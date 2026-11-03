import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/audio/narration_speed.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../kingdom/providers/kingdom_course_providers.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../data/goal_meditation_repository.dart';
import '../domain/goal_meditation_plan.dart';
import '../domain/goal_scripture_response.dart';
import '../providers/goal_meditation_providers.dart';
import '../providers/goal_providers.dart';

class GoalMeditationScreen extends ConsumerStatefulWidget {
  const GoalMeditationScreen({required this.goalId, super.key});
  final String goalId;

  @override
  ConsumerState<GoalMeditationScreen> createState() =>
      _GoalMeditationScreenState();
}

class _GoalMeditationScreenState extends ConsumerState<GoalMeditationScreen>
    with WidgetsBindingObserver {
  final _notes = TextEditingController();
  final _guide = AudioPlayer();
  final _bed = AudioplayersMeditationSoundBedPlayer();
  late final GoalMeditationRepository _repository;
  Timer? _timer;
  Timer? _draftTimer;
  GoalMeditationFrequency _frequency = GoalMeditationFrequency.daily;
  int _weekday = DateTime.monday;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _duration = 10;
  int _remaining = 10 * 60;
  MeditationSoundBed? _sound;
  GoalScriptureResponse? _scriptureResponse;
  double _volume = .15;
  bool _setupLoaded = false;
  bool _editingPlan = false;
  bool _session = false;
  bool _running = false;
  bool _saving = false;
  bool _recordingBusy = false;
  bool _guidePlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = ref.read(goalMeditationRepositoryProvider);
    _notes.addListener(_scheduleDraftSave);
    unawaited(_loadDraft());
    unawaited(_loadScriptureResponse());
    _guide.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _guidePlaying = false);
    });
    unawaited(_loadSound());
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _repository.loadDraft(widget.goalId);
      if (mounted && draft != null && _notes.text.isEmpty) _notes.text = draft;
    } on Object {
      if (mounted) setState(() => _error = 'Notebook draft is unavailable.');
    }
  }

  Future<void> _loadScriptureResponse() async {
    try {
      final key = await _repository.loadScriptureResponseKey(widget.goalId);
      if (mounted) {
        setState(() => _scriptureResponse = goalScriptureResponseForKey(key));
      }
    } on Object {
      // A missing optional passage must not interrupt meditation.
    }
  }

  Future<void> _selectScriptureResponse(GoalScriptureResponse response) async {
    setState(() {
      _scriptureResponse = response;
      _error = null;
    });
    try {
      await _repository.saveScriptureResponseKey(widget.goalId, response.key);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Scripture choice could not be saved.');
      }
    }
  }

  Future<void> _readScriptureResponse(GoalScriptureResponse response) async {
    if (_running) await _pause();
    if (mounted) {
      context.push(
        '/remember/scripture/${Uri.encodeComponent(response.book)}/${response.chapter}',
      );
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _persistDraft() async {
    try {
      await _repository.saveDraft(widget.goalId, _notes.text);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Notebook draft could not be saved.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _draftTimer?.cancel();
      unawaited(_persistDraft());
      if (_running) unawaited(_pause());
    }
  }

  Future<void> _loadSound() async {
    try {
      final value = await ref.read(meditationSoundPreferencesProvider).load();
      if (mounted) {
        setState(() {
          _sound = value.sound;
          _volume = value.volume;
        });
      }
    } on Object {
      // A sound preference must never prevent a quiet session.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _draftTimer?.cancel();
    _notes.removeListener(_scheduleDraftSave);
    unawaited(_persistDraft());
    unawaited(_guide.dispose());
    unawaited(_bed.dispose());
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final text = _notes.text.trim();
    if (text.isEmpty) return;
    await _repository.addEntry(
      GoalMeditationEntry(
        id: const Uuid().v7(),
        goalId: widget.goalId,
        createdAt: DateTime.now(),
        text: text,
      ),
    );
    if (mounted) ref.invalidate(goalMeditationEntriesProvider(widget.goalId));
  }

  Future<void> _stopAudio() async {
    await Future.wait([_guide.stop(), _bed.stop()]);
    if (mounted) setState(() => _guidePlaying = false);
  }

  Future<void> _pause() async {
    _timer?.cancel();
    _timer = null;
    await _stopAudio();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _begin({bool resume = false}) async {
    if (_running) return;
    if (!resume) {
      _remaining = _duration * 60;
    }
    setState(() {
      _session = true;
      _running = true;
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, _duration * 60));
      if (_remaining == 0) unawaited(_pause());
    });
    try {
      if (_sound case final sound?) await _bed.start(sound, volume: _volume);
      if (!resume) await _playGuide();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Audio is unavailable. Continue quietly.',
        );
      }
    }
  }

  Future<void> _playGuide() async {
    if (_guidePlaying) {
      await _guide.pause();
      if (mounted) setState(() => _guidePlaying = false);
      return;
    }
    await _guide.play(AssetSource('kingdom/goal-meditation-guide.mp3'));
    await _guide.setPlaybackRate(defaultNarrationSpeed);
    if (mounted) setState(() => _guidePlaying = true);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _pause();
    try {
      final hadNotes = _notes.text.trim().isNotEmpty;
      await _saveNotes();
      _draftTimer?.cancel();
      await _repository.clearDraft(widget.goalId);
      if (!mounted) return;
      _notes.clear();
      setState(() {
        _session = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadNotes ? 'Reflection saved.' : 'Meditation complete.',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Reflection could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _savePlan() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final plan = GoalMeditationPlan(
      goalId: widget.goalId,
      frequency: _frequency,
      weekday: _weekday,
      hour: _time.hour,
      minute: _time.minute,
      durationMinutes: _duration,
    );
    try {
      await ref.read(goalMeditationRepositoryProvider).savePlan(plan);
      ref.invalidate(goalMeditationPlanProvider(widget.goalId));
      var allowed = false;
      var reminderUnavailable = false;
      try {
        final coordinator = await ref.read(
          goalMeditationReminderCoordinatorProvider.future,
        );
        allowed = await coordinator.enableOnThisDevice();
      } on Object {
        reminderUnavailable = true;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editingPlan = false;
        if (reminderUnavailable) {
          _error = 'Meditation time saved. The reminder could not be set.';
        } else if (!allowed) {
          _error = 'Reminder permission is off. The meditation plan was saved.';
        }
      });
      if (allowed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Meditation time saved.')));
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Meditation time could not be saved.';
        });
      }
    }
  }

  Future<void> _removePlan() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final coordinator = await ref.read(
        goalMeditationReminderCoordinatorProvider.future,
      );
      await coordinator.cancel(widget.goalId);
      await _repository.deletePlan(widget.goalId);
      ref.invalidate(goalMeditationPlanProvider(widget.goalId));
      if (mounted) {
        setState(() {
          _saving = false;
          _editingPlan = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Meditation time could not be removed. Try again.';
        });
      }
    }
  }

  Future<void> _selectSound(MeditationSoundBed? sound) async {
    final volume = sound?.preferredVolume ?? _volume;
    setState(() {
      _sound = sound;
      _volume = volume;
    });
    await _bed.stop();
    if (_running && sound != null) await _bed.start(sound, volume: volume);
    await ref
        .read(meditationSoundPreferencesProvider)
        .save(MeditationSoundPreferences(sound: sound, volume: volume));
  }

  @override
  Widget build(BuildContext context) {
    final kingdom = ref.watch(kingdomMeditationReadyProvider);
    if (kingdom case AsyncData(value: final ready)) {
      if (!ready) {
        return Scaffold(
          appBar: AppBar(title: const Text('Goal meditation')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Complete the first six Kingdom Nuggets to begin.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/kingdom'),
                  child: const Text('Kingdom life'),
                ),
              ],
            ),
          ),
        );
      }
    } else if (kingdom.hasError) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(kingdomMeditationReadyProvider),
            child: const Text('Try again'),
          ),
        ),
      );
    } else {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final goal = ref.watch(goalProvider(widget.goalId));
    final plan = ref.watch(goalMeditationPlanProvider(widget.goalId));
    if (goal.isLoading || plan.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (goal.hasError || plan.hasError) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              ref.invalidate(goalProvider(widget.goalId));
              ref.invalidate(goalMeditationPlanProvider(widget.goalId));
            },
            child: const Text('Try again'),
          ),
        ),
      );
    }
    if (goal.value == null) {
      return const Scaffold(body: Center(child: Text('Goal unavailable.')));
    }
    final saved = plan.value;
    if (!_setupLoaded && saved != null) {
      _setupLoaded = true;
      _frequency = saved.frequency;
      _weekday = saved.weekday;
      _time = TimeOfDay(hour: saved.hour, minute: saved.minute);
      _duration = saved.durationMinutes;
    }
    return PracticeAudioScope(
      onVisibilityChanged: (visible) {
        if (!visible && _running) unawaited(_pause());
      },
      child: ScreenAwake(
        child: Scaffold(
          appBar: AppBar(title: const Text('Goal meditation')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      goal.value?.title ?? 'Goal',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_session)
                      _sessionView(context)
                    else if (saved != null && !_editingPlan)
                      _savedPlanView(context, saved)
                    else
                      _planView(context, savedPlan: saved),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
    );
  }

  Widget _savedPlanView(BuildContext context, GoalMeditationPlan plan) {
    final day = plan.frequency == GoalMeditationFrequency.daily
        ? 'Daily'
        : const [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ][plan.weekday - 1];
    final time = TimeOfDay(
      hour: plan.hour,
      minute: plan.minute,
    ).format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Offer this goal to God. Listen, write, and discern one faithful step.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text('$day at $time'),
          subtitle: Text('${plan.durationMinutes} minutes'),
          trailing: TextButton(
            key: const Key('change-goal-meditation-plan'),
            onPressed: () => setState(() => _editingPlan = true),
            child: const Text('Change'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('start-goal-meditation'),
          onPressed: () => _begin(),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Begin meditation'),
        ),
        const SizedBox(height: AppSpacing.sm),
        MeditationSoundPicker(selected: _sound, onSelected: _selectSound),
        const SizedBox(height: AppSpacing.lg),
        _recentNotes(),
      ],
    );
  }

  Widget _planView(
    BuildContext context, {
    GoalMeditationPlan? savedPlan,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Offer this goal to God. Listen, write, and discern one faithful step.',
      ),
      const SizedBox(height: AppSpacing.lg),
      SegmentedButton<GoalMeditationFrequency>(
        segments: const [
          ButtonSegment(
            value: GoalMeditationFrequency.daily,
            label: Text('Daily'),
          ),
          ButtonSegment(
            value: GoalMeditationFrequency.weekly,
            label: Text('Weekly'),
          ),
        ],
        selected: {_frequency},
        onSelectionChanged: (values) =>
            setState(() => _frequency = values.first),
      ),
      if (_frequency == GoalMeditationFrequency.weekly) ...[
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          initialValue: _weekday,
          decoration: const InputDecoration(labelText: 'Day'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Monday')),
            DropdownMenuItem(value: 2, child: Text('Tuesday')),
            DropdownMenuItem(value: 3, child: Text('Wednesday')),
            DropdownMenuItem(value: 4, child: Text('Thursday')),
            DropdownMenuItem(value: 5, child: Text('Friday')),
            DropdownMenuItem(value: 6, child: Text('Saturday')),
            DropdownMenuItem(value: 7, child: Text('Sunday')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _weekday = value);
          },
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: const Text('Meditation time'),
        trailing: Text(_time.format(context)),
        onTap: () async {
          final selected = await showTimePicker(
            context: context,
            initialTime: _time,
          );
          if (selected != null && mounted) setState(() => _time = selected);
        },
      ),
      DropdownButtonFormField<int>(
        initialValue: _duration,
        decoration: const InputDecoration(labelText: 'Minutes'),
        items: const [5, 10, 15, 20, 30]
            .map(
              (minutes) => DropdownMenuItem(
                value: minutes,
                child: Text('$minutes minutes'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _duration = value);
        },
      ),
      const SizedBox(height: AppSpacing.md),
      MeditationSoundPicker(selected: _sound, onSelected: _selectSound),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        key: const Key('save-goal-meditation-plan'),
        onPressed: _saving ? null : _savePlan,
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Save meditation time'),
      ),
      if (savedPlan == null) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('start-goal-meditation'),
          onPressed: () => _begin(),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Begin now'),
        ),
      ],
      if (savedPlan != null) ...[
        TextButton(
          key: const Key('cancel-goal-meditation-plan'),
          onPressed: _saving
              ? null
              : () {
                  setState(() {
                    _frequency = savedPlan.frequency;
                    _weekday = savedPlan.weekday;
                    _time = TimeOfDay(
                      hour: savedPlan.hour,
                      minute: savedPlan.minute,
                    );
                    _duration = savedPlan.durationMinutes;
                    _editingPlan = false;
                  });
                },
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('remove-goal-meditation-plan'),
          onPressed: _saving ? null : _removePlan,
          child: const Text('Remove meditation time'),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      _recentNotes(),
    ],
  );

  Widget _sessionView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'God of mercy, I commit this time and this goal to you. Guide me in truth and love.',
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          IconButton(
            tooltip: _guidePlaying ? 'Pause guidance' : 'Play guidance',
            onPressed: () => unawaited(_playGuide()),
            icon: Icon(_guidePlaying ? Icons.pause_circle : Icons.play_circle),
          ),
          const Expanded(child: Text('Spoken guidance')),
          TextButton(
            onPressed: _running ? _pause : () => _begin(resume: true),
            child: Text(_running ? 'Pause' : 'Continue'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Column(
          children: [
            PopupMenuButton<GoalScriptureResponse>(
              key: const Key('goal-scripture-response-picker'),
              tooltip: 'Choose Scripture response',
              onSelected: _selectScriptureResponse,
              itemBuilder: (_) => [
                for (final response in goalScriptureResponses)
                  PopupMenuItem(
                    value: response,
                    child: Text('${response.label} · ${response.reference}'),
                  ),
              ],
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Answer with Scripture'),
                subtitle: Text(
                  _scriptureResponse?.reference ??
                      'Choose a recurring struggle',
                ),
                trailing: const Icon(Icons.expand_more),
              ),
            ),
            if (_scriptureResponse case final response?) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(response.practice),
                ),
              ),
              TextButton.icon(
                key: const Key('read-goal-scripture-response'),
                onPressed: () => _readScriptureResponse(response),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Read chapter'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Text(
                  'Read morning, midday, evening, and when the urge returns.',
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      VoiceNotesField(
        key: const Key('goal-meditation-notebook'),
        noteContext: (type: 'goal', id: widget.goalId, field: 'notebook'),
        title: 'Meditation reflection',
        beforeRecord: _pause,
        onBusyChanged: (busy) {
          if (mounted) setState(() => _recordingBusy = busy);
        },
      ),
      if (_notes.text.isNotEmpty)
        ExpansionTile(
          title: const Text('Earlier written draft'),
          children: [SelectableText(_notes.text)],
        ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        key: const Key('finish-goal-meditation'),
        onPressed: _saving || _recordingBusy ? null : _finish,
        icon: const Icon(Icons.check),
        label: const Text('Finish and save'),
      ),
    ],
  );

  Widget _recentNotes() {
    final entries = ref.watch(goalMeditationEntriesProvider(widget.goalId));
    return entries.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : ExpansionTile(
              title: Text('Reflections (${items.length})'),
              children: [
                for (final entry in items.reversed)
                  ListTile(
                    title: Text(entry.text),
                    subtitle: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(entry.createdAt.toLocal()),
                    ),
                  ),
              ],
            ),
    );
  }
}
