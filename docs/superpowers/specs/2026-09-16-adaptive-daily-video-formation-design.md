# Adaptive daily video formation

## Outcome

After the eight orientation Nuggets, SoulBuddy offers one carefully curated Christian formation video each day. The experience preserves a coherent foundation while adapting future recommendations to choices the user explicitly makes: spiritual priorities, available time, reminder time, presentation preference, source preferences, and any voluntarily selected struggle track.

The 70-day workbook is the editorial source. Production clients consume validated, versioned records from SoulBuddy's API with a bundled offline snapshot. Completed history survives every configuration change. An unresolved recommendation remains active until the user finishes it, replaces it, or explicitly skips it.

## Product boundaries

- Orientation remains the first formation experience and retains its existing progress, replay, synchronized transcript, speed, and accessibility behavior.
- Daily video formation begins after orientation. It does not replace Daily Scripture, meditation, Sacred Hours, Goals, or Remember.
- Today presents the current video formation invitation after orientation. Scripture, prayer, reflection, and one practical action support the video without becoming additional completion requirements.
- A YouTube click records intent only. SoulBuddy never treats opening an external video as proof of completion.
- Only an explicit **Finished** response advances the canonical progression pointer.
- Spiritual progress is never expressed as holiness, moral worth, or a shame-based streak.
- Sensitive personalization uses only a struggle the user explicitly selects. Browsing, clicks, prayer, journal, Memory, or search content never infer a struggle.

## Editorial source and copy corrections

`C:\Users\Son\Downloads\SoulBuddy_Daily_Video_Progression_v3.xlsx` contains:

- 45 production-ready videos with exact YouTube watch IDs and verified runtimes, including the user-selected BibleProject Beatitudes visual commentary (`W9fR7sHw9Y8`, 10:23);
- ten seven-day formation packs and a 70-day canonical path;
- primary and alternative videos for every day;
- recommendation and recovery rules;
- completion reminder timing;
- user-state and event-schema proposals;
- candidate, excluded, source, discovery-coverage, and QA sheets.

The import pipeline must reject a production video when its exact watch URL is missing, its runtime is unknown or exceeds 630 seconds, its status is not production-ready, or a referenced catalog ID does not exist. Same-day options must be distinct. Every daily record must have a pack, objective, Scripture reference, reflection, practical action, and completion rule.

Before the first import:

- rename the first pack **A Plentiful Harvest**;
- replace the legacy compulsory-harvest wording with **Aim for a plentiful harvest** or context-specific positive planting language;
- preserve **Plant something good in the garden each day** as the daily invitation;
- repair Unicode replacement characters (`U+FFFD`) into the intended apostrophe, quotation mark, dash, or accented character;
- retain theological-lens and sensitive-topic labels as editorial metadata, not promotional copy.

The original workbook remains an editorial artifact. A deterministic importer produces a reviewed JSON snapshot and database seed. The importer emits a manifest with source checksum, catalog version, import time, record counts, warnings, and validation result. Import failure leaves the prior production catalog active.

## Learning-path model

The system uses a core path with adaptive tracks.

1. **Foundation.** The first pack establishes identity, repentance, grace, the Holy Spirit, discipline, and fruitful action. It remains first unless the user resumes an older migrated position.
2. **Adaptive pack queue.** Remaining packs are ordered from the user's explicit priorities. Unselected packs retain the workbook's editorial order after selected priorities.
3. **Daily resolution.** The engine resolves the current pack and day, then chooses the canonical video or up to two compatible alternatives.
4. **Maintenance.** After the 70-day path, the user may repeat a weakly completed pack, choose a virtue track, or begin a 30-day maintenance rhythm. History is retained.

Changing configuration recalculates only future pack order and future recommendations. It does not:

- remove completion events;
- rewrite dates or videos already completed;
- change the current unresolved recommendation without an explicit Replace action;
- advance or reset the canonical day;
- create duplicate daily recommendations for the same local date.

Pack priority choices map to the workbook tracks:

| User priority | Packs promoted |
|---|---|
| Freedom from sin | Understanding Sin & Repentance, then an explicitly selected struggle pack |
| Prayer and the Holy Spirit | Growing Spiritually: Spirit & Prayer |
| Discipline and consistency | Defeating Laziness / Building Discipline |
| Humility and gratitude | Defeating Pride & Envy |
| Forgiveness and patience | Defeating Anger & Unforgiveness |
| Generosity and justice | Defeating Greed / Learning Generosity, then Virtue Formation |
| Character and virtue | Virtue Formation / Christlike Character |
| Service and purpose | Bearing Fruit / Service & Mission |
| A balanced path | Original editorial order |

