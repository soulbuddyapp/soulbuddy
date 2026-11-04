import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import 'supporting_reading_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../prayers/presentation/inline_spiritual_response_editor.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../scripture/domain/scripture_passage.dart';
import '../../scripture/providers/scripture_providers.dart';
import '../data/formation_progress_repository.dart';
import '../domain/formation_reading.dart';
import '../providers/formation_providers.dart';

class FormationReadingScreen extends ConsumerStatefulWidget {
  const FormationReadingScreen({this.readingId, this.soundPlayer, super.key});

  final String? readingId;
  final MeditationSoundBedPlayer? soundPlayer;

  @override
  ConsumerState<FormationReadingScreen> createState() =>
      _FormationReadingScreenState();
}

class _FormationReadingScreenState
    extends ConsumerState<FormationReadingScreen> {
  late final _soundPlayer =
      widget.soundPlayer ?? AudioplayersMeditationSoundBedPlayer();
  bool _soundVisible = false;
  int _soundRevision = 0;
  MeditationSoundBed? _sound;
  double _volume = 0.15;
  bool _completing = false;
  bool _recordingBusy = false;
  bool _prayerEditor = false;
  bool _goalEditor = false;
  String? _passageReadingId;
  Future<ScripturePassage>? _passageFuture;

  @override
  void dispose() {
    unawaited(_soundPlayer.dispose());
    super.dispose();
  }

  FormationReading _reading(Set<String> completed) {
    final requested = formationReadings.where((r) => r.id == widget.readingId);
    if (requested.isNotEmpty) return requested.first;
    return FormationProgress(completed).next(formationReadings);
  }

  @override
  Widget build(BuildContext context) {
    return PracticeAudioScope(
      onVisibilityChanged: _soundVisibilityChanged,
      child: ScreenAwake(child: _buildReading(context)),
    );
  }

  Widget _buildReading(BuildContext context) {
    final progress = ref.watch(formationProgressProvider);
    return progress.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _error(),
      data: (value) {
        final reading = _reading(value.completedIds);
        return FutureBuilder<ScripturePassage>(
          future: _passageFor(reading),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData) return _error();
            return _content(reading, snapshot.requireData, value.completedIds);
          },
        );
      },
    );
  }

  Widget _content(
    FormationReading reading,
    ScripturePassage passage,
    Set<String> completed,
  ) {
    final index = formationReadings.indexOf(reading);
    final isComplete = completed.contains(reading.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grow closer to God'),
        actions: [
          IconButton(
            tooltip: 'All readings',
            onPressed: _recordingBusy ? null : () => _showReadings(completed),
            icon: const Icon(Icons.list_alt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'MEDITATION ${index + 1} OF ${formationReadings.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                SanctuaryReadingHeading(
                  title: reading.theme,
                  art: SanctuaryArt.scripture,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${passage.reference} · RSVCE',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  key: const Key('formation-reading-body'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final verse in passage.verses)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SelectableText.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${verse.number}  ',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: verse.text),
                                ],
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _responseCard(
                  'REFLECT',
                  reading.meditation,
                  Icons.edit_note,
                  'Save a private reflection',
                  () {},
                  actionControl: VoiceNotesField(
                    key: ValueKey('formation-reflection-${reading.id}'),
                    noteContext: (
                      type: 'formation',
                      id: reading.id,
                      field: 'reflection',
                    ),
                    title: 'Reflection · ${reading.theme}',
                    recordLabel: 'Save a private reflection',
                    showTitle: false,
                    beforeRecord: () async {
                      _soundVisible = false;
                      _soundRevision++;
                      await _soundPlayer.stop();
                    },
                    onBusyChanged: (busy) {
                      if (mounted) {
                        setState(() => _recordingBusy = busy);
                        if (!busy && TickerMode.of(context)) {
                          _soundVisible = true;
                          unawaited(_playSelectedSound());
                        }
                      }
                    },
                  ),
                  controls: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IgnorePointer(
                        ignoring: _recordingBusy,
                        child: MeditationSoundPicker(
                          selected: _sound,
                          onSelected: _setSound,
                          onPreview: _previewSound,
                        ),
                      ),
                      if (_sound != null)
                        Slider(
                          key: const Key('meditation-sound-volume'),
                          value: _volume,
                          min: 0.05,
                          max: 0.3,
                          divisions: 5,
                          label: '${(_volume * 100).round()}%',
                          onChanged: _recordingBusy
                              ? null
                              : (value) {
                                  setState(() => _volume = value);
                                  unawaited(_soundPlayer.setVolume(value));
                                  unawaited(_saveSound());
                                },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _responseCard(
                  'PRAY',
                  reading.prayer,
                  Icons.volunteer_activism_outlined,
                  'Save as a prayer',
                  () => setState(() => _prayerEditor = true),
                  actionControl: _prayerEditor
                      ? InlineSpiritualResponseEditor(
                          key: ValueKey('prayer-${reading.id}'),
                          title: 'Prayer · ${reading.theme}',
                          initialText: reading.prayer,
                          editorKey: const Key('formation-prayer-editor'),
                          prayer: true,
                          enabled: !_recordingBusy,
                          onCancel: () => setState(() => _prayerEditor = false),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _responseCard(
                  'PLANT',
                  reading.practice,
                  Icons.spa_outlined,
                  'Turn this into a Goal',
                  () => setState(() => _goalEditor = true),
                  actionControl: _goalEditor
                      ? InlineSpiritualResponseEditor(
                          key: ValueKey('goal-${reading.id}'),
                          title: reading.theme,
                          initialText: reading.practice,
                          editorKey: const Key('formation-goal-editor'),
                          prayer: false,
                          enabled: !_recordingBusy,
                          onCancel: () => setState(() => _goalEditor = false),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Further reading',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  key: const Key('formation-further-reading'),
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final label in reading.supportingReferences)
                      SupportingReadingChip(label: label),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('complete-formation-reading'),
                  onPressed: _completing || _recordingBusy
                      ? null
                      : () => _complete(reading, index),
                  icon: Icon(
                    isComplete ? Icons.replay : Icons.check_circle_outline,
                  ),
                  label: Text(
                    isComplete
                        ? 'Continue to next meditation'
                        : 'Complete this meditation',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: index > 0 && !_recordingBusy
                          ? () => _open(formationReadings[index - 1])
                          : null,
                      child: const Text('Previous'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          index + 1 < formationReadings.length &&
                              !_recordingBusy
                          ? () => _open(formationReadings[index + 1])
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _responseCard(
    String label,
    String text,
    IconData icon,
    String action,
    VoidCallback onPressed, {
    Widget? controls,
    Widget? actionControl,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(text),
          if (controls != null) ...[
            const SizedBox(height: AppSpacing.sm),
            controls,
          ],
          if (actionControl != null)
            actionControl
          else
            TextButton.icon(
              onPressed: _recordingBusy ? null : onPressed,
              icon: Icon(icon),
              label: Text(action),
            ),
        ],
      ),
    ),
  );

  Future<void> _setSound(MeditationSoundBed? value) async {
    ++_soundRevision;
    setState(() {
      if (value != null && value != _sound) _volume = value.preferredVolume;
      _sound = value;
    });
    unawaited(_saveSound());
    await _playSelectedSound();
  }

  void _soundVisibilityChanged(bool visible) {
    _soundVisible = visible;
    ++_soundRevision;
    if (visible) {
      unawaited(_restoreSound());
    } else {
      unawaited(_soundPlayer.stop());
    }
  }

  Future<void> _restoreSound() async {
    final revision = _soundRevision;
    try {
      final preferences = await ref
          .read(meditationSoundPreferencesProvider)
          .load();
      if (!mounted || !_soundVisible || revision != _soundRevision) return;
      setState(() {
        _sound = preferences.sound;
        _volume = preferences.volume;
      });
      await _playSelectedSound();
    } catch (error) {
      debugPrint('Reading sound preference unavailable: $error');
    }
  }

  Future<void> _saveSound() async {
    try {
      await ref
          .read(meditationSoundPreferencesProvider)
          .save(MeditationSoundPreferences(sound: _sound, volume: _volume));
    } catch (_) {
      if (mounted && _soundVisible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sound preference could not be saved.')),
        );
      }
    }
  }

  Future<void> _playSelectedSound() async {
    try {
      final sound = _sound;
      if (!_soundVisible || sound == null) {
        await _soundPlayer.stop();
      } else {
        await _soundPlayer.start(sound, volume: _volume);
      }
    } catch (error) {
      debugPrint('Reading sound unavailable: $error');
    }
  }

  Future<void> _previewSound(MeditationSoundBed value) async {
    if (!mounted || !TickerMode.of(context)) return;
    try {
      await _soundPlayer.start(value, volume: value.preferredVolume);
    } catch (error) {
      debugPrint('Sound preview unavailable: $error');
    }
  }

  Future<ScripturePassage> _passageFor(FormationReading reading) {
    if (_passageReadingId != reading.id || _passageFuture == null) {
      _passageReadingId = reading.id;
      _passageFuture = ref
          .read(scriptureRepositoryProvider)
          .verses(
            book: reading.book,
            chapter: reading.chapter,
            firstVerse: reading.firstVerse,
            lastVerse: reading.lastVerse,
          );
    }
    return _passageFuture!;
  }

  Future<void> _complete(FormationReading reading, int index) async {
    setState(() => _completing = true);
    await ref.read(formationProgressRepositoryProvider).complete(reading.id);
    ref.invalidate(formationProgressProvider);
    if (!mounted) return;
    setState(() => _completing = false);
    if (index + 1 < formationReadings.length) {
      _open(formationReadings[index + 1]);
    }
  }

  void _open(FormationReading reading) =>
      context.pushReplacement('/prayers/meditation/${reading.id}');

  void _showReadings(Set<String> completed) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: formationReadings.length,
      itemBuilder: (_, index) {
        final reading = formationReadings[index];
        return ListTile(
          leading: Icon(
            completed.contains(reading.id)
                ? Icons.check_circle
                : Icons.circle_outlined,
          ),
          title: Text(reading.theme),
          subtitle: Text(reading.reference),
          onTap: () {
            Navigator.pop(sheetContext);
            _open(reading);
          },
        );
      },
    ),
  );

  Widget _error() => Scaffold(
    appBar: AppBar(title: const Text('Grow closer to God')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('This meditation could not be opened.'),
          TextButton(
            onPressed: () {
              ref.invalidate(formationProgressProvider);
              setState(() {});
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
