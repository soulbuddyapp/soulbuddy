# Premium Formation and Memory Experience — approved design

## Product intent

SoulBuddy should turn orientation, Scripture, prayer, action, and remembrance into one short daily formation path. The experience stays private and local-first. It encourages practice without scoring holiness, creating spiritual streak pressure, or claiming outcomes for the user.

The compact orientation items are **Nuggets**. The longer source teaching remains available as **the full course**. The app uses the approved invitations **“Aim for a plentiful harvest”** and **“Plant something good in the garden each day.”** Retired wording must not appear in user-facing copy or narration.

## Experience architecture

The Today screen owns one premium formation card titled **Grow closer to God**.

1. Before all eight Nuggets are completed, the card opens the first unfinished Nugget. It says **Start orientation** before any progress and **Continue orientation** afterward, with a visible `n of 8` progress line.
2. Completing one Nugget moves directly to the next through persistent Previous and Next controls. Nuggets remain replayable at any time.
3. The Nuggets library offers a separate **Read or listen to the full course** entry. The full course is optional and never blocks completion.
4. After all eight Nuggets are completed, the Today card becomes the next staged Scripture meditation. One reading is presented at a time in the curated order below.
5. Every Nugget and Scripture meditation ends with three optional responses: a short reviewed prayer, a private reflection/confession prompt, and one editable practical seed. The user chooses whether to save any of them.

The presentation is content-first and restrained: strong type hierarchy, the existing covenant/garden visual language, 48dp controls, 150–300ms meaningful transitions, large-text support, reduced-motion support, and no visual dashboard or completion score.

## Nugget and full-course reader

All user-facing compact-item labels change from Course to Nugget. Internal Dart class names may remain stable where renaming would add migration risk.

The existing synchronized reader remains the shared reader for Nuggets and the full course:

- actual media-time sentence and word highlighting;
- automatic scrolling with a visible Follow narration recovery control after manual scrolling;
- saved position and completion;
- 0.5×, 0.75×, 0.85×, 1×, 1.25×, and 1.5× speed;
- Previous and Next without leaving the reader;
- no autoplay;
- retry on media failure while the text remains readable.

The full course uses the source teaching with editorial corrections, a motivational narration, and precise timing data. Its completion does not affect the eight-Nugget orientation gate.

## Curated Scripture formation path

The curriculum uses static, reviewed metadata and reads verse text from the bundled RSVCE database. Each stage has a primary passage and supporting passages; the first release presents the primary passage and exposes the supporting references as optional further reading.

| Stage | Theme | Primary reading | Supporting readings | Practice focus |
|---|---|---|---|---|
| 1 | Effects of sin and denouncing sin | Romans 6:12–14 | Psalm 51:1–12; Mark 7:20–23 | Name and remove one opening for sin. |
| 2 | Overcoming sin in Christ | Romans 8:1–14 | 1 Corinthians 10:12–13; 1 John 1:5–9 | Choose one hopeful next step after a fall. |
| 3 | Holy Spirit and kingdom righteousness | Galatians 5:16–25 | John 14:15–27; Matthew 6:31–34 | Pause, pray, and listen before one decision. |
| 4 | God’s purpose in our lives | Ephesians 2:8–10 | Jeremiah 1:4–8; Romans 12:1–8 | Use one entrusted gift in service. |
| 5 | Practicing discipline | 1 Corinthians 9:24–27 | Proverbs 4:20–27; Hebrews 12:1–11 | Keep one small faithful practice today. |
| 6 | Understanding humility | Philippians 2:3–11 | Luke 14:7–14; Romans 12:3–5 | Give thanks for a gift without self-display. |
| 7 | Practicing humility | John 13:1–17 | Micah 6:6–8; 1 Peter 5:5–7 | Do one useful act of service quietly. |
| 8 | Forgiveness | Matthew 18:21–35 | Luke 15:11–32; Colossians 3:12–15 | Pray honestly and choose a safe act of repair. |
| 9 | Charity | 1 Corinthians 13:1–13 | Luke 10:25–37; 1 John 4:7–12 | Meet one concrete need with love. |
| 10 | Justice | Isaiah 58:6–12 | Amos 5:21–24; Matthew 25:31–40 | Correct one unfairness within reach. |
| 11 | Faith | Hebrews 11:1–16 | Mark 9:14–29; James 2:14–26 | Act on one truth entrusted to you. |
| 12 | Bearing fruit | John 15:1–17 | Galatians 5:22–25; Matthew 7:15–20 | Plant something good in the garden today. |
| 13 | Helping others spiritually | 2 Timothy 2:1–7 | Matthew 28:16–20; James 5:19–20 | Encourage one person toward a faithful next step. |

The reading screen shows only the requested verse range, its RSVCE provenance, a short reviewed meditation prompt, optional Stillness or Flowing water sound, and a single **Complete this meditation** action. Completion advances the next Today card but never locks previous readings.

## Reliable Memories and Altar discovery

Saving a Memory returns the created `Encounter` and immediately opens `/remember/:memoryId`. The saved page shows the written content, playable voice recording, Altar state, and a clear route back to Remember. The save button shows progress and prevents double submission. A save error stays on the form with the recording intact and gives a readable retry message.

Remember adds clear All, Altar, and Voice filters. The newest Memory is visible first. An Altar Memory appears in the Altar filter and in Today’s **At your Altar** section. Prayer rituals and Memories may coexist there; neither silently replaces the other.

The audio repair configures real media-player mode and an explicit speech/media audio context for both recording review and saved playback. Existing private-file checks remain in place. Playback errors remain visible and retryable.

## Memory soundscape

Voice is always recorded and stored clean. Sound is layered locally during review and playback so it can be changed, reduced, or turned off later. SoulBuddy reuses the audited Stillness and Flowing water assets, defaults to Quiet, caps the bed at 35%, and starts a selected bed at 15%. The voice remains foreground audio. Stopping, changing Memory, leaving the screen, or reaching the end stops the bed.

The selected bed and volume are stored as device-local playback preferences for that audio asset. They do not alter, upload, or duplicate the private recording.

## Acceptance criteria

1. No compact orientation surface says Course; each says Nugget.
2. Today opens the first unfinished Nugget until all eight are complete, then opens the next Scripture stage.
3. The full corrected course is readable/listenable, synchronized, speed-adjustable, replayable, and optional.
4. Previous and Next remain available inside Nugget and formation readers.
5. Saving a voice Memory immediately opens the saved Memory and playback works on the connected Android device.
6. Marking a Memory as Altar makes it discoverable in Remember and Today.
7. Quiet, Stillness, and Flowing water are available for Memory review/playback; the clean recording is preserved.
8. Scripture text comes from the bundled RSVCE source and only the curated verse range is shown.
9. Formation responses are optional, editable, and use reviewed or user-authored spiritual content.
10. The flow works offline, at large text sizes, with reduced motion, and after app restart.
