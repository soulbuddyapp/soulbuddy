# SoulBuddy Prayer Refrains and Voice Tablets Design

**Date:** 2026-08-26

**Status:** Approved direction; written specification awaiting final user review

**Platforms:** Flutter Android, iOS, and web; Laravel API

**Extends:** `2026-08-11-guided-prayer-personalization-ai-design.md`, `2026-08-12-sensory-feedback-daily-remembrance-design.md`, and `2026-08-13-covenant-grace-visual-audio-design.md`

## Purpose

Make a person's own voice a practical aid to prayer, remembrance, meditation, and faithful daily return. A saved prayer can become a **Voice Tablet**: a private recording of the prayer, an optional short **Prayer Refrain**, an optional subtle sound bed, and a reminder or daily Altar ritual.

SoulBuddy helps the person form words that are truthful, healing, hopeful, repentant, thankful, and grounded in the Gospel, then remember and pray those words. The recording does not create grace, certify healing, manufacture a covenant, or make repetition spiritually powerful. A personal promise or covenant before God remains serious and personal. The app only helps the person preserve and return to what they have freely chosen to pray or remember.

## Considered approaches

### Platform-aware refrain and full prayer — selected

A user may record a full prayer of ordinary spoken length and, separately, a reminder-ready refrain of at most 25 seconds. At reminder time, the short refrain may serve as the notification sound where the platform reliably permits it. Opening the reminder begins the full Voice Tablet and optional sound bed when the user has enabled that behavior and the audio route is appropriate.

This approach provides useful automatic playback without promising behavior that operating systems and browsers do not guarantee.

### Alarm-style unattended full playback — rejected

Android foreground services and alarm-like presentation could force longer playback in some conditions, but this would be intrusive, inconsistent with iOS and web, and inappropriate for an ordinary prayer reminder. SoulBuddy will not impersonate a calling or alarm application, bypass Do Not Disturb, or cover other apps with a full-screen prayer surface.

### Playback only after an explicit Play tap — retained as fallback

This is the universal fallback when notification audio, autoplay, the current route, or the user's settings do not permit automatic playback. It remains a complete and respectful experience, but is not the preferred mobile reminder path.

## Product language

The terms are deliberately distinct:

- **Voice Tablet:** the saved prayer audio object. It may contain the full prayer recording, a short Prayer Refrain, and playback settings.
- **Prayer Refrain:** a short line or compact version that the person wants to return to and can record in their own voice. It is not presented as a manifestation formula or a source of spiritual power.
- **Sound bed:** quiet non-verbal ambience under prayer or during silent meditation.
- **Altar ritual:** a chosen recurring practice that brings a Voice Tablet, prayer, Scripture, promise, or memory before the person at a selected time.

The UI may use `Record a Voice Tablet`, `Add a Prayer Refrain`, `Keep on my Altar`, and `Add as a daily ritual`. It avoids `activate`, `manifest`, `raise your vibration`, `unlock a blessing`, `speak this into existence`, and claims that the app establishes a covenant for the user.

## Spiritual guardrails

1. Repetition serves remembrance, attention, persistence, and renewed obedience; no count or duration is said to produce grace or divine favour.
2. The user's voice is never represented as God's voice. App prompts are plainly aids from SoulBuddy, not divine messages.
3. The feature may help a person preserve a promise or personal covenant, but the default flow calls the object a prayer. `Promise` or `Covenant` appears only when the person explicitly classifies it that way.
4. Healing language describes truthful and uplifting communication that may support the soul; it makes no medical or guaranteed spiritual-outcome claim.
5. Listening does not replace praying, reflecting, obeying, reconciling, serving, seeking appropriate care, or acting on truth.
6. Repeated playback never becomes a streak, score, level, badge, public count, or measure of faithfulness.

## Voice Tablet creation

### Entry points

A Voice Tablet can be created from:

- a saved personal prayer;
- a library prayer saved privately by the user;
- the completed personalized-prayer flow; or
- an existing Voice Tablet's `Record again` action.

The primary prayer action is `Record in my voice`. Generated TTS remains available as a separate private narration choice and is never labelled as the user's voice.

