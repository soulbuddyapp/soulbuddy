# SoulBuddy orientation assets

Eight short, story-based courses for the interactive orientation reader. `catalog.json` is the ordered manifest. Each course has one final stereo MP3 and one transcript JSON. The bundle contains no raw voice recordings, WAV masters, instrument bank, or font.

## Voice and text provenance

The narration is an AI-generated Microsoft `en-US-GuyNeural` voice, generated using the edge-tts client (https://github.com/rany2/edge-tts). It is not a recording by a human speaker. The approved fast segment rates are retained: the welcome uses +8% with a +2% closing, and the stories use their existing +6% / +7% rates. The narrator is mixed with quiet instrumental music; the score ducks during speech.

These scripts adapt the user's supplied teaching (https://docs.google.com/document/d/1K1-kS6tVjoXD4u65oIb2kt5ImrMAbqiHzHD4AGFlMiI/edit), incorporating the approved short illustrative stories. The historical user source document was not edited. The September 8, 2026 editorial revision uses the positive title “Aim for a plentiful harvest” and the closing invitation “Plant something good in the garden each day”, including the final course. The instruction to “continue from where you stopped” remains in the welcome. Superseded local drafts are archived outside the app bundle.

## Music credits and license

An original, programmatically arranged 84 BPM piano-and-strings score was created for these courses. It uses GeneralUser GS v2.0.3 instrument samples by S. Christian Collins: https://schristiancollins.com/generaluser.php. The complete publisher-provided license is included as `GeneralUser-GS-LICENSE.txt`; it permits private and commercial music creation and describes the sample provenance. The instrument bank itself is not redistributed in this app.

The score was rendered with TinySoundFont Python bindings (https://github.com/nwhitehead/tinysoundfont) and mixed with FFmpeg. Those production tools are not bundled in the application. Production masters and scripts are retained under `.artifacts/orientation/production` and `.artifacts/orientation/follow-along` in the source workspace.

## Transcript timing and validation

Word timestamps are the speech provider's exact `WordBoundary` offsets and durations, shifted by each segment's measured audio trim and final timeline start. They are never estimated from text length. Times are rounded to milliseconds and bounded to each trimmed speech segment. Sentence ranges derive from the timed words. `charStart` is inclusive and `charEnd` exclusive. The current scripts contain only BMP Unicode characters, so these indices also match Dart string offsets.

Each transcript contains `id`, `title`, `tenet`, `durationMs`, `text`, `words`, and `sentences`. The manifest uses `orientation/<id>.mp3` for Audioplayers' `AssetSource` and `assets/orientation/<id>.json` for Flutter's asset bundle. The default narration includes intentional pauses and a short music tail.

Run `python scripts/orientation/verify_assets.py` from the repository root with FFmpeg and FFprobe available. It validates all eight complete audio decodes, manifest paths and durations, ordered character and time bounds, and full spoken-text coverage by both words and sentences. It also confirms the updated wording and retained resume invitation.
