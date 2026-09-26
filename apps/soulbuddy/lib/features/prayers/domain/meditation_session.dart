import 'voice_tablet.dart';

enum MeditationSoundCategory { quiet, motivational }

enum MeditationSoundBed {
  stillness(label: 'Stillness', assetPath: 'audio/meditation/stillness.mp3'),
  flowingWater(
    label: 'Flowing water',
    assetPath: 'audio/meditation/flowing_water.mp3',
  ),
  gentleRain(
    label: 'Gentle rain',
    assetPath: 'audio/meditation/gentle_rain.mp3',
  ),
  oceanWaves(
    label: 'Ocean waves',
    assetPath: 'audio/meditation/ocean_waves.mp3',
  ),
  forestMorning(
    label: 'Forest morning',
    assetPath: 'audio/meditation/forest_morning.mp3',
  ),
  softWind(label: 'Soft wind', assetPath: 'audio/meditation/soft_wind.mp3'),
  warmFireplace(
    label: 'Warm fireplace',
    assetPath: 'audio/meditation/warm_fireplace.mp3',
  ),
  nightCrickets(
    label: 'Night crickets',
    assetPath: 'audio/meditation/night_crickets.mp3',
  ),
  hopefulPiano(
    label: 'Resolutions',
    assetPath: 'audio/meditation/hopeful_piano.mp3',
    category: MeditationSoundCategory.motivational,
    preferredVolume: 0.22,
  ),
  cinematicRise(
    label: 'Aurora',
    assetPath: 'audio/meditation/cinematic_rise.mp3',
    category: MeditationSoundCategory.motivational,
    preferredVolume: 0.22,
  ),
  steadyResolve(
    label: 'Affirmations',
    assetPath: 'audio/meditation/steady_resolve.mp3',
    category: MeditationSoundCategory.motivational,
    preferredVolume: 0.22,
  ),
  warmStrings(
    label: 'First Snow',
    assetPath: 'audio/meditation/warm_strings.mp3',
    category: MeditationSoundCategory.motivational,
    preferredVolume: 0.22,
  ),
  victoriousCalm(
    label: 'A Kind Of Hope',
    assetPath: 'audio/meditation/victorious_calm.mp3',
    category: MeditationSoundCategory.motivational,
    preferredVolume: 0.22,
  );

  const MeditationSoundBed({
    required this.label,
    required this.assetPath,
    this.category = MeditationSoundCategory.quiet,
    this.preferredVolume = 0.15,
  });

  final String label;
  final String assetPath;
  final MeditationSoundCategory category;
  final double preferredVolume;
}

enum MeditationPrompt {
  beStill('Be still.'),
  remember('Remember what God has done.'),
  speakSlowly('Speak this prayer slowly.'),
  remain('Remain with these words.'),
  carryForward('Carry this into your next action.');

  const MeditationPrompt(this.copy);
  final String copy;
}

class MeditationSessionRequest {
  const MeditationSessionRequest({
    required this.duration,
    required this.includeVoice,
    required this.repeatRefrain,
    required this.soundVolume,
    this.soundBed,
    this.prompt,
    this.voiceAudio,
  });

  final Duration duration;
  final MeditationSoundBed? soundBed;
  final bool includeVoice;
  final bool repeatRefrain;
  final double soundVolume;
  final MeditationPrompt? prompt;
  final VoiceTabletAudio? voiceAudio;
}
