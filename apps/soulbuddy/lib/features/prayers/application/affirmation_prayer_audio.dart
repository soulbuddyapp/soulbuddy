import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/audio/narration_speed.dart';
import '../../../core/presentation/screen_awake.dart';
import '../domain/meditation_session.dart';
import '../domain/worship_sound_bed.dart';
import 'affirmation_prayer_session_controller.dart';

/// The three sound families of the Prayer of attention.
///
/// Creation sounds are offered as help for quiet attention, never as a source
/// of spiritual power. Worship is offered only here, which is why it lives in
/// this enum and not in the shared picker.
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
  ]),
  worship('Quiet worship music', [
    WorshipSoundBed.tenThousandReasons,
    WorshipSoundBed.animaChristi,
  ]);

  const AffirmationPrayerSoundFamily(this.label, this.sounds);

  final String label;
  final List<PrayerSoundBed> sounds;

  /// The level a bed in this family should start at when it is chosen.
  ///
  /// Every existing bed keeps the level already on the slider; only worship
  /// adopts its own, because its two arrangements are 4.3 dB apart and one
  /// shared number would leave one of them wrong.
  double levelFor(PrayerSoundBed bed, double current) =>
      bed is WorshipSoundBed ? bed.preferredVolume : current;
}

/// Resolves a saved sound key to the bed it names, across both families.
///
/// A key this does not recognise is silence, never a guess.
PrayerSoundBed? prayerSoundBedFor(String soundKey) {
  for (final bed in MeditationSoundBed.values) {
    if (bed.key == soundKey) return bed;
  }
  for (final bed in WorshipSoundBed.values) {
    if (bed.key == soundKey) return bed;
  }
  return null;
}

/// The starting pace, shared by the setup surface and the player.
const double affirmationPrayerDefaultSpeed = defaultNarrationSpeed;

/// Plays the selected bed low, and lowers it for a focused pause.
///
/// Ambient beds are short seamless loops and repeat. Worship arrangements are
/// complete songs: they are never looped, and the last seconds are faded down
/// so the practice is never cut off mid-phrase and never has to pretend the
/// song is still going.
class AffirmationPrayerBedPlayer implements AffirmationPrayerSoundBed {
  AffirmationPrayerBedPlayer({
    AudioPlayer? player,
    this.fadeSteps = 8,
    this.fadeStep = const Duration(milliseconds: 120),
    Future<void> Function(Duration)? delay,
  }) : _player = player ?? AudioPlayer(),
       _delay = delay ?? Future<void>.delayed;

  /// How many volume steps the closing fade is made of.
  final int fadeSteps;

  /// The gap between them. The two together are the fade's length, which must
  /// be short enough to fit inside [WorshipSoundBed.duration] and long enough
  /// to be heard as a fade.
  final Duration fadeStep;

  final AudioPlayer _player;
  final Future<void> Function(Duration) _delay;
  var _generation = 0;
  double? _volume;
  Future<void> _pending = Future.value();

  @override
  Future<void> start({required String soundKey, required double volume}) async {
    final generation = ++_generation;
    final bed = prayerSoundBedFor(soundKey);
    if (bed == null) return;

    final starting = _pending.then((_) async {
      try {
        await _player.stop();
        if (generation != _generation) return;
        // A worship arrangement is a whole song, so it is released at its end
        // rather than looped. Treating it as a loop would replay a chorus
        // nobody chose to hear again.
        final worship = bed is WorshipSoundBed;
        await _player.setReleaseMode(
          worship ? ReleaseMode.release : ReleaseMode.loop,
        );
        if (generation != _generation) return;
        // The bed stays low enough for spoken prayer.
        await _player.setVolume(volume.clamp(0.0, 0.3));
        _volume = volume;
        await _player.play(AssetSource(bed.assetPath));
        if (generation != _generation) return;
        if (worship) {
          _pending = _fadeOutAtEnd(bed.duration, generation);
        }
      } on Exception {
        // A missing or unavailable bed leaves the practice in quiet.
      }
    });
    _pending = starting.catchError((Object _) {});
    return starting;
  }

