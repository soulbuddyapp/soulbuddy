import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/practice_audio_scope.dart';
import '../../../core/presentation/screen_awake.dart';
import '../application/meditation_sound_bed_player.dart';
import '../domain/meditation_session.dart';
import 'meditation_sound_picker.dart';

class QuietPrayerScreen extends StatefulWidget {
  const QuietPrayerScreen({this.soundPlayer, super.key});
  final MeditationSoundBedPlayer? soundPlayer;

  @override
  State<QuietPrayerScreen> createState() => _QuietPrayerScreenState();
}

class _QuietPrayerScreenState extends State<QuietPrayerScreen> {
  late final _player =
      widget.soundPlayer ?? AudioplayersMeditationSoundBedPlayer();
  MeditationSoundBed? _sound;
  bool _visible = false;
  String? _error;

  void _visibility(bool visible) {
    _visible = visible;
    if (!visible) {
      unawaited(_player.stop());
    } else if (_sound != null) {
      unawaited(_syncSound());
    }
  }

  Future<void> _select(MeditationSoundBed? sound) async {
    setState(() {
      _sound = sound;
      _error = null;
    });
    await _syncSound();
  }

  Future<void> _syncSound() async {
    try {
      final sound = _sound;
      if (sound == null || !_visible) {
        await _player.stop();
      } else {
        await _player.start(sound, volume: sound.preferredVolume);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Sound could not be played.');
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PracticeAudioScope(
    onVisibilityChanged: _visibility,
    child: ScreenAwake(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiet prayer'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/today'),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Be still',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      MeditationSoundPicker(
                        selected: _sound,
                        onSelected: _select,
                      ),
                      if (_error != null) Text(_error!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
