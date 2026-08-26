# SoulBuddy Meditation Scenery Design

## Purpose

SoulBuddy's existing `Pray and remain` experience combines a user's Voice Tablet recording, an optional restrained sound bed, an optional prompt, and a timed session. The running view is currently text-only. This feature adds calm nature photography so a person may use sight as well as sound to settle attention and imagine a peaceful setting while praying.

The scenery is an optional aid to attention. SoulBuddy does not claim that an image, sound, frequency, or landscape produces healing, spiritual power, divine presence, or a particular prayer outcome.

## Scope

The feature extends the existing `Pray and remain` session rather than creating a second meditation system. It is available wherever that session is available, including Voice Tablets created from daily/affirming personalized prayers. The initial slice does not add scenery to ordinary prayer-library cards, prayer drafting, reminders, Today, navigation, or other decorative surfaces.

The session continues to support voice-only, sound with voice, sound without voice, optional repeated Prayer Refrains, optional prompts, and the existing duration choices. Scenery does not alter whether a session is recorded as prayed; only the existing explicit `I prayed` action records that fact.

## Chosen approach

Bundle four license-verified still photographs as compressed WebP assets and render the selected scene edge-to-edge during the running session. Apply an extremely slow pan-and-zoom treatment when motion is allowed. Bundled stills are preferred to remote images or video loops because they remain available offline, add modest package weight, avoid runtime image-download and cache failure, and use less battery and memory than continuous video.

The first scene set is:

1. `Dawn lake` — quiet water and a broad, uncluttered horizon.
2. `Flowing waterfall` — gentle flowing water without people or dramatic danger.
3. `Forest path` — a welcoming, well-lit path with open visual depth.
4. `Mountain meadow` — a spacious landscape without buildings, crowds, or promotional associations.

Images must be realistic photography with restrained color and contrast. Reject images containing recognizable people, faces, text, logos, religious symbols, private property as the focal subject, dangerous terrain, disaster imagery, heavy compositing, or visually aggressive saturation. Nature photography is meditation content only; it does not reinstate the rejected tree, vine, flower, fruit, or botanical brand motifs documented in the Covenant and Grace design.

## Asset requirements and provenance

Each image must have a complete, independently reviewable provenance record before it enters the bundle:

- direct source-page URL;
- creator or originating public institution;
- exact license or public-domain basis;
- retrieval date;
- original filename and dimensions;
- transformation recipe;
- final dimensions, byte size, and SHA-256 checksum.

Prefer public-domain sources or CC0. A permissive source requiring attribution may be used only if the application exposes the required attribution in a durable, discoverable place. A search-results thumbnail, repost, social-media copy, wallpaper aggregator, or page without a verifiable license is not acceptable.

Prepare one portrait-oriented WebP master per scene at 1440 × 1920 pixels. Crop with the primary subject away from the central prayer-text safe area, preserve enough edge content for wide screens, remove metadata, and target 200–400 KB per file without visible banding or blocking. The full initial scenery bundle should remain at or below 1.6 MB. Store the images below `assets/images/meditation/` with an `ASSETS.md` provenance manifest and include the directory in `pubspec.yaml`.

## Domain model and defaults

Add a focused `MeditationScenery` value set containing a stable identifier, user-facing label, asset path, and preferred alignment. Use these exact initial identities and paths:

| Identifier | Label | Asset path |
| --- | --- | --- |
| `dawnLake` | `Dawn lake` | `images/meditation/dawn_lake.webp` |
| `flowingWaterfall` | `Flowing waterfall` | `images/meditation/flowing_waterfall.webp` |
| `forestPath` | `Forest path` | `images/meditation/forest_path.webp` |
| `mountainMeadow` | `Mountain meadow` | `images/meditation/mountain_meadow.webp` |

`MeditationSessionRequest` carries an optional selected scenery independently from `MeditationSoundBed`.

The setup view provides a `Scenery` section with `No scenery` and one choice for each bundled scene. A newly opened setup initially selects `Dawn lake`; scenery choice never silently enables voice or sound. When the user changes the sound bed and has not manually chosen scenery, SoulBuddy selects a calm matching default:

- `Stillness` → `Dawn lake`;
- `Flowing water` → `Flowing waterfall`;
- voice-only → `Dawn lake`.

After the user explicitly selects a scene or `No scenery`, sound-bed changes do not overwrite that choice. No scenery preference is persisted across sessions in this slice; every newly opened setup starts with `Dawn lake`.

## Setup experience

The existing setup remains a modal surface titled `Pray and remain`. Scenery choices use compact image thumbnails with text labels and explicit selected state. The selection is reachable by keyboard and screen reader, does not rely on color, and uses at least the existing 48 logical-pixel minimum target.

To keep the setup compact, show the selected-scene summary in the main form and reveal the four thumbnails plus `No scenery` in a concise selector. Sound, voice, refrain, length, and prompt controls keep their existing behavior. `Begin` remains unavailable only under the existing invalid condition where neither voice nor a sound bed can play; selecting scenery alone does not turn a silent image viewer into a prayer session.

If a scenery asset cannot be decoded during setup, that option is disabled for the current session with the factual label `Image unavailable`. Other scenery options and the audio-only path remain usable.

## Running focus view