  @override
  Future<void> duck() async {
    final volume = _volume;
    // Nothing is playing, so there is nothing to lower. This previously fell
    // back to the narration default, which is a speed and not a level.
    if (volume == null) return;

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
    ++_generation;
    _volume = null;
    try {
      await _player.stop();
    } on Exception {
      // Stopping must never throw during teardown.
    }
    await _pending;
  }

  @override
  void dispose() {
    _generation++;
    _volume = null;
    _player.dispose();
  }

  /// Lowers the level to nothing over the last seconds of a song.
  ///
  /// The step count is derived from the bed's own length so the fade always
  /// lands on its last moment, and it ends at silence rather than at a cut. A
  /// generation change — a pause, a change of bed, leaving the screen — cancels
  /// it, because the fade belongs to the bed that was playing and not to
  /// whatever plays next.
  Future<void> _fadeOutAtEnd(Duration duration, int generation) async {
    final fade = fadeStep * fadeSteps;
    if (duration <= fade) return;

    var remaining = duration - fade;
    await _delay(remaining);
    if (generation != _generation) return;

    final volume = _volume;
    if (volume == null) return;

    for (var step = 1; step <= fadeSteps; step++) {
      if (generation != _generation) return;
      final level = volume * (1 - step / fadeSteps);
      try {
        await _player.setVolume(level.clamp(0.0, 0.3));
      } on Exception {
        return;
      }
      if (step < fadeSteps) await _delay(fadeStep);
    }
  }
}

/// Speaks the exact phrase through a validated audio asset.
///
/// The asset is fetched only for content whose recorded transcript hash matched
/// the release content hash on the server. A repeated read replays that same
/// asset, and neither a first read nor a repeat ever advances a count.
class AffirmationPrayerVoice implements AffirmationPrayerNarrationPlayer {
  AffirmationPrayerVoice({
    required this.speakPhrase,
    AudioPlayer? player,
    this.downloadBudgetBytes = 2_000_000,
  }) : _player = player ?? AudioPlayer();

  /// Reads one exact phrase at one pace. Injected so the spoken text is the
  /// visible text and nothing else.
  final Future<void> Function(String phrase, double speed) speakPhrase;

  /// Refuse an implausibly large asset rather than buffering it.
  final int downloadBudgetBytes;

  final AudioPlayer _player;
  var _generation = 0;
  Completer<void>? _reading;
  StreamSubscription<void>? _completion;

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

  /// Plays validated narration bytes at the chosen pace.
  ///
  /// The returned future completes when the phrase has actually finished
  /// being read, or when it is stopped. That is what lets the bed be lowered
  /// for exactly as long as the guide is speaking and then brought back up,
  /// rather than for an arbitrary span guessed from the words.
  Future<void> playAsset(Uint8List bytes, {required double speed}) async {
    if (bytes.isEmpty || bytes.length > downloadBudgetBytes) return;

    final generation = ++_generation;
    final read = Completer<void>();
    _reading = read;
    try {
      await _player.stop();
      if (generation != _generation) return;
      // The player also reports completion when it is stopped, so the pending
      // read is listened for before playback begins and both paths end it.
      _completion?.cancel();
      _completion = _player.onPlayerComplete.listen((_) {
        if (generation == _generation && !read.isCompleted) read.complete();
      });
      await _player.play(
        BytesSource(bytes, mimeType: 'audio/mpeg'),
        ctx: AudioContextConfig(
          respectSilence: true,
          stayAwake: false,
          // The guide ducks the bed rather than silencing it.
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      await _player.setPlaybackRate(speed);
      if (generation != _generation) return;
      await read.future;
    } on Exception {
      // An unplayable asset leaves the person reading the same words.
    } finally {
      if (identical(_reading, read)) _reading = null;
    }
  }

  @override
  Future<void> stop() async {
    ++_generation;
    final reading = _reading;
    _reading = null;
    _completion?.cancel();
    _completion = null;
    try {
      await _player.stop();
    } on Exception {
      // Stopping must never throw during teardown.
    }
    // Ending the read is what releases whoever is waiting on the guide.
    if (reading != null && !reading.isCompleted) reading.complete();
  }

  @override
  void dispose() {
    ++_generation;
    _completion?.cancel();
    _completion = null;
    _player.dispose();
  }
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
