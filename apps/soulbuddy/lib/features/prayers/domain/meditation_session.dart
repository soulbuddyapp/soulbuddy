import 'voice_tablet.dart';

enum MeditationSoundBed {
  stillness(label: 'Stillness', assetPath: 'audio/meditation/stillness.mp3'),
  flowingWater(
    label: 'Flowing water',
    assetPath: 'audio/meditation/flowing_water.mp3',
  );

  const MeditationSoundBed({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
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
