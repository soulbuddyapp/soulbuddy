# Orientation reader implementation plan

**Goal:** Ship the approved eight-course audio reader with slower playback options, synchronized text, saved progress, and the user's positive editorial revisions.

**Architecture:** Bundle edited audio and provider-timed transcripts. A media-time domain and serialized playback controller drive a Flutter reader. Existing secure device storage persists progress and preferences; onboarding and Settings expose the library.

**Tech stack:** Flutter, Riverpod, audioplayers, flutter_secure_storage, locally generated MP3/JSON/WebVTT assets.

## Tasks

- [x] Update the three affected narration segments and titles; rebuild exact timestamp data; bundle eight flat MP3/JSON assets and catalog in apps/soulbuddy/assets/orientation.
- [x] Add domain cue lookup, validated progress/preferences storage and a playback controller under lib/features/orientation; write unit tests before implementation covering seeks, rate changes, completion, reopening and errors.
- [x] Add providers and reader/library widgets. Widget tests exercise speed selection, manual scroll/follow, highlight movement, replay, failure and large text on a small screen.
- [x] Add an Orientation action to the welcome flow and a permanent Settings entry. Opening orientation does not complete onboarding; Skip for now preserves the existing route into Today.
- [x] Validate bundled text and cues, run focused tests/analyzer, build and inspect real browser playback, then obtain an independent code review and resolve material findings.

## Concrete checks

Run from apps/soulbuddy:

```powershell
flutter test test/features/orientation
flutter test test/features/onboarding
flutter analyze
flutter build web
```

Success requires matching source text and timestamp bounds for every course; highlighting follows the audio playhead at all rates; leaving pauses audio and persists position; navigation, retry and replay work without autoplay.

## Editorial scope

The current catalog, narrator, subtitles and shared preview use the two positive replacement sentences supplied by the user. Historical source documents are preserved; retired audio drafts are identified as outdated.