### Recording flow

1. Show the exact immutable prayer revision being recorded.
2. Request microphone permission just in time.
3. Let the user record, pause, resume, stop, discard, and record again.
4. Keep the prayer text readable with an optional larger, paced reading view.
5. Review the recording with play, pause, seek, duration, and an editable neutral title.
6. Offer `Add a short refrain` after the full recording is safely retained. The refrain is optional and capped at 25 seconds.
7. Offer sound-bed preview and volume balance. `Voice only` is the default.
8. Offer reminder and `Keep on my Altar` actions after save.

The initial full-prayer limit is 15 minutes, consistent with existing private voice memories. Recording never starts automatically. A source prayer revision remains immutable; rerecording creates a new Voice Tablet revision and does not rewrite the prayer or destroy the earlier take until the replacement is committed.

### Prayer Refrain choices

The user may:

- record a short direct prayer to God;
- record a line selected from the saved prayer;
- record a Scripture-grounded declaration; or
- skip the refrain and use SoulBuddy's ordinary reminder cue.

SoulBuddy may offer a few tap-to-select structural suggestions such as `A line of surrender`, `A promise I want to remember`, `A request for grace`, or `A word of thanksgiving`. It does not invent a divine promise, diagnose the person's spirit, or suggest that frequent repetition compels an outcome.

## Altar rituals

### Relationship to the existing Altar

An Altar currently marks encounters that the person deliberately wants to revisit. That meaning remains intact. An **Altar item** is something kept in remembrance; an **Altar ritual** is the recurring way the person returns to it.

Encounter records continue to use their existing `is_altar` flag. Voice Tablets and prayers use a typed Altar-item relationship rather than pretending to be encounters. Ritual scheduling is stored separately so the same item can remain on the Altar while its schedule is paused, changed, or removed.

### Adding the daily ritual

From a saved Voice Tablet, `Keep on my Altar` opens a compact sheet with:

- `Daily` selected by default, with optional selected weekdays;
- one local time;
- playback choice: `Refrain`, `Full prayer`, or `Open quietly`;
- sound choice: `Voice only`, `Sound only`, or `Voice + sound`;
- optional meditation length for in-app playback: 3, 5, 10, or 20 minutes;
- reminder actions: `Open`, `I prayed`, and `Later`.

The routine can be saved with no system reminder. In that case it appears in the day's Altar section and remains fully offline.

### Today and Altar presentation

Today includes one compact **At your Altar** section inside the existing Pray–Act–Remember flow. It shows only the next due ritual or the currently chosen ritual, not a dashboard of every saved object.

The card contains:

- ritual title and scheduled time;
- a small incised waveform derived from the actual recording;
- `Listen` as the primary action when due;
- `I prayed` as an explicit confirmation;
- `Later` and a restrained overflow menu for pause, edit, or remove.

If no ritual exists, the empty state remains above the fold: `Keep a prayer or memory before you.` and `Add to my Altar`. It does not use sales copy, generic wellness claims, or a large decorative panel.

The Covenant Slabs continue to summarize only the factual Pray, Act, and Remember categories. An Altar ritual confirmation can satisfy the day's Pray fact when it is tied to a prayer, but it does not create a fourth progress category or permanent collection of completed tablets.

### Completion and history

- Audio delivery, audio start, or audio completion never marks a prayer as prayed.
- Only `I prayed` creates the normal immutable prayer-session record for the exact prayer revision.
- The person may confirm from the notification action, compact in-app overlay, Voice Tablet player, or Today.
- Refrain repeats within one meditation session do not create multiple prayer sessions.
- Undo uses the existing five-minute retraction behavior.
- The user may see a factual dated history privately, but there is no streak, missed-day state, public activity, or repeated-play count.

## Meditation modes

The player supports three restrained modes:

1. **Voice only:** play the user's full recording or short refrain once.
2. **Voice + stillness:** play the chosen voice over a low sound bed; the sound bed fades in, ducks under speech, and fades out.
3. **Quiet meditation:** play only the selected sound bed with optional minimal prompts.

