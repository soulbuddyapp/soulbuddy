# SoulBuddy Covenant and Grace Visual and Audio Design

**Date:** 2026-08-13  
**Status:** Approved direction; written specification awaiting final user review  
**Platforms:** Flutter Android, iOS, and web  
**Supersedes:** `2026-08-12-living-vine-visual-language-design.md` and `2026-08-12-signature-illustration-design.md`

## Purpose

Replace SoulBuddy's decorative botanical language with one memorable, sacred, and useful visual system. The new system is called **Covenant and Grace**. It uses a pair of naturally cut stone tablets, light, inscription, and sound to help a person understand the daily movement of prayer, obedient action, and remembrance.

This work also makes audio a first-class way to record a spiritual encounter, promise, surrender, revelation, Scripture, person, family memory, lesson, or testimony. Speaking and writing are equal capture methods; audio is not a small attachment hidden inside a text form.

The design must continue to express that SoulBuddy is a humble aid to a personal relationship with God. It helps a person attend, record, remember, and respond. It does not measure holiness, mediate grace, certify revelation, or turn obedience into entertainment.

## Considered directions

### Covenant and Grace — selected

Two naturally split limestone tablets receive light and restrained inscriptions. This direction is recognizably sacred, connects remembrance with covenant, and gives Today a meaningful animation without implying that a user is dying or building a score.

### Illuminated journal — not selected as the central metaphor

An open page, ribbon, and handwritten marks make recording easy to understand, but the direction reads primarily as journaling and does not carry covenant, obedience, or shared prayer strongly enough. Page and inscription details may support forms and records, but they are not the signature image.

### Sanctuary architecture — not selected

Arches, windows, and shafts of light can feel sacred, but repeated church-like architecture would make the experience more denominationally specific and decorative. Light remains part of the selected system without architectural scenery.

## Theological and product grammar

- **Light:** grace, guidance, and God's prior action. The light is present before any daily mark appears.
- **Paired tablets:** covenant, truth received, promises, and what should be preserved in memory.
- **Inscription:** a person's concrete response in prayer, obedience, or remembrance. It records an action; it does not earn grace.
- **Natural stone:** weight, durability, and sacred seriousness. It must not resemble a polished app icon or a grave marker.
- **An unfinished mark:** an available practice, not spiritual failure.
- **A completed mark:** a factual practice completed on the displayed local date, not spiritual worth or divine approval.
- **A spoken line becoming an inscription:** a living memory preserved through audio.
- **Several illuminated marks together:** private shared prayer in Circles, without audience size, popularity, or comparison.

The core movement is:

```text
GRACE IS GIVEN
      ↓
TRUTH IS RECEIVED AND REMEMBERED
      ↓
THE PERSON RESPONDS IN PRAYER AND OBEDIENCE
```

## Tablet art direction

The signature object is a pair of regular, naturally split limestone slabs.

- The slabs have flat or subtly uneven natural edges. They do not have rounded tops, rounded rectangles, pill silhouettes, or exaggerated cartoon chips.
- The pair rests on a warm surface and is seen from a shallow three-quarter or slightly overhead angle. It never stands alone vertically like a headstone.
- The two-slab arrangement should make the Mosaic covenant reference legible without copying a film prop or presenting a numbered reproduction of the Ten Commandments.
- Surface treatment uses restrained grain, shallow incisions, slight tonal variation, and believable weight. It avoids photorealistic rubble, cracks suggesting destruction, glossy 3D rendering, or fake antiquity.
- Inscribed marks are abstract horizontal strokes or simple approved symbols. There is no fake Hebrew, pseudo-Scripture, Roman numerals, lightning, fire, halos, wings, or ornamental religious clip art.
- A quiet field of warm light already falls across the slabs in the zero-completion state. Grace is therefore never pictured as a reward unlocked by use.
- The illustration is code-native vector painting so it scales, animates, adapts to themes, and avoids a network dependency. A subtle bundled texture may be used only if it remains small, licensed, and nonessential.

The component is named for its function, for example `CovenantSlabs`, rather than exposing a generic progress-ring API. It accepts semantic states for Pray, Act, and Remember and owns the visual mapping internally.

## Daily completion animation

The tablets provide a quiet visualization of today's completed practices. They are not a growth chart and do not persist a cumulative spiritual score.

### States

1. **Beginning:** the paired slabs and prior light are visible; three faint inscription beds indicate Pray, Act, and Remember.
2. **Prayer recorded:** the Pray inscription is revealed with a shallow engraved-line animation.
3. **Practical action completed:** the Act inscription is revealed.
4. **Daily remembrance completed:** the Remember inscription is revealed.
5. **All available practices completed:** light moves once across the existing inscriptions and then becomes still.

