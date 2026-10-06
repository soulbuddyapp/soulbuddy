import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/audio/narration_speed.dart';
import '../../../core/presentation/screen_awake.dart';
import '../domain/meditation_session.dart';
import 'affirmation_prayer_session_controller.dart';

/// The two sound families of the Prayer of attention.
///
/// Creation sounds are offered as help for quiet attention, never as a source
/// of spiritual power.
enum AffirmationPrayerSoundFamily {
  creation('Creation sounds', [
    MeditationSoundBed.oceanWaves,
    MeditationSoundBed.flowingWater,
    MeditationSoundBed.gentleRain,
    MeditationSoundBed.softWind,
    MeditationSoundBed.forestMorning,
  ]),
  instrumental('Quiet instrumental music', [
    MeditationSoundBed.hopefulPiano,
    MeditationSoundBed.cinematicRise,
    MeditationSoundBed.steadyResolve,
    MeditationSoundBed.warmStrings,
    MeditationSoundBed.victoriousCalm,
  ]);

  const AffirmationPrayerSoundFamily(this.label, this.sounds);

  final String label;
  final List<MeditationSoundBed> sounds;
}

/// The starting pace, shared by the setup surface and the player.
const double affirmationPrayerDefaultSpeed = defaultNarrationSpeed;

/// Plays the selected bed low, and lowers it for a focused pause.
class AffirmationPrayerBedPlayer implements AffirmationPrayerSoundBed {
  AffirmationPrayerBedPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  var _generation = 0;
  double? _volume;

  @override
  Future<void> start({required String soundKey, required double volume}) async {
    final generation = ++_generation;
    final bed = _bedFor(soundKey);
    if (bed == null) return;

    try {
      await _player.stop();
      if (generation != _generation) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      // The bed stays low enough for spoken prayer.
      await _player.setVolume(volume.clamp(0.0, 0.3));
      _volume = volume;
      await _player.play(AssetSource(bed.assetPath));
    } on Exception {
      // A missing or unavailable bed leaves the practice in quiet.
    }
  }

  @override
  Future<void> duck() async {
    final volume = _volume ?? affirmationPrayerDefaultSpeed;

    try {
      await _player.setVolume((volume * .4).clamp(0.0, 0.3));
    } on Exception {
      // Ducking is best effort; the prayer continues either way.
    }
  }

  @override
  Future<void> restore() async {
    final volume = _volume;
    if (volume == null) return;

    try {
      await _player.setVolume(volume.clamp(0.0, 0.3));
    } on Exception {
      // Restoring is best effort.
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _player.stop();
    } on Exception {
      // Stopping must never throw during teardown.
    }
  }

  @override
  void dispose() {
    _generation++;
    _player.dispose();
  }

  MeditationSoundBed? _bedFor(String soundKey) {
    for (final bed in MeditationSoundBed.values) {
      if (bed.name == soundKey) return bed;
    }

    return null;
  }
}

/// Speaks the exact phrase text with the device voice at the chosen pace.
///
/// The only text ever spoken is the phrase the person can see. No substitute
/// script is read, and a request for audio the device cannot provide leaves the
/// person reading the same words in silence.
class AffirmationPrayerVoice implements AffirmationPrayerNarrationPlayer {
  AffirmationPrayerVoice({required this.speakPhrase});

  /// Reads one exact phrase at one pace. Injected so the spoken text is the
  /// visible text and nothing else.
  final Future<void> Function(String phrase, double speed) speakPhrase;

  @override
  Future<void> speak(String phrase, {required double speed}) async {
    try {
      await speakPhrase(phrase, speed);
    } on Exception {
      // Spoken guidance is optional; the prayer continues in silence.
    }
  }

  @override
  Future<void> repeat(String phrase, {required double speed}) {
    return speak(phrase, speed: speed);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Keeps the device awake through the shared screen-awake controller.
class AffirmationPrayerAwake implements AffirmationPrayerScreenAwake {
  AffirmationPrayerAwake(this.controller, this.owner);

  final ScreenAwakeController controller;
  final Object owner;

  @override
  Future<void> setEnabled(bool value) async {
    if (value) {
      controller.acquire(owner);
    } else {
      controller.release(owner);
    }
    await controller.settled;
  }
}
