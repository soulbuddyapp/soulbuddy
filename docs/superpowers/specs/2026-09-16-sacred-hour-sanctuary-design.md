# Sacred Hour Sanctuary

## Purpose

Make an active Sacred Hour feel solemn, focused, and unmistakably separate from
the rest of the app. The experience centres on one truth: **We belong to God.**
Prayer, sound, completion, and reflection remain available without competing
cards, repeated guidance, or overlapping global controls.

## Experience

Opening a Sacred Hour replaces the normal app chrome with a full-screen
sanctuary. A warm ivory background and one golden portal illustration fade in
together. Live text appears over the quiet lower portion of the composition:

- `Sacred Hour`
- `We belong to God.`
- the remaining prayer time in a compact, low-emphasis treatment

The fade runs once on entry and is disabled when reduced motion is requested.
No carousel, stacked cards, floating reminders, or persistent global player may
appear over the sanctuary.

The top edge contains two small 48dp touch targets with visually restrained
glyphs: pause or resume, and exit. The bottom control dock contains:

- `Prayer`, showing the selected prayer name when one is attached;
- `Sound`, showing the selected sound and its play or pause state;
- the single primary action, `I've prayed`.

The controls use live Flutter text and semantics. Raster artwork never supplies
labels or actions.

## Visual assets

Copy these user-provided assets into the app during implementation:

- `artwork/hero-portal-clean.webp` becomes the sanctuary focal image. Preserve
  its aspect ratio and render it within its recommended native scale. On wider
  layouts, increase surrounding space instead of enlarging the bitmap beyond
  its useful resolution.
- `artwork/prayer-scene-fade.webp` appears only in prayer-opening and closing
  setup. It must not compete with the portal during an active Sacred Hour.

The surrounding surfaces use the existing SoulBuddy design system with soft
ivory, restrained marble texture, warm gold highlights, deep diffuse shadows,
and high-contrast live text. Native Flutter surfaces and shadows provide the
control dock and sheets; screenshot fragments and baked labels are excluded.

## Prayer selection and playback

`Prayer` opens a compact picker containing the linked prayer first, followed by
the existing purpose-aware suggestions and `New prayer`. Selection closes the
picker and updates the active Sacred Hour immediately.

When a selected prayer has playable audio on the device, the sanctuary starts
that recording once per selection. It does not restart after widget rebuilds,
route restoration, or background preference changes. If the selected prayer
has no recording, the sanctuary remains silent and keeps the prayer selected.

A single foreground audio coordinator owns prayer playback and the background
sound bed. Starting prayer audio fades the sound bed to a low level, plays the
opening, prayer, and closing sequence, then restores the prior sound-bed level.
Changing the prayer cancels the old sequence before starting the new one.
Leaving the route, opening a full prayer, or opening the reflection composer
stops all sanctuary audio immediately.

## Background sound

`Sound` opens the existing meditation-sound picker in a compact sheet. The
user's last sound and volume remain the default for future Sacred Hours,
readings, and meditation where the shared preference already applies. The
control shows play while silent and pause while playing.

Selecting a sound starts it immediately. Selecting silence stops it. Sound
does not restart automatically merely because a Sacred Hour route rebuilds.

## Prayer openings and closings

Prayer recording gains a reusable ritual profile with one default opening and
one default closing. The initial presets are:

### Opening

- `In Jesus' Name I pray.`
- `In the name of the Father, and of the Son, and of the Holy Spirit.`
- `No opening`
- `My recording`

### Closing

- `Amen.`
- `No closing`
- `My recording`

The Catholic opening is recommended when the prayer grounding is Catholic;
the Christian opening is recommended otherwise. A user's explicit default
always wins over that recommendation.

The recording flow presents three compact steps: `Opening`, `Prayer`, and
`Closing`. Preset text may be retained as live text, while `My recording`
captures a private audio clip using the existing local recording system. The
prayer body continues to use the existing Voice Tablet recording. Opening and
closing clips remain separate so a default can be changed without re-recording
the prayer itself.

