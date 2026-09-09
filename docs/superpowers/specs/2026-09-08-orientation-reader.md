# Orientation audio with a synchronized reader — approved design

## User requirements

Keep the approved welcome and seven story-based lessons. Give listeners control over speed, highlight the spoken text, and follow the narration by scrolling. Preserve skipping, continuing later, and replaying every course.

## Recommended experience

Use an interactive audio reader in the Flutter app. It supports readable text at the person's chosen size and listening pace; a video can be exported separately from the same timing data.

- Start at 1×. Offer 0.5×, 0.75×, 0.85×, 1×, 1.25× and 1.5×, and remember the selected speed on the device.
- Highlight the current sentence with a visible border/background and the current word with weight and underline. Keep surrounding text readable.
- Scroll the active sentence into view when it changes. Scrolling the transcript manually suspends automatic following; a Follow narration button restores it.
- Tapping a sentence seeks to its beginning. Pausing, seeking and changing speed preserve alignment because highlighting follows audio position, never elapsed wall-clock time.
- Allow playback, pause, seek, replay and return to the course list. A person may skip orientation and continue using the app.
- Save position per course and speed on the device. Offer Continue from where you stopped, and a separate Start again action. Returning to a course never autoplays.
- Provide a permanent Orientation entry in Settings and an introduction entry from the existing welcome flow. Course completion never locks access.
- Support large text, accessible control labels and reduced motion; reduced motion follows without animated scrolling.
- An audio error leaves the transcript readable and offers Retry.

## Assets and timing

Bundle the eight recordings and exact text with timed word spans. Capture speech-provider word boundaries from the same synthesis used for the final audio. Adjust timestamps for the leading-silence trim, inserted pauses and intro music offset. Export sentence cues and WebVTT alongside word spans.

Do not estimate timings by dividing a paragraph equally between its words. Validate that all spoken words are represented, cue times are monotonic and within the recording, and the complete text matches the approved script.

## App boundaries

- Orientation catalog/domain: course identity, title, source text and timed cues; media-time lookup independent of speed.
- Playback adapter: the existing audioplayers dependency, with position/duration/state streams and playback-rate control.
- Progress repository: per-course media position, completion and listening speed, using the existing device storage pattern.
- Reader and library screens: playback controls, transcript following and navigation.
- Onboarding/Settings integration: access the reader without removing the existing skip route.

## Verification

Cover cue boundaries and gaps, backwards/forwards seeks, speed changes, pause/continue after reopening, replay after completion, manual-scroll suspension, reduced motion, large text, asset validity, error recovery and navigation from welcome and Settings. Verify real playback and scrolling on a browser or device in addition to widget tests.

## Alternative

A captioned video can show exactly the same highlighted sentences. Its player must expose playback speed. Video fixes the text layout and is less adaptable to a person's font size; it is best kept as a shareable version of the interactive reader.