After `Begin`, transition within the meditation flow to an edge-to-edge focus view. The chosen image fills the viewport with `BoxFit.cover` and its configured alignment. A restrained dark gradient protects the readability of overlaid content without making the photograph look theatrical.

The focus view contains:

- the selected optional prompt, otherwise the Voice Tablet title;
- an accessible remaining-time value when a sound bed or repeated refrain activates the existing session timer; voice-only sessions continue until `Stop`, as they do now;
- a clear `Stop` control that remains visible and meets the minimum target;
- no navigation chrome, ratings, completion animation, streak, score, or unrelated action.

The text block stays within a centered safe area with verified contrast against the gradient. Wide layouts cap text width while allowing the image to continue edge-to-edge. When `No scenery` is selected, the current quiet surface-based running presentation remains available rather than substituting an unrelated image.

## Motion and accessibility

With motion enabled, animate the photograph once across the full session from scale 1.00 to no more than 1.05 with positional drift of no more than 2% of the viewport. For an untimed voice-only session, run the same transform over ten minutes and hold its final state if the session remains open. The movement must be nearly imperceptible, never loop or snap, and never compete with prayer text. It is decorative and excluded from semantics.

When the platform requests reduced motion, render the final static crop immediately. Image decoding, animation, and layout must not delay audio start. Screen readers receive the selected scene label once, for example `Meditation scenery: dawn lake`; they do not receive changing descriptions of the pan or zoom. Prompt and error announcements keep the existing live-region behavior. Text remains readable at 200% scaling, and decorative scenery yields space before controls or text are clipped.

## Lifecycle and failure handling

Audio remains authoritative for session start and stop. The image is decoded or precached while the setup is visible when practical, but `Begin` must still start the session if image preparation fails. In that case, use the no-scenery surface and announce `Scenery unavailable; prayer audio is continuing.` without stopping or restarting audio.

Stopping, dismissing, navigating away, or disposing the session cancels the session timer, refrain timer, scenery animation, sound bed, and Voice Tablet playback exactly once. The existing sound/voice failure message remains recoverable and does not mark a prayer complete. A missing or corrupt image never crashes the session and never blocks the audio-only experience.

No scenery choice, image decoding event, prayer text, private audio identifier, or asset storage key is sent to analytics or logs.

## Architecture boundaries

- `MeditationScenery` owns stable bundled-scene metadata only and has no Flutter widget or repository dependency.
- A focused scenery selector renders the setup choices and reports a selected value; it does not start audio or timers.
- A focused running view renders the image, overlay, prompt/title, time, and Stop action; it receives session state and owns no repository access.
- `MeditationSessionSheet` continues to coordinate setup state, timers, and callbacks while delegating scenery-specific rendering.
- `MeditationSoundBedPlayer` remains audio-only. Image behavior must not enter the audio player or the private Voice Tablet storage abstractions.

This separation keeps asset metadata, visual rendering, and audio/session lifecycle independently testable.

## Verification

### Unit and widget coverage

- Every scenery has a unique stable identifier, non-empty label, bundled WebP path, and valid alignment.
- Every declared scenery asset exists and is listed in the provenance manifest.
- The total scenery asset bundle is at or below 1.6 MB, and checksums match the manifest.
- Sound-bed defaults map to the intended scenes without overwriting an explicit user selection.
- Selecting `No scenery` preserves the existing running presentation.
- Beginning a session passes the selected scenery in `MeditationSessionRequest` without changing sound, voice, refrain, prompt, volume, or duration values.
- The running view shows the correct prompt/title, remaining time, and Stop action on compact and wide layouts.
- Reduced motion renders a static scene.
- A missing or failed image falls back to the no-scenery surface while audio continues.
- Stop and disposal cancel all timers and audio callbacks once.
- Semantics expose selection state, scene label, remaining time, prompt, and Stop without describing decorative animation.
- Normal and 200% text scales retain readable prayer text and reachable controls.

### Visual and device verification

- Golden coverage includes all four scenes plus no scenery, light and dark app themes, compact phone and wide layouts, normal and 200% text, and reduced motion.
- Manually inspect each final crop on a supported Android phone, Android emulator, and Chrome viewport before release.
- Audition the existing sound beds while viewing their mapped scenes to reject combinations that feel abrupt, visually busy, or misleading.
- Verify airplane-mode operation after a clean installation; all scenery and sound beds must remain available.

## Explicit non-goals

- No video loops, animated GIFs, live wallpapers, generative imagery, or remote image feed.
- No user-uploaded scenery or downloadable scenery packs.
- No persisted favorite scene, per-prayer scene assignment, synchronization, or backend schema.
- No scenery on navigation, library cards, Today, reminders, or other ordinary app surfaces.
- No automatic claim that viewing a scene constitutes prayer or meditation completion.
- No health, frequency, manifestation, visualization-success, or spiritual-effect claims.

## Acceptance summary

The feature is complete when a person can choose one of four calm, fully licensed offline nature scenes—or no scenery—while setting up `Pray and remain`; begin an edge-to-edge, readable, accessible focus session with subtle or reduced motion; continue using all existing voice, sound, prompt, refrain, duration, and Stop behavior; and recover automatically to the audio-only presentation if an image is unavailable.