The ritual profile is device-local and stores only preset identifiers and
references to private local audio. Missing or unreadable clips are skipped;
prayer playback continues rather than failing the full sequence.

## Completion and meditation

`I've prayed` performs the existing prayer-session and Sacred Hour occurrence
updates, then replaces the prayer controls with the meditation phase inside the
same sanctuary. The page does not add a second completion card or global
check-mark widget.

The meditation phase keeps the approved copy:

- `God speaks to us in meditation`
- `Listen to know if your prayer needs something from you`

Reflection prompts appear one at a time in the bottom dock. Selecting a prompt
opens the write or speak composer immediately with the prompt and local date
already applied. Returning to the sanctuary must not recreate completed prayer
controls or restart prayer audio.

## Overlay and route ownership

The Sacred Hour route owns all controls during the session. While its path is
active, the app shell suppresses:

- the spiritual-session mini-player;
- prayer-reminder overlays;
- altar-reminder overlays;
- any active Sacred Hour overlay rendered by Today.

Those global elements resume after exit when their underlying state is still
relevant. The Android system notification remains active because it provides
lock-screen and background continuity; it is not duplicated inside the route.

The screen-awake wrapper remains active for both prayer and meditation and is
released when the route closes.

## State and component boundaries

`SacredHourSessionScreen` coordinates repositories, route lifecycle, system
notification state, and audio. The visual layout is split into focused units:

- `SacredHourSanctuaryScaffold` owns the full-screen visual shell, animation,
  safe areas, and compact top controls.
- `SacredHourPrayerControls` owns the selected prayer, sound state, remaining
  time, and completion action.
- `SacredHourMeditationControls` owns meditation copy and one-at-a-time prompts.
- `PrayerRitualPreferences` owns opening and closing defaults.
- `PrayerRitualPlaybackCoordinator` serializes opening, prayer audio, closing,
  and sound-bed ducking.

The session controller remains the source of truth for prayer, meditation, and
dismissed phases. It must not own media files or presentation animation.

## Recovery

- Prayer audio unavailable: keep the prayer selected and continue silently.
- Opening or closing audio unavailable: skip that clip and continue playback.
- Background sound unavailable: show the selected sound but leave playback
  stopped; allow another selection.
- Prayer completion fails: remain in prayer phase and keep `I've prayed`
  available.
- Sacred Hour data unavailable: show the existing concise unavailable state
  with an exit action.

Errors must never create a second card over the sanctuary. A brief accessible
message near the bottom dock is sufficient for recoverable audio failures.

## Accessibility and responsive behaviour

- All interactive targets are at least 48dp even when the visible icon is
  smaller.
- Text contrast is measured against the rendered lower-image scrim and ivory
  surfaces.
- TalkBack announces the prayer name, sound name, playback state, remaining
  time, and completion action without describing layout.
- Text scaling up to 200% keeps the primary action reachable and makes the
  lower dock scroll internally if needed.
- Reduced motion replaces the entry fade with an immediate render.
- Landscape and large-screen layouts preserve one focal portal and constrain
  controls to a readable width.

## Verification

Automated coverage must prove:

- global players and reminder overlays are absent on Sacred Hour routes;
- the sanctuary contains one focal image and one primary completion action;
- selected prayer audio starts once and does not restart on rebuild;
- sound-bed ducking, restoration, cancellation, and route-exit cleanup;
- saved opening and closing defaults survive provider recreation;
- Catholic and general-Christian recommendations apply only without an
  explicit default;
- missing ritual clips are skipped without blocking prayer playback;
- `I've prayed` transitions to meditation without duplicate completion UI;
- reduced-motion, large-text, and narrow-screen layouts remain usable.

Targeted widget and unit tests run first, followed by Flutter analysis, the
broader app test suite, an Android build, and installation on the connected
device for visual and lifecycle verification.
