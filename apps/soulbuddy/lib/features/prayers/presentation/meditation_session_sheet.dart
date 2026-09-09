import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/presentation/screen_awake.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../record/audio/application/memory_audio_player.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../domain/meditation_session.dart';
import '../domain/voice_tablet.dart';
import '../application/meditation_sound_bed_player.dart';
import '../application/meditation_sound_preferences.dart';

Future<void> showMeditationSessionSheet(
  BuildContext context,
  WidgetRef ref, {
  required VoiceTablet tablet,
  required VoiceTabletAudio selectedAudio,
}) async {
  final soundPlayer = AudioplayersMeditationSoundBedPlayer();
  final preferences = ref.read(meditationSoundPreferencesProvider);
  final coordinatorFuture = ref.read(
    memoryAudioPlaybackCoordinatorProvider.future,
  );
  var sessionGeneration = 0;
  Future<void> playVoice(VoiceTabletAudio audio) async {
    final generation = sessionGeneration;
    final coordinator = await coordinatorFuture;
    if (generation != sessionGeneration) return;
    await coordinator.playTrack(
      PrivateAudioTrack(
        id: audio.id,
        storageKey: audio.storageKey,
        duration: audio.duration,
      ),
    );
  }

  Future<void> stop() async {
    ++sessionGeneration;
    await Future.wait([
      soundPlayer.stop(),
      coordinatorFuture.then((coordinator) => coordinator.stop()),
    ]);
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MeditationSessionSheet(
        tablet: tablet,
        selectedAudio: selectedAudio,
        soundPreferences: preferences,
        onStart: (request) async {
          final generation = ++sessionGeneration;
          if (request.soundBed case final bed?) {
            await soundPlayer.start(bed, volume: request.soundVolume);
          }
          if (generation != sessionGeneration) return;
          if (request.includeVoice) {
            if (request.voiceAudio case final audio?) {
              await playVoice(audio);
            }
          }
        },
        onRepeatVoice: playVoice,
        onSoundVolume: soundPlayer.setVolume,
        onStop: stop,
      ),
    );
  } finally {
    try {
      await stop();
    } finally {
      await soundPlayer.dispose();
    }
  }
}

class MeditationSessionSheet extends StatefulWidget {
  const MeditationSessionSheet({
    required this.tablet,
    required this.selectedAudio,
    required this.onStart,
    this.onRepeatVoice,
    this.onSoundVolume,
    this.onStop,
    this.soundPreferences,
    super.key,
  });

  final VoiceTablet tablet;
  final VoiceTabletAudio selectedAudio;
  final Future<void> Function(MeditationSessionRequest) onStart;
  final Future<void> Function(VoiceTabletAudio)? onRepeatVoice;
  final Future<void> Function(double)? onSoundVolume;
  final Future<void> Function()? onStop;
  final MeditationSoundPreferencesRepository? soundPreferences;

  @override
  State<MeditationSessionSheet> createState() => _MeditationSessionSheetState();
}