Every state is accompanied by a textual status such as `Prayer recorded` or `2 of 3 practices completed`. Color and imagery are never the sole carriers of meaning. If a practice is not available that day, it is shown as unavailable and excluded from the denominator; it is not shown as failed.

### Data rules

- The visual is a read-only projection of authoritative local records: a non-retracted prayer session for the displayed local date, the selected prayer's practical-action completion, and the daily remembrance occurrence marked remembered.
- No new spiritual-progress ledger, point total, streak, level, or backend score is created.
- The visual follows the date actually rendered on Today. Midnight rollover and delayed writes must not apply to a newly displayed day.
- Undoing a factual completion reverses its inscription without punishment copy or a negative sound.
- A new local day returns to the appropriate factual state for that date. Saved prayers and memories remain intact.

### Motion and sensory feedback

- Each inscription draws once over 280–420 ms with a soft haptic already represented by SoulBuddy's semantic feedback service.
- The all-complete light pass lasts at most 700 ms and uses the existing gentle completion sound only when sounds are enabled.
- No confetti, sparks, coins, bouncing slabs, cracking stone, repeated pulsing, victory copy, or celebration of spiritual superiority is permitted.
- Reduced motion renders the final engraved state immediately and uses a restrained contrast change.
- Motion never blocks navigation or delays the underlying write.

## Visual system

### Color

The palette moves from generic white-and-green cards to warm sacred restraint:

- **Parchment:** the primary light canvas.
- **Ink:** near-black green for text.
- **Limestone:** warm beige and mineral-grey slab tones.
- **Forest:** the existing grounded green, used for primary actions and selected navigation.
- **Covenant gold:** a muted ochre-gold used sparingly for light and meaningful focus.
- **Umber:** inscription and stone-shadow detail.
- **Night:** a deep green-charcoal dark canvas rather than pure black.

All values are semantic design tokens with verified WCAG contrast. Gold is an accent, never body text on a light surface.

### Typography

- A restrained, license-reviewed serif display face gives page titles, selected prayer text, and key remembrance passages a sacred editorial voice.
- The system sans remains the control, navigation, metadata, and long-form utility face.
- Decorative capitals, faux calligraphy, all-caps Scripture styling, and compressed display type are prohibited.
- Headings become smaller and better proportioned than the current oversized mobile titles so useful content remains above the fold.

The implementation plan must choose and license-check one bundled open font; it must not rely on a network font request.

### Surfaces and hierarchy

- Not every section is boxed. Spacing, typography, light, and tonal fields establish grouping before borders do.
- Cards are reserved for distinct interactive objects. Introductory teaching copy does not occupy a large card above the primary task.
- Ordinary controls may keep practical radii, but the tablet silhouette itself is naturally irregular and never rounded.
- Empty states use one focal visual, one short framework-grounded sentence, and one primary action. At normal phone text size the action is visible without scrolling.
- Settings remains available but no longer competes visually with the page title in a large floating circle.

## Screen application

### Today

Today becomes the clearest expression of Covenant and Grace.

- The header remains `Today` with `Pray. Act. Remember.` as its compact orientation.
- The paired tablets occupy one intentional focal region rather than a small image inside a large generic card.
- The three inscription states map directly to Pray, Act, and Remember.
- A new user sees the already illuminated blank tablets, one short sentence grounded in the framework, and `Choose a prayer` as the primary action. `Record something` is a quiet secondary action. Both fit above the bottom navigation without scrolling at normal text scale.
- Once content exists, the selected prayer, practical action, and daily remembrance are presented as a single ordered daily flow. The page does not become a dashboard.

### Prayers

- Remove the oversized botanical introduction card and its unsubstantiated or promotional framing.
- Present `Library` and `Personalized` as the first clear choice, followed by compact purpose and grounding filters.
- Prayer cards emphasize title, purpose, grounding, and a short opening line. Helpful totals remain factual metadata rather than ranking claims.
- A faint inscription treatment may distinguish a prayer selected for Today, but tablet artwork is not repeated on every prayer card.

### Record

- Replace the nine full-width type buttons with two primary capture choices: `Speak` and `Write`.
- Memory types become compact, accessible choices after the capture method is clear. Recent or framework-priority types may appear first, but all working types remain reachable without deceptive `Coming soon` controls.
- The copy changes from the writing-only `Write what happened before it fades` to `Keep what you do not want to forget.`
- Promise and personal-covenant records may use a small paired-tablet mark because the covenant meaning is specific and appropriate there.

### Remember

- Remove the vine and anything resembling a grave or funeral memorial.
- Records appear as living entries with type, date, title, a restrained excerpt, and audio duration when applicable.
- Bookmarks, incised-line dividers, and light may support hierarchy; the full tablet illustration is reserved for the daily focus and covenant-specific records.
- The empty state uses one compact tablet-and-inscription composition, `Record something` as the primary action, and no large blank ornamental region.

