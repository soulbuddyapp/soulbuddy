import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/sacred_surface.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import '../../goals/application/daily_faithfulness.dart';
import '../../goals/presentation/daily_practice_sheet.dart';
import '../../prayers/application/meditation_sound_bed_player.dart';
import '../../prayers/application/meditation_sound_preferences.dart';
import '../../prayers/domain/meditation_session.dart';
import '../../prayers/presentation/meditation_sound_picker.dart';
import '../../record/presentation/voice_notes_field.dart';
import '../../prayers/presentation/inline_spiritual_response_editor.dart';
import '../domain/daily_scripture.dart';
import '../providers/daily_scripture_providers.dart';

class DailyScriptureScreen extends ConsumerStatefulWidget {
  const DailyScriptureScreen({this.soundPlayer, super.key});
  final MeditationSoundBedPlayer? soundPlayer;
  @override
  ConsumerState<DailyScriptureScreen> createState() =>
      _DailyScriptureScreenState();
}

class _DailyScriptureScreenState extends ConsumerState<DailyScriptureScreen> {
  late final _player =
      widget.soundPlayer ?? AudioplayersMeditationSoundBedPlayer();
  MeditationSoundBed? _sound;
  double _volume = .15;
  bool _visible = false;
  int _revision = 0;
  String? _audioError;
  bool _recordingBusy = false;
  bool _prayerEditor = false;

  @override
  void dispose() {
    _visible = false;
    _revision++;
    unawaited(_player.dispose());
    super.dispose();
  }

  void _visibility(bool visible) {
    _visible = visible;
    final revision = ++_revision;
    if (!visible) {
      unawaited(_player.stop());
      return;
    }
    unawaited(_restore(revision));
  }

  Future<void> _restore(int revision) async {
    try {
      final preferences = await ref
          .read(meditationSoundPreferencesProvider)
          .load();
      if (!mounted || !_visible || revision != _revision) return;
      setState(() {
        _sound = preferences.sound;
        _volume = preferences.volume;
      });
      await _play();
    } catch (_) {
      /* A sound preference must not prevent reading. */
    }
  }

  Future<void> _play() async {
    try {
      if (!_visible || _sound == null) {
        await _player.stop();
      } else {
        await _player.start(_sound!, volume: _volume);
      }
    } catch (_) {
      if (mounted) setState(() => _audioError = 'Sound could not be played.');
    }
  }

  Future<void> _chooseSound(MeditationSoundBed? sound) async {
    ++_revision;
    if (!mounted) return;
    setState(() {
      _sound = sound;
      _volume = sound?.preferredVolume ?? .15;
      _audioError = null;
    });
    await _saveSound();
    await _play();
  }

  Future<void> _saveSound() async {
    try {
      await ref
          .read(meditationSoundPreferencesProvider)
          .save(MeditationSoundPreferences(sound: _sound, volume: _volume));
    } catch (_) {
      if (mounted) {
        setState(() => _audioError = 'Sound preference could not be saved.');
      }
    }
  }

  void _open(Uri uri) {
    if (_recordingBusy) return;
    _visibility(false);
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) => PracticeAudioScope(
    onVisibilityChanged: _visibility,
    child: ScreenAwake(
      child: Scaffold(
        appBar: AppBar(title: const Text('Daily scripture')),
        body: ref
            .watch(dailyScriptureProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Scripture could not be loaded.'),
                    TextButton(
                      onPressed: () => ref.invalidate(dailyScriptureProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: _reading,
            ),
      ),
    ),
  );

  Widget _reading(DailyScripture scripture) {
    final theme = Theme.of(context);
    final date = DateTime.parse(scripture.date);
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                MaterialLocalizations.of(context).formatFullDate(date),
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              SanctuaryReadingHeading(
                title: scripture.theme,
                art: SanctuaryArt.scripture,
              ),
              const SizedBox(height: 16),
              SacredSurface(
                marble: true,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scripture.reference,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      scripture.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 21,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      scripture.translation,
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Reflection', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(scripture.reflection, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: _recordingBusy,
                child: MeditationSoundPicker(
                  selected: _sound,
                  onSelected: _chooseSound,
                ),
              ),
              if (_sound != null)
                Slider(
                  value: _volume,
                  min: .05,
                  max: .3,
                  divisions: 5,
                  label: '${(_volume * 100).round()}%',
                  onChanged: _recordingBusy
                      ? null
                      : (value) {
                          setState(() => _volume = value);
                          unawaited(_player.setVolume(value));
                        },
                  onChangeEnd: (_) => unawaited(_saveSound()),
                ),
              if (_audioError != null)
                Text(
                  _audioError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              VoiceNotesField(
                key: ValueKey('scripture-reflection-${scripture.date}'),
                noteContext: (
                  type: 'daily_scripture',
                  id: scripture.date,
                  field: 'reflection',
                ),
                title: 'Reflection · ${scripture.reference}',
                recordLabel: 'Record reflection',
                showTitle: false,
                beforeRecord: () async {
                  _visible = false;
                  _revision++;
                  await _player.stop();
                },
                onBusyChanged: (busy) {
                  if (mounted) {
                    setState(() => _recordingBusy = busy);
                    if (!busy && TickerMode.of(context)) {
                      _visible = true;
                      unawaited(_play());
                    }
                  }
                },
              ),
              const Divider(height: 32),
              Text('Prayer', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                scripture.prayer,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              if (_prayerEditor)
                InlineSpiritualResponseEditor(
                  key: ValueKey('scripture-prayer-${scripture.date}'),
                  editorKey: const Key('scripture-prayer-editor'),
                  title: 'Prayer · ${scripture.theme}',
                  initialText: scripture.prayer,
                  prayer: true,
                  enabled: !_recordingBusy,
                  onCancel: () => setState(() => _prayerEditor = false),
                )
              else
                TextButton.icon(
                  onPressed: _recordingBusy
                      ? null
                      : () => setState(() => _prayerEditor = true),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: const Text('Personal prayer'),
                ),
              TextButton.icon(
                onPressed: () => _open(
                  Uri(
                    pathSegments: [
                      'remember',
                      'scripture',
                      scripture.book,
                      scripture.chapter.toString(),
                    ],
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Read full chapter'),
              ),
              const Divider(height: 32),
              Text(
                'Put faith into practice',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(scripture.practice, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _recordingBusy
                    ? null
                    : () => showDailyPracticeSheet(
                        context,
                        initial: scripture.precept == 'guard-the-gate'
                            ? SpiritualPrecept.guardTheGate
                            : SpiritualPrecept.strengthForToday,
                        suggestedAction: scripture.practice,
                      ),
                icon: const Icon(Icons.spa_outlined),
                label: const Text('Daily practice'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
