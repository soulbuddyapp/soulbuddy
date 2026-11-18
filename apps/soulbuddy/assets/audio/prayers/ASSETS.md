# Built-in prayer narration

The nine MP3 recordings were generated from the approved `assets/content/prayer_library.json` prayer bodies with Microsoft `en-US-JennyNeural` at -8%, using `edge-tts` 7.3.1. They are synthesized voices, not human recordings. The manifest links each stable prayer ID to the SHA-256 hash of its exact UTF-8 body; mismatched audio is not used. Generation processes only bundled public editorial text, never a person's prayer.

Regenerate using `python tools/audio/generate_prayer_audio.py` with `edge-tts` 7.3.1. The generator also copies each MP3 to Android notification resources and converts the first eight to iOS notification sounds. The ninth is longer than iOS’s 30-second limit, so its reminder uses the short cue and the full prayer can play after opening. The test `test/features/prayers/bundled_prayer_audio_test.dart` checks coverage, text hashes, Android copy identity and iOS files. All nine files decoded with ffprobe; human listening and editorial review are still needed before release.

`prayer_reflection_v1.wav` is a five-second generic spoken reminder: “Be still. Give thanks, and bring this moment to God.” It is generated using the same voice and stored in Android raw resources and the iOS Sounds bundle. Existing explicit silent and device sound selections are preserved.