### Circles

- Remove intertwined branches.
- Use several small illuminated inscription marks arranged around a shared center to express people carrying prayer together.
- Empty-state copy remains explicit that the current Circle is private and saved on this device.
- Visual density never implies popularity or membership rank.

### Navigation

- Preserve the five top-level destinations while refining active-state color, spacing, and icons.
- Record remains visually central but does not look like a gamified add button.
- At 200% text, labels remain understandable through adaptive layout and semantics rather than clipping.

## Audio recording experience

### Capture model

A memory may contain:

- written text only;
- one audio recording only; or
- one audio recording plus written notes.

The first slice supports one recording per memory. This keeps capture and deletion predictable while satisfying the core need to speak instead of type. Additional clips and automatic transcription are outside this slice.

### Speak flow

1. The user selects `Speak`.
2. SoulBuddy explains in one sentence that microphone access is used only for the recording and requests permission just in time.
3. A focused recording surface shows a large explicit Record control, elapsed time, a real sound-level response, and `Pause`, `Resume`, `Stop`, and `Discard` as state-appropriate controls.
4. The visual sound line is live input feedback. It must not be a fake looping waveform.
5. On stop or recoverable interruption, a review surface provides playback, seek, duration, `Record again`, `Discard`, and `Keep recording`/`Save` as applicable.
6. The user chooses the memory type, date, sensitivity, daily-remembrance preference, optional Altar state, and optional short written note.
7. If no title is entered, SoulBuddy supplies a neutral title such as `Voice memory · 13 Aug` which may be edited.
8. Saving commits metadata and the final audio asset together from the user's perspective. A failed save retains the reviewable temporary recording and offers retry or discard.

The recording limit is 15 minutes. The timer counts upward, gives a quiet notice before the limit, and stops safely at the limit. Recording never begins automatically, continues secretly, or restarts after a permission denial.

### Visual relationship to inscription

- During recording, the live sound level appears as a warm line over a quiet neutral field.
- After save, the line settles into a short engraved waveform mark associated with the record.
- This is a visual metaphor only. The saved waveform thumbnail is derived from real sampled amplitude data and is not used as spiritual progress.
- Reduced motion replaces the settling animation with an immediate static waveform.

### Playback

- Remember cards with audio expose a clear Play control and duration; opening the record provides play, pause, seek, stop, playback position, and an accessible transcript-independent label.
- Only one user recording plays at a time. Playback stops when its owning screen is disposed unless the user explicitly enters a later background-listening feature.
- Prayer narration and user recordings remain separate concepts. A recorded memory is never sent to a TTS or AI provider, and prayer narration settings do not affect it.
- Daily remembrance offers `Listen` when the selected memory has audio, while preserving the user's written notes and dated reflections.

## Audio storage and privacy

- Recording is local-first and usable offline.
- The initial audio asset remains on the device/browser that created it. The UI states `Audio saved on this device` before final save and on the record detail. Cross-device audio synchronization is a later encrypted-media project, not silently implied here.
- Mobile stores finalized recordings in app-private support storage. Web stores recording bytes in private origin storage such as IndexedDB; object URLs are transient playback handles, not durable identifiers.
- A local-only audio metadata table relates the owner, memory, current source revision, storage key, MIME type, duration, byte size, creation time, and sampled waveform summary.
- Mobile uses a broadly supported compressed speech format such as AAC in an M4A container where available. Web uses the supported browser MediaRecorder format, normally Opus in WebM. Playback reads the stored MIME type rather than assuming one format.
- Temporary assets use unique private names. Save finalizes them atomically where the platform permits. Cancelled takes, replaced takes, failed unsaved takes, and explicitly deleted recordings are cleaned up without deleting an unrelated record.
- Archiving a memory does not silently destroy its recording. Permanent audio deletion requires explicit user action and explains that the recording cannot be recovered from SoulBuddy.
- Audio bytes, filenames, waveform data, titles, and sensitive memory text are excluded from logs, analytics, notification content, and AI prompts.

## Failure and lifecycle handling

- **Permission denied:** show a concise explanation and `Open settings` where supported; keep `Write instead` available.
- **Microphone unavailable/in use:** preserve the form and offer retry or writing.
- **Storage full/quota denied:** stop safely, retain a reviewable take when possible, and explain that it cannot be saved until space is available.
- **Call, browser suspension, route change, or app backgrounding:** pause or finalize according to platform guarantees; never pretend recording continued. On return, show exactly what was retained.
- **Playback failure:** keep the memory readable and provide retry; never archive or rewrite it.
- **Unsupported browser:** disable `Speak` with a factual explanation while leaving `Write` fully functional.
- **Crash recovery:** delete abandoned temporary assets on the next safe startup after confirming they are not referenced by committed metadata.