class _MeditationSessionSheetState extends State<MeditationSessionSheet> {
  MeditationSoundBed? _soundBed;
  MeditationPrompt? _prompt;
  var _includeVoice = true;
  var _repeatRefrain = false;
  var _duration = const Duration(minutes: 3);
  var _soundVolume = 0.15;
  var _showPrompts = false;
  var _starting = false;
  var _running = false;
  String? _error;
  Timer? _sessionTimer;
  Timer? _repeatTimer;
  int _soundRevision = 0;
  int _sessionRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSound());
  }

  Future<void> _restoreSound() async {
    final revision = _soundRevision;
    try {
      final preferences = await widget.soundPreferences?.load();
      if (!mounted ||
          preferences == null ||
          revision != _soundRevision ||
          _starting ||
          _running) {
        return;
      }
      setState(() {
        _soundBed = preferences.sound;
        _soundVolume = preferences.volume;
      });
    } catch (error) {
      debugPrint('Meditation sound preference unavailable: $error');
    }
  }

  void _selectSound(MeditationSoundBed? sound) {
    ++_soundRevision;
    setState(() {
      if (sound != null && sound != _soundBed) {
        _soundVolume = sound.preferredVolume;
      }
      _soundBed = sound;
      if (sound == null) _includeVoice = true;
    });
    unawaited(_saveSound());
  }

  Future<void> _saveSound() async {
    try {
      await widget.soundPreferences?.save(
        MeditationSoundPreferences(sound: _soundBed, volume: _soundVolume),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sound preference could not be saved.');
      }
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _repeatTimer?.cancel();
    ++_sessionRevision;
    if (_running || _starting) unawaited(widget.onStop?.call());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PracticeAudioScope(
      onVisibilityChanged: (visible) {
        if (!visible && (_running || _starting)) unawaited(_stop());
      },
      child: ScreenAwake(child: _buildSession(context)),
    );
  }

  Widget _buildSession(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_starting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _running ? _runningView(context) : _setupView(context),
          ),
        ),
      ),
    );
  }

  Widget _setupView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Pray and remain', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(widget.tablet.title, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        height: 48,
        child: ListView(
          key: const Key('meditation-sound-list'),
          scrollDirection: Axis.horizontal,
          children: [
            ChoiceChip(
              label: const Text('Voice only'),
              selected: _soundBed == null,
              onSelected: _starting ? null : (_) => _selectSound(null),
            ),
            const SizedBox(width: AppSpacing.sm),
            for (final bed in MeditationSoundBed.values) ...[
              ChoiceChip(
                label: Text(bed.label),
                selected: _soundBed == bed,
                onSelected: _starting ? null : (_) => _selectSound(bed),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
      if (_soundBed != null) ...[
        CheckboxListTile(
          key: const Key('meditation-include-voice'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Include my voice'),
          value: _includeVoice,
          onChanged: _starting
              ? null
              : (value) => setState(() => _includeVoice = value ?? true),
        ),
        Text('Sound level', style: Theme.of(context).textTheme.labelLarge),
        Slider(
          key: const Key('meditation-sound-volume'),
          value: _soundVolume,
          min: 0.05,
          max: 0.3,
          divisions: 5,
          label: '${(_soundVolume * 100).round()}%',
          onChanged: _starting
              ? null
              : (value) {
                  setState(() => _soundVolume = value);
                  unawaited(widget.onSoundVolume?.call(value));
                  unawaited(_saveSound());
                },
        ),
      ],
      if (_includeVoice && widget.tablet.refrainAudio != null)
        CheckboxListTile(
          key: const Key('meditation-repeat-refrain'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Repeat my Prayer Refrain'),
          subtitle: const Text('With a quiet pause between each return.'),
          value: _repeatRefrain,
          onChanged: _starting
              ? null
              : (value) => setState(() => _repeatRefrain = value ?? false),
        ),
      if (_soundBed != null || _repeatRefrain) ...[
        Text('Length', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final minutes in const [3, 5, 10, 20])
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _duration == Duration(minutes: minutes),
                onSelected: _starting
                    ? null
                    : (_) => setState(
                        () => _duration = Duration(minutes: minutes),
                      ),
              ),
          ],
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _starting
              ? null
              : () => setState(() => _showPrompts = !_showPrompts),
          icon: const Icon(Icons.short_text),
          label: Text(_showPrompts ? 'Hide prompts' : 'Add a prompt'),
        ),
      ),
      if (_showPrompts)
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('None'),
              selected: _prompt == null,
              onSelected: (_) => setState(() => _prompt = null),
            ),
            for (final prompt in MeditationPrompt.values)
              ChoiceChip(
                label: Text(prompt.copy),
                selected: _prompt == prompt,
                onSelected: (_) => setState(() => _prompt = prompt),
              ),
          ],
        ),
      if (_error case final error?) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        key: const Key('begin-meditation'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
        ),
        onPressed: _starting ? null : _start,
        icon: const Icon(Icons.play_arrow),
        label: Text(_starting ? 'Opening…' : 'Begin'),
      ),
    ],
  );

  Widget _runningView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Pray and remain', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.lg),
      if (_prompt case final prompt?)
        Semantics(
          liveRegion: true,
          child: Text(
            prompt.copy,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        )
      else
        Text(
          widget.tablet.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton.icon(
        key: const Key('stop-meditation'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchTarget),
        ),
        onPressed: _stop,
        icon: const Icon(Icons.stop),
        label: const Text('Stop'),
      ),
    ],
  );

  Future<void> _start() async {
    if (!_includeVoice && _soundBed == null) return;
    final revision = ++_sessionRevision;
    ++_soundRevision;
    setState(() {
      _starting = true;
      _error = null;
    });
    final voiceAudio = _includeVoice
        ? (_repeatRefrain ? widget.tablet.refrainAudio : widget.selectedAudio)
        : null;
    final request = MeditationSessionRequest(
      duration: _duration,
      soundBed: _soundBed,
      includeVoice: _includeVoice,
      repeatRefrain: _repeatRefrain,
      soundVolume: _soundVolume,
      prompt: _prompt,
      voiceAudio: voiceAudio,
    );
    try {
      await widget.onStart(request);
      if (!mounted || revision != _sessionRevision) return;
      setState(() {
        _starting = false;
        _running = true;
      });
      if (_soundBed != null || _repeatRefrain) {
        _sessionTimer = Timer(_duration, _stop);
      }
      if (_repeatRefrain && voiceAudio != null) {
        _repeatTimer = Timer.periodic(
          voiceAudio.duration + const Duration(seconds: 30),
          (_) => unawaited(widget.onRepeatVoice?.call(voiceAudio)),
        );
      }
    } catch (_) {
      if (mounted && revision == _sessionRevision) {
        setState(() {
          _starting = false;
          _error = 'Could not begin this prayer time just now.';
        });
      }
    }
  }

  Future<void> _stop() async {
    ++_sessionRevision;
    _sessionTimer?.cancel();
    _repeatTimer?.cancel();
    _sessionTimer = null;
    _repeatTimer = null;
    try {
      await widget.onStop?.call();
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _starting = false;
        });
      }
    }
  }
}