The explicit lust/purity track is opt-in, age-appropriate, and never named in notification text.

## Configuration

The user may change configuration during initial Daily Formation setup or later from Formation settings:

- formation priorities, ordered or equally weighted;
- local reminder time and enabled state;
- daily time budget from 2 to 10 minutes 30 seconds;
- presentation preference: **Choose for me**, **One video**, or **Three choices**;
- content-source preference: broad Christian, Catholic-inclusive, or no preference;
- sensitive struggle track, optional and explicit;
- completion check-in notifications, independently enabled.

**Choose for me** follows the rules engine. **One video** suppresses optional alternatives unless recovery requires a choice. **Three choices** shows the canonical option plus two eligible alternatives. A strict time budget excludes longer media. If no video fits, SoulBuddy offers the shortest eligible same-objective video and clearly shows its duration; it never silently violates the configured budget.

## Recommendation rules

Rules are deterministic, versioned, and store the rule ID used for each recommendation.

Priority order:

1. Preserve an unresolved clicked or partially watched recommendation.
2. Respond to an explicitly logged struggle with a targeted option, a hope/repentance option, and a practical virtue replacement.
3. After two unresolved days, offer the shortest same-theme option, the canonical option, and a familiar reinforcement.
4. Honor an explicit request for three choices.
5. Offer three choices on the first day of a new pack.
6. Otherwise show the canonical next video.
7. Avoid a video completed within the prior 14 days when an equally suitable alternative exists.
8. Permit deliberate repetition when all suitable options were recently watched.
9. Honor the configured time budget before source variety or novelty.

Every option must be production-ready, within the global 630-second ceiling, compatible with the current objective, allowed by the user's source settings, and appropriate for any sensitive-content constraints.

## Daily experience

### Today

The formation card is compact and visually consistent with SoulBuddy's ivory, warm-gold, raised-card system. It shows:

- the formation focus and pack;
- video artwork or verified thumbnail;
- title, creator, and runtime;
- canonical progress such as `Day 12 of 70`;
- **Watch today**;
- **Choose another** when alternatives are available;
- a quiet settings action.

Copy states purpose and condition directly. It does not explain the interface or narrate storage, navigation, or creation.

### Watching

SoulBuddy opens the exact YouTube watch URL. The app records `video_clicked`, schedules a completion check-in for runtime plus five minutes, and keeps the recommendation unresolved. Returning immediately shows **Watching** and the pending check-in time rather than claiming completion.

### Completion check-in

The system notification and next app foreground offer:

- **Finished** — idempotently records completion and advances once;
- **Watched some** — records partial progress and offers Resume or a shorter alternative;
- **Not yet** — leaves the recommendation active;
- **Skip** — records the skip and offers another eligible option without automatic advancement.

After **Finished**, one optional reflection and one practical action appear. The reflection may open Remember with the day's prompt. The action may become a Goal action through the existing editable practice flow. Neither is required to advance video formation.

### Recovery

An unresolved recommendation is shown at the next daily window with Retry, Shorter option, and Choose another. Follow-up notifications are capped at the first check-in and one soft reminder. Notification copy remains generic and never exposes a sensitive track on the lock screen.

## Data architecture

### Editorial records

- `formation_catalog_versions`: version, source checksum, published state, timestamps.
- `formation_videos`: stable video ID, title, creator, exact URL/YouTube ID, runtime, production state, topics, vice/virtue tags, difficulty, theological lens, sensitivity, verification provenance.
- `formation_packs`: stable pack ID, title, struggle, target formation, Scripture anchors, editorial order.
- `formation_days`: stable day ID, pack/day position, focus, objective, Scripture, planting language, presentation default, reflection, action, and option video IDs.
- `formation_rules`: stable rule ID, priority, eligibility parameters, presentation behavior, and enabled version.

Editorial records are readable without authentication. Only protected operator tooling may publish a new catalog version. The mobile app bundles the latest reviewed snapshot and refreshes newer published metadata through the API.

### User records