## Accessibility

- The tablets are decorative when adjacent text describes completion. Their semantic summary is concise, for example `Today: prayer and action completed; remembrance available`.
- Completion states always have text and accessible control states; texture, light, and color are supplemental.
- Record, pause, stop, discard, playback, and seek controls meet 48×48 logical-pixel targets and expose role, state, and elapsed-time announcements without announcing every amplitude change.
- Live waveform animation is hidden from screen readers. Recording time is announced at useful intervals or on request, not every second.
- High text scale removes or reduces decorative art before compressing controls. Empty-state primary actions remain visible without scrolling at normal scale.
- Light/dark themes, high contrast, reduced motion, screen readers, keyboard navigation, and web focus visibility are first-class verification targets.

## Architecture boundaries

The implementation should preserve focused units:

- `CovenantSlabs`: code-native visual and state animation; no repository access.
- `DailyPracticeState`: read-only projection of prayer, action, and remembrance facts for one displayed local date.
- `AudioRecorder`: platform capability and lifecycle abstraction.
- `AudioAssetStore`: durable private storage abstraction with mobile and web implementations.
- `MemoryAudioRepository`: transactional metadata relationship and orphan cleanup rules.
- `AudioCaptureController`: permission, recorder states, temporary asset, recovery, and save coordination.
- `MemoryAudioPlayer`: single-active-playback coordination independent of prayer narration.

Screens depend on these interfaces rather than platform plugins directly. The existing encounter repository remains authoritative for the memory and its immutable source revisions; local audio metadata points to the resulting memory/revision without placing large media in the synchronized PowerSync tables.

## Migration and removal

- Remove `LivingVine`, `LivingVineColors`, botanical variants, and every screen integration.
- Remove the bundled olive-tree memorial image and its asset-manifest entry once no code references it.
- Replace the prior Today action-fruit behavior with factual CovenantSlabs inscription states.
- Update tests and semantics that refer to vines, branches, fruit, blossoms, olive trees, or stone memorials.
- Keep historical design files but mark them superseded so the rejected metaphor cannot be reintroduced accidentally.
- Preserve user data, current routes, local database identity, saved prayers, memories, reminders, sessions, and reflections.

## Verification and acceptance

### Visual and interaction verification

- Golden tests cover zero, one, two, and all available daily practices; light/dark themes; compact and wide layouts; normal and 200% text; and reduced motion.
- Widget tests prove textual completion status, non-scroll empty-state primary actions on the supported compact phone shell, and no botanical semantics or assets.
- The visual is inspected on the connected physical Android device using screenshots from Today, Prayers, Record, Remember, and Circles.
- The final Today composition must have an intentional focal region and useful above-fold action, without the large blank lower screen visible in the current build.

### Audio verification

- Unit tests cover recorder state transitions, denial, pause/resume, interruption, limit, discard, retry, atomic save, replacement, and orphan cleanup.
- Repository tests use the real local database for metadata ownership and memory/revision relationships.
- Widget tests cover Speak/Write entry, real busy/disabled states, save recovery, playback, accessibility labels, and 200% text.
- Android emulator and connected-device tests record from the microphone, pause, stop, play, save, reopen the app/database, replay the same asset, surface it in Remember, and delete it explicitly.
- Chrome integration verifies permission-capability handling, a synthetic/test media stream where browser automation permits it, durable origin storage, reopen, and playback. Unsupported automation paths retain deterministic platform-unit coverage rather than weakening production checks.
- Existing offline prayer, reminder, daily remembrance, circles, Laravel, and PowerSync integration suites remain green.

## Explicit non-goals

- No spiritual score, streak, level, rank, public progress, tablet collection, or permanent completion monument.
- No branch, vine, tree, flower, fruit, cairn, grave, funeral memorial, or botanical replacement motif.
- No fake inscription language or reproduced Decalogue text.
- No automatic transcription, AI interpretation, sentiment analysis, or claim that a recording is divinely authoritative.
- No background recording, continuous listening, auto-upload, public audio, or hidden cloud backup.
- No cross-device audio synchronization in this slice.
- No redesign of backend authentication, prayer TTS generation, or Circle networking beyond the visual integration described here.

## Acceptance summary

The slice is accepted when SoulBuddy has one recognizable Covenant and Grace language; natural non-rounded slabs communicate sacred covenant without resembling graves; Today animates factual Pray, Act, and Remember responses without gamification; all rejected botanical assets are gone; new users can act above the fold; and a person can privately speak, review, save, replay, remember, and delete an audio memory on supported mobile and web platforms without being forced to type.
