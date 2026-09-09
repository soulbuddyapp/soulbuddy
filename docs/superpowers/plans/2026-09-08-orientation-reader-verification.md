# Orientation reader verification

Verified locally on 2026-09-08, branch `codex/orientation-reader`.

- `python scripts/orientation/verify_assets.py`: all eight MP3s fully decode; all timed words cover the exact text; ordered cues remain within actual audio duration; the positive replacement wording is present.
- `flutter test --no-pub test/features/orientation test/features/onboarding`: 67 tests passed.
- `flutter analyze --no-pub`: no issues.
- `flutter build web --no-pub`: successful release web build and Wasm dry run.
- Independent review found and resolved onboarding Overlay/navigation, failed-storage restoration, delayed post-seek updates, keyboard follow, and large-text error-state layout issues. Final scoped reviewer tests passed.

## Real browser checks

Chromium browser at a 390×844 viewport, serving the release build locally with HTTP byte-range support:

1. Opened orientation from the first-use welcome without completing onboarding.
2. Opened Welcome paused at zero; selected 0.75×; observed the actual HTML media clock advance at rate 0.75 with the 72.178-second MP3 loaded.
3. Visually inspected active sentence and underlined spoken word while playback automatically followed the transcript.
4. Used Forward 10 seconds; actual media time and displayed time moved forward together.
5. Paused near 21.879 seconds, left, and reopened: the reader remained paused at 0:21 with 0.75× retained. Continue played from approximately 22 seconds.
6. Used Skip for now during playback: audio stopped and Today opened.
7. Reopened via Settings → Orientation, used Start again and tapped a sentence: position moved to its timed start while remaining paused.

Screenshots: `.artifacts/orientation/orientation-reader-live.png` and `orientation-reader-final.png`.

The initial Python SimpleHTTPServer lacked range support: browser `seekable` was [0, 0] despite fully buffered audio. A local range-aware server reported the full [0, 72.178209] interval and the seek/restore checks then passed. Production static hosting must support media byte-range requests. This is documented in README.

Native iOS/Android device playback was not exercised in this verification. The broader course-to-practice integration remains a separate proposal in `../specs/2026-09-08-course-daily-practice.md`.