For a time-limited session, the user may enable `Repeat my refrain`. The refrain repeats with a calm configurable pause rather than displaying or targeting a repetition count. The default gap is 30 seconds. Stop, pause, and volume controls are always visible. Removing headphones, losing the audio route, receiving a call, or starting another media session pauses or stops playback safely.

Optional prompts are short and infrequent:

- `Be still.`
- `Remember what God has done.`
- `Speak this prayer slowly.`
- `Remain with these words.`
- `Carry this into your next action.`

Prompts are selectable and off by default. They are displayed as SoulBuddy guidance and are not narrated in a voice that might be mistaken for God speaking.

## Reminder playback matrix

### Android

- Use an ordinary actionable local notification, never a full-screen intent.
- The app attempts short recorded-refrain notification audio only when a stable local sound URI/channel strategy is supported and verified on the device/API level.
- Android notification channels are persistent and their sound becomes user-controlled after channel creation. A failed or unsupported custom-refrain path falls back to the selected SoulBuddy cue without silently creating large numbers of channels.
- When the app is visibly active, the compact due overlay may begin the chosen playback after the user has explicitly enabled reminder autoplay and an appropriate audio route is available.

### iOS

- Copy the finalized reminder refrain into the app container's `Library/Sounds` location in a supported alert format before scheduling.
- Cap the refrain at 25 seconds, below Apple's 30-second custom-alert limit.
- Missing, invalid, or unavailable audio falls back to the ordinary notification cue.
- Focus, silent mode, notification permission, and the user's system settings remain authoritative.

### Web

- Web notifications do not promise recorded audio playback.
- Opening the reminder presents the compact player. Audible autoplay is attempted only after a qualifying prior/user interaction and must expose a clear Play fallback when the browser rejects it.
- The ritual and all local playback remain usable without Web Push.

### Common rules

- The reminder text remains privacy-safe and does not expose prayer content on the lock screen by default.
- Playback respects the app's sound setting, route checks, media interruptions, system volume, and platform notification settings.
- SoulBuddy never bypasses silent mode, Focus, Do Not Disturb, or operating-system restrictions.
- The reminder must still arrive and remain actionable if its audio asset is missing.

## Sound-bed library

The first release contains only three subtle, offline-ready options:

1. **Stillness:** an original, procedurally generated warm noise bed. SoulBuddy owns the source recipe and rendered master.
2. **Gentle Rain:** a softened seamless adaptation of the CC0 Freesound recording `Rainfall` by colorsCrimsonTears: <https://freesound.org/people/colorsCrimsonTears/sounds/532681/>.
3. **Flowing Water:** a softened seamless adaptation of the CC0 Freesound recording `Gentle Stream` by EvilDavo: <https://freesound.org/people/EvilDavo/sounds/507155/>.

Before an external asset enters the repository it must be auditioned on phone speaker, wired/Bluetooth headphones, and a quiet room; checked for speech, voices, birds, thunder, sudden transients, clipping, obvious loop seams, excessive stereo motion, and distracting tonal peaks; normalized conservatively; crossfaded; and encoded to a practical offline mobile format.

No bells, choirs, chants, subliminal material, binaural-beat claims, named frequencies, or `healing frequency` marketing are included in the core pack. Sound beds are aids to attention, not treatments.

Freesound's licence guidance distinguishes CC0, attribution, and noncommercial assets: <https://freesound.org/help/faq/>. The app ships only reviewed CC0 or original masters in this slice. Each asset receives a manifest record containing source page, creator, displayed licence, download date, original filename, source checksum, edit recipe, final checksum, duration, loudness, and reviewer. Attribution remains visible in About even where CC0 does not require it.

Pixabay is not used for the core pack because its licence prohibits standalone redistribution and introduces a less direct boundary for embedded sound assets: <https://pixabay.com/service/license-summary/>.

## Audio mixing and quality

