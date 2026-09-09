import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../scripture/domain/scripture_passage.dart';
import '../../scripture/providers/scripture_providers.dart';
import '../data/formation_progress_repository.dart';
import '../domain/formation_reading.dart';
import '../providers/formation_providers.dart';

class FormationReadingScreen extends ConsumerStatefulWidget {
  const FormationReadingScreen({this.readingId, super.key});

  final String? readingId;

  @override
  ConsumerState<FormationReadingScreen> createState() =>
      _FormationReadingScreenState();
}

class _FormationReadingScreenState
    extends ConsumerState<FormationReadingScreen> {
  final _soundPlayer = AudioplayersMeditationSoundBedPlayer();
  MeditationSoundBed? _sound;
  double _volume = 0.15;
  bool _completing = false;
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
    return ScreenAwake(child: _buildReading(context));
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
            onPressed: () => _showReadings(completed),
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
                  () {
                    final uri = Uri(
                      path: '/remember/capture',
                      queryParameters: {
                        'mode': 'reflection',
                        'source': 'formation',
                        'title': 'Reflection · ${reading.theme}',
                        'prompt': reading.meditation,
                      },
                    );
                    context.go(uri.toString());
                  },
                  controls: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MeditationSoundPicker(
                        selected: _sound,
                        onSelected: _setSound,
                        onPreview: _previewSound,
                      ),
                      if (_sound != null)
                        Slider(
                          key: const Key('meditation-sound-volume'),
                          value: _volume,
                          min: 0.05,
                          max: 0.3,
                          divisions: 5,
                          label: '${(_volume * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _volume = value);
                            unawaited(_soundPlayer.setVolume(value));
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
                  () {
                    final uri = Uri(
                      path: '/prayers/create',
                      queryParameters: {
                        'context': '${reading.theme} · ${reading.reference}',
                        'starter': reading.prayer,
                        'purpose': 'guidance',
                      },
                    );
                    context.go(uri.toString());
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _responseCard(
                  'PLANT',
                  reading.practice,
                  Icons.spa_outlined,
                  'Turn this into a Goal',
                  () => context.push('/welcome/goal'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Further reading: ${reading.supportingReferences.join(' · ')}',
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('complete-formation-reading'),
                  onPressed: _completing
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
                      onPressed: index > 0
                          ? () => _open(formationReadings[index - 1])
                          : null,
                      child: const Text('Previous'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: index + 1 < formationReadings.length
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
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(action),
          ),
        ],
      ),
    ),
  );

  Future<void> _setSound(MeditationSoundBed? value) async {
    setState(() {
      _sound = value;
      if (value != null) _volume = value.preferredVolume;
    });
    if (value == null) return _soundPlayer.stop();
    await _soundPlayer.start(value, volume: _volume);
  }

  Future<void> _previewSound(MeditationSoundBed value) =>
      _soundPlayer.start(value, volume: value.preferredVolume);

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
      context.go('/prayers/meditation/${reading.id}');

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