- `formation_profiles`: user/installation identity, timezone, reminder time and state, presentation preference, time budget, source preference, explicit priorities, optional explicit struggle, active catalog version.
- `formation_pack_queue`: resolved pack order with reason and configuration version.
- `formation_recommendations`: recommendation ID, local date, canonical day, pack/day IDs, rule ID, status, check-in due time, and configuration version.
- `formation_recommendation_options`: ordered video options and selected option.
- `formation_events`: append-only alarm, open, click, check-in, completion, partial, skip, replace, advance, and configuration-change events with idempotency keys.

The current pointer and derived counters are projections from events. Completion and day advancement occur in one idempotent transaction. A repeated tap, notification delivery, retry, reconnect, or sync replay cannot advance twice.

User progress is server-synced through the existing installation identity and PowerSync pattern, with a local-first projection for offline access. Sensitive explicit-struggle state is excluded from general analytics exports and notification bodies.

## Offline and failure behavior

- The bundled snapshot can resolve the next recommendation without a network connection.
- Clicks and explicit responses persist locally first and sync later.
- A network or API failure retains the last valid catalog and current recommendation.
- If YouTube cannot open, the recommendation remains unresolved and offers Retry.
- If notification permission is denied, pending check-ins appear when the app next opens.
- If a video becomes unavailable, the server marks it ineligible; an unresolved recommendation offers a compatible replacement and records that replacement explicitly.
- Catalog updates never mutate an already completed historical record. Titles and URLs shown in history use the captured recommendation snapshot.

## Migration

The current `FormationProgressRepository` stores only completed Scripture-reading IDs. Preserve that state as Scripture Formation history. Do not reinterpret it as video completion.

Daily video formation receives a new repository and schema. Existing users who completed orientation start at the Daily Formation setup, with the balanced path preselected and no alarm enabled until they opt in. Users still in orientation continue from their existing Nugget and position.

The Today card chooses one formation state in order:

1. incomplete orientation;
2. Daily Formation setup;
3. unresolved video recommendation;
4. today's resolved video;
5. completed video with optional reflection/action;
6. maintenance choice after the 70-day path.

Daily Scripture remains available independently in Meditation and its existing reader.

## Accessibility and media

- Video titles, thumbnails, and controls have meaningful accessibility labels.
- Durations are visible before opening a video.
- Cards support large text without hiding the primary action.
- Motion follows the existing reduced-motion preference.
- External playback never starts automatically.
- If an embedded player is introduced later, it must preserve captions, playback speed, audio focus, background lifecycle, and YouTube terms; it is not required for this release.

## Verification

### Import and editorial validation

- Import all 45 production videos and 70 daily records from the workbook.
- Reject missing IDs, duplicate daily options, invalid URLs, runtime above 630 seconds, unapproved status, missing required copy, corrupt characters, and prohibited garden phrases.
- Verify formula-derived source values against their referenced catalog rows.
- Confirm deterministic output and source checksum.
- Confirm a failed import cannot replace the active catalog.

### Rules and progress

- Resolve balanced and priority-reordered pack queues deterministically.
- Preserve the current unresolved recommendation across configuration changes.
- Recalculate only future packs after changing priorities.
- Enforce time budget, source preference, recent-history avoidance, sensitive opt-in, and one-versus-three presentation.
- Verify click does not advance, Finished advances exactly once, partial/skip do not advance, and day 70 enters maintenance.
- Verify offline events synchronize without duplicates.

### App experience

- Cover setup, Today states, external launch failure, notification permission denial, check-in actions, recovery, reflection/action handoff, large text, reduced motion, and orientation-to-video transition.
- Verify generic lock-screen copy for sensitive tracks.
- Verify Daily Scripture and orientation progress remain independent.
- Run API tests, Flutter domain/widget tests, static analysis, Android build, and connected-device checks for reminder/check-in delivery.

## Release sequence

1. Normalize and validate the workbook; generate the first reviewed catalog snapshot.
2. Add backend catalog, profile, recommendation, option, and event persistence plus protected catalog publication.
3. Add the deterministic rules engine and offline snapshot repository.
4. Add configuration, Today recommendation, external video launch, and completion check-in.
5. Add alarms, recovery notifications, optional Remember/Goal handoffs, and maintenance transition.
6. Migrate existing users without changing orientation or Scripture completion history.
7. Validate on the connected Android device, then publish through the existing Play draft flow.