- Voice is always intelligible over the sound bed.
- Default sound-bed gain is approximately 15% of the voice level and is user-adjustable independently.
- Apply a short fade-in/fade-out and duck the sound bed while voice is active.
- Loop boundaries use equal-power crossfades and are tested with headphones.
- Never normalize a user's private recording destructively. Playback may apply non-destructive gain management, limiting, and route-aware volume protection.
- The player starts at a moderate application gain and never raises the system volume.
- Haptics mark explicit user controls only; they do not pulse with the refrain or ambient loop.

## Data model

New synchronized metadata uses immutable identifiers and existing ownership/sync conventions:

- `voice_tablets`: owner, source prayer/reference and exact revision, title, current audio revision, optional current refrain revision, created/updated/archive timestamps.
- `voice_tablet_revisions`: immutable recording metadata, duration, MIME type, local asset identity, waveform summary, and replacement lineage.
- `altar_items`: owner, typed target (`encounter`, `prayer`, `voice_tablet`, or later `scripture`), target identity, created/archive timestamps.
- `altar_rituals`: owner, altar item, timezone identifier, local time, weekdays, enabled/paused state, playback mode, sound-bed key, meditation duration, refrain-repeat gap, reminder/autoplay choices, and revision timestamps.
- `altar_ritual_occurrences`: deterministic local date, due instant, status, notification identity, prayer-session link when confirmed, and retraction metadata.

Large user audio bytes remain device-local in this slice, matching the existing voice-memory privacy model. Metadata sync does not imply cross-device audio availability. If a ritual syncs to a device without its recording, the UI states `Recording is on another device` and offers prayer text or TTS only after the user explicitly chooses an available alternative.

Bundled sound beds are versioned assets, not database blobs. Notification-ready derivatives are private local files and are deleted when no active scheduled occurrence references them.

## Architecture

The implementation extends existing abstractions rather than creating a parallel audio system:

- `AudioRecorder` and `AudioAssetStore` capture and retain full recordings and refrains.
- `VoiceTabletRepository` owns immutable metadata and local asset references.
- `AltarRepository` projects typed saved items without changing existing encounter semantics.
- `AltarRitualRepository` owns schedules and factual occurrences.
- `PrayerReminderCoordinator` gains capability-aware short-refrain preparation and schedules ordinary fallback notifications when preparation fails.
- `MeditationPlaybackCoordinator` is the single-active-session mixer for voice, sound bed, prompts, interruption, route changes, and lifecycle.
- `PrayerNarrationPlaybackPolicy` remains responsible for TTS consent and safe playback; a user recording never goes to Deepgram or DeepSeek.
- Laravel validates owned references, revisions, ritual schedules, and sync mutations. It does not receive or synthesize user-recorded voice in this slice.

The reminder scheduler records the exact referenced prayer/Voice Tablet revision. Edits create a new schedule revision and reschedule future occurrences without rewriting history.

## Privacy and safety

- User recordings are private and local-first.
- Microphone permission is requested only when the person presses Record.
- Recordings are never used for voice cloning, transcription, model training, prayer generation, analytics, or Circle sharing.
- Notification copy is generic by default; the person's spoken words do not appear as notification text.
- The user explicitly enables recorded reminder audio and sees that people nearby may hear it.
- Delete is recoverable at the metadata level where possible, but explicit permanent audio deletion clearly states that the local recording cannot be recovered from SoulBuddy.
- Export, publishing, cross-device encrypted audio, Circle audio, and cloud backup are separate future decisions.

## Accessibility

- Recording, playback, seek, reminder actions, and sound controls meet 48×48 logical-pixel targets.
- The waveform is supplemental and hidden from screen readers; title, duration, state, and current position are announced textually.
- The player works with screen readers, keyboard controls, reduced motion, high contrast, 200% text, and mono audio.
- Prompts are available as text even when narration is disabled.
- The app remembers caption/prompt visibility, not private session content.
- An active reminder overlay never traps focus or blocks emergency/device controls.

## Failure handling

- **Permission denied:** retain the prayer and offer TTS or text-only ritual setup.
- **Recording interrupted:** retain the last safely finalized portion and ask the user to keep, rerecord, or discard it.
- **Notification derivative unavailable:** schedule the ordinary cue; do not drop the reminder.
- **Custom sound rejected by the OS:** show the standard reminder and make Play immediately available on open.
- **Autoplay rejected:** leave the player ready with one clear Play action.
- **Bluetooth or headphone route lost:** pause voice playback and require a deliberate resume unless the user previously enabled speaker fallback.
- **Sound asset corrupt/missing:** continue voice-only or silence-only meditation and offer repair on the next online opportunity.
- **Storage full:** preserve metadata and prayer text, do not claim the recording was saved, and offer retry or cleanup guidance.
- **Timezone/DST change:** preserve the selected local wall time and deterministically reschedule future occurrences using the existing reminder rules.

## Verification and acceptance

### Domain and repository tests

- Immutable Voice Tablet and refrain revision creation, replacement, archival, ownership, and orphan cleanup.
- Typed Altar items without target collisions.
- Daily and selected-weekday schedule calculation across timezone and DST changes.
- Deterministic ritual occurrence identity, confirmation, undo, pause, reschedule, and sync replay.
- Missing-local-audio behavior after metadata sync.

### Audio tests

- Real microphone capture, pause/resume, interruption, save, rerecord, reopen, play, and permanent delete on Android device and emulator.
- Full prayer plus optional sound-bed mixing, gain ducking, fade, repeat gap, route loss, and single-active-session enforcement.
- Every bundled sound passes asset-manifest, checksum, duration, loudness, loop-seam, and licence-provenance checks.
- Notification derivatives remain under 25 seconds and use platform-supported formats.

### Reminder tests

- Android API/device matrix verifies capability detection, channel stability, ordinary fallback, actions, lock-screen privacy, reboot rescheduling, and no full-screen intent.
- iOS integration verifies `Library/Sounds` preparation, under-30-second delivery, missing-file fallback, and settings-controlled silence.
- Chrome verifies notification/open behavior, rejected autoplay fallback, persistent local audio storage, and offline ritual use.
- Playback never creates a prayer session; only `I prayed` does.

### UI and accessibility tests

- Create a Voice Tablet from every supported prayer entry point.
- Add, edit, pause, remove, and complete a daily Altar ritual.
- Today shows only the next/current Altar ritual and remains usable above the fold on the supported compact phone shell.
- Empty, due, playing, completed, missing-audio, permission-denied, and offline states work at normal and 200% text.
- Screen-reader labels distinguish `Listen`, `I prayed`, `Later`, recording state, sound choice, and reminder behavior.

## Explicit non-goals

- No claim that repetition causes spiritual power, healing, prosperity, grace, or answered prayer.
- No casual default covenant ceremony or wording that the app establishes a covenant with God.
- No voice cloning, speech imitation, automatic transcription, AI interpretation of recordings, or upload to an AI provider.
- No full-screen prayer alarm, bypass of silent/DND settings, hidden playback, or background recording.
- No public Voice Tablets, Circle audio, cloud audio backup, or cross-device user-recording delivery in this slice.
- No streaks, repetition counts, goals based on number of plays, missed-day penalties, spiritual score, or celebratory gamification.
- No large meditation marketplace or unsupported health claims.

## Acceptance summary

This slice is accepted when a person can privately turn a saved prayer into a Voice Tablet, optionally record a short Prayer Refrain, combine it with one restrained offline sound bed, place it on their Altar as a daily ritual, receive a capable but respectful reminder, meditate or pray with it offline, and explicitly confirm `I prayed`. The behavior must remain truthful across Android, iOS, and web; preserve the app's spiritual framework; and never confuse playback, repetition, or app usage with grace, covenant, holiness, or spiritual achievement.

## Platform references

- Apple custom notification sounds: <https://developer.apple.com/documentation/usernotifications/unnotificationsound>
- Android notification channels and custom sound behavior: <https://developer.android.com/reference/android/app/NotificationChannel>
- Android full-screen notification restrictions: <https://developer.android.com/reference/android/app/Notification.Builder#setFullScreenIntent(android.app.PendingIntent,boolean)>
- Chrome autoplay policy: <https://developer.chrome.com/blog/autoplay/>
- WebKit autoplay guidance: <https://webkit.org/blog/7734/auto-play-policy-changes-for-macos/>
