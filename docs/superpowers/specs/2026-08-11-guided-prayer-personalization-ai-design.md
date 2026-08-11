# Guided Prayer Personalization and AI Design

**Date:** 2026-08-11

**Status:** Approved for implementation planning

**Primary AI provider:** DeepSeek

## 1. Purpose

This slice makes `Create personalized` a working, local-first path beside the existing prayer library. It helps a person prepare a concise, editable prayer without pretending to replace their relationship with God, Scripture, conscience, church, family, clergy, or wise counsel.

SoulBuddy remains a humble guide and memory aid. The user owns the final wording. Every generated result is labelled as a draft until the user deliberately saves or uses it.

The spiritual formation framework contributes four guardrails rather than a new dashboard: examine important desires, entrust outcomes to God, consider outward benefit, and connect blessing with responsibility. The flow never measures spiritual wealth, scores motives, or turns prayer into performance.

## 2. Goals

- Enable the existing `Create personalized` choice.
- Keep the flow short, option-led, and responsive on mobile and web.
- Adapt the flow to daily versus important situational prayer.
- Generate a live, editable draft through Laravel and DeepSeek.
- Save every unfinished request locally before network work begins.
- Resume a queued request after authenticated connectivity returns.
- Send only context the user explicitly selects.
- Preserve accepted personal prayers with immutable revisions.
- Let an accepted prayer become today's prayer without leaving the flow.
- Let the user schedule a private reminder for a saved personal prayer.
- Let a reminder open a compact prayer surface with listening and confirmation actions.
- Record deliberate prayer-session confirmations without streaks or performance rewards.
- Generate one private narrated audio asset per prayer revision and voice configuration, then reuse it.
- Allow a revision with at least 40 recorded prayer sessions to be submitted for moderated publication in the library.
- Maintain the existing restrained, Gospel-conscious content voice.

## 3. Out of scope

- Authentication screens or account recovery. This slice consumes the existing application-session boundary.
- Anonymous or client-direct access to an AI provider.
- People, family, lessons, commitments, Circles, or chat.
- A general notification centre, Circle notifications, marketing notifications, or arbitrary habit reminders.
- Public profiles, visible contributor rankings, comments, or direct messaging around published prayers.
- Automatic analysis of the user's private history.
- Automatic provider failover.
- Spiritual scores, streaks, maturity levels, dashboards, leaderboards, or rewards.
- Claims of discernment, divine authorship, prophecy, or diagnosis.

People, family, lesson, and commitment connections remain part of the remembering-relationships slice. This slice supports only Encounter and Scripture context because those records already exist.

## 4. Approaches considered

### Server-orchestrated generation with a local queue — selected

Flutter saves the complete request locally, then Laravel authenticates and calls the configured model. This protects provider credentials, centralizes the safety contract, permits rate limiting, and keeps the app usable offline.

### Direct Flutter-to-provider generation — rejected

It would expose a reusable provider credential or require an unsafe token-broker design. It would also duplicate safety, privacy, and validation rules across clients.

### Template-only composition — rejected

It would work entirely offline but would tend toward mechanical or cosmetic wording. The library remains the fully offline alternative; personalized generation queues until a trusted server connection is available.

## 5. Product flow

### Entry

The Prayers screen presents two active choices:

1. `Choose from library`
2. `Create personalized`

The second choice opens `/prayers/create`. Returning to the library preserves the current library filters.

### Core choices

The creation flow uses one clear decision per step, with a visible back action and a quiet progress indication. Choices use large tap targets and remain keyboard and screen-reader accessible.

1. **Style**
   - `Daily / affirming`
   - `Situational / special`
2. **Reach**
   - `Personal`
   - `Encompassing / selfless`
3. **Grounding**
   - `General Christian`
   - `Catholic`
4. **Purpose**
   - Daily
   - Gratitude
   - Guidance
   - Family
   - Healing
   - Work
   - Forgiveness
   - A difficult time
5. **Request**
   - One short sentence, with purpose-sensitive examples and suggestions.
   - The field is limited to 500 Unicode characters and saved locally as it changes.

The app does not ask for a long journal entry. Suggestions are selectable but always editable.

### Dynamic `Before you ask`

Daily or affirming prayers may proceed directly from the core choices to optional context. Situational or special prayers receive a short examination step. It is guidance, never a test, and never blocks prayer.

The user chooses from:

- **Who should this blessing help?**
  - Me
  - My household or family
  - Another person
  - People affected by this
  - Beyond what I can see
- **What can you entrust to God?**
  - The outcome
  - The timing
  - The way it happens
  - All of these
- **If it is given, what responsibility may come with it?**
  - Use it wisely
  - Share or serve
  - Repair what needs attention
  - Act faithfully
  - I need time to discern
- **Could this conflict with love, truth, justice, or a responsibility?**
  - I see no conflict
  - I want to examine this further

The second alignment choice does not diagnose a problem. It causes the draft to use appropriately humble wording and leaves the user's request intact.

### Optional context

The user may add:

- one existing Encounter; and/or
- one Scripture passage from the bundled RSVCE repository.

The selection screen explains that only chosen material will be sent for this draft. SoulBuddy captures a local snapshot of the selected title/reference and excerpt at selection time. A later edit to the source record does not silently change an already queued request.

The Scripture reference is displayed separately from generated prayer wording. The model is never asked to invent or quote an unselected passage.

### Consent and generation

Before the first provider call, the user sees a short, versioned disclosure:

> To prepare this draft, SoulBuddy sends your choices and only the records you selected to DeepSeek. DeepSeek processes this information under its privacy policy.

Actions are `Prepare draft` and `Not now`. `Not now` leaves the request locally saved. Consent is requested again when the disclosure version or configured provider changes.

The generation screen does not block navigation. Leaving the screen preserves the request and status.

### Draft result

The result screen presents:

- a visible `Prayer draft` label;
- editable title;
- editable prayer body;
- a separately editable, optional practical action;
- selected Scripture reference or Encounter connection outside the generated body;
- `Use today`;
- `Save prayer`;
- `Prepare another draft`.

Regenerating after the user has edited the result requires confirmation before replacing the edited wording. Saving or using today creates the personal prayer and its first immutable revision. `Use today` also creates or replaces the current dated Today selection using the existing local-first behaviour.

### Saved prayer and reminder

After saving, the personal-prayer detail offers `Set reminder`, `Listen`, and `I prayed this`. The latter two behave the same way as their compact-reminder counterparts, allowing prayer and confirmation without waiting for a scheduled reminder. A reminder supports:

- once;
- every day; or
- selected weekdays;

at one local wall-clock time. The schedule stores its IANA timezone so the same local time survives daylight-saving changes. A device timezone change causes SoulBuddy to reschedule and briefly confirm the new timezone rather than silently shifting the reminder.

Notification permission is requested only when the user enables the first reminder. Lock-screen content is private by default: the system notification says `Prayer reminder` without the prayer title or body. The user may explicitly allow the title later; the body is never placed in a notification payload.

When SoulBuddy is in the foreground, a compact in-app prayer card appears. When it is in the background:

- Android and iOS use an actionable local notification that remains useful offline;
- supported browsers use authenticated Web Push;
- a browser without permission or push support shows the compact card on the next active visit.

The compact surface provides:

- `Listen`;
- `I prayed this`;
- `Snooze 10 minutes`;
- `Dismiss`.

It is an in-app route, sheet, or standard notification action, not an Android draw-over-other-apps overlay. SoulBuddy does not request `SYSTEM_ALERT_WINDOW`. Audio never starts without the user's `Listen` action.

`I prayed this` creates one private prayer-session record for the exact revision displayed or narrated. Repeated actions for the same reminder occurrence are idempotent. A brief `Undo` is available for accidental confirmation; there is no celebration, streak, score, or social signal.

### Narrated prayer

Narration is opt-in and has a separate, versioned disclosure because the prayer wording is sent to a voice provider. The initial provider is Deepgram Aura 2 using `aura-2-athena-en` at `0.9` speed, selected for a calm, smooth reading style.

The first `Listen` request for a revision generates one MP3 on the backend. Its cache identity is the SHA-256 digest of the normalized revision text, provider, model, voice, speed, and encoding. A matching asset is reused rather than regenerated. The private object is delivered through a short-lived signed URL and cached on the device after first playback for offline reuse.

Editing the prayer creates a new immutable revision and therefore a new audio identity. Old private audio is removed after it is no longer referenced and its retention window expires. Narration failure never blocks reading, confirming, saving, or rescheduling the prayer.

### Prayer sessions and publication

The personal-prayer detail may quietly state, for example, `14 prayer times recorded`. It may also say that publication becomes available after 40. It does not show a progress ring, streak, milestone celebration, ranking, or claim that repetition makes the prayer more spiritually valuable.

Publication eligibility is calculated by Laravel from at least 40 non-retracted prayer sessions for the exact current revision. Editing the wording creates a new revision whose publication count begins at zero; this prevents unprayed replacement wording from inheriting eligibility.

When eligible, `Publish for others` presents the exact public snapshot:

- title;
- body;
- optional action;
- grounding; and
- purpose.

The request text, `Before you ask` choices, Encounter and Scripture snapshots, reminders, sessions, identity, and all other private records are excluded. The user confirms ownership or permission to share the wording and understands that an approved snapshot enters the shared prayer library without personal attribution.

Publication creates a moderated submission. It does not become public immediately. States are `pending_review`, `changes_requested`, `rejected`, `published`, and `withdrawn`. Approval creates a normal `library_prayers` row and moves the submission atomically to `published`, after which existing Helpful voting and ordering apply. Editing the private prayer never silently edits the public snapshot; a changed revision requires a new submission and review. The owner may withdraw a published prayer, which archives it from new discovery.

This slice supplies a minimal audited Laravel review command for authorized operators. A richer Filament moderation interface remains in the operational-readiness slice.

## 6. Content contract

The generated prayer must:

- address God directly;
- contain 60–140 words;
- use clear, restrained, warm language;
- remain suitable for private prayer rather than presentation copy;
- reflect the selected style, reach, grounding, purpose, examination choices, and explicit context;
- avoid invented biblical imagery and sentimental church language;
- include at most one optional practical action of 3–18 words.

The generated prayer must not:

- say or imply `God told you`, `The Holy Spirit is saying`, or equivalent claims;
- promise an outcome or claim that God caused a selected event;
- diagnose faith, motive, spiritual state, sin, or maturity;
- imply that a hardship proves something about the user;
- present prosperity, status, health, or success as guaranteed;
- invent a Bible quotation or reference;
- present the practical action as God's command;
- include a score, achievement, streak, or comparative judgment;
- expose prompt instructions, provider metadata, or selected-record identifiers.

Catholic grounding does not automatically introduce Catholic doctrines, devotional formulas, saintly intercession, or formal prayer structures. General Christian grounding does not argue against Catholic belief or impose another denomination. Both use the same central Christian posture while allowing carefully reviewed grounding-specific wording.

The provider response schema contains exactly:

```json
{
  "title": "string",
  "body": "string",
  "action": "string or null"
}
```

Laravel performs schema, type, length, control-character, forbidden-claim, and reference checks. One invalid result may be sent through a repair attempt. A second invalid result is discarded and returned as a generic `draft_needs_attention` failure.

## 7. Client architecture

The Flutter feature remains under `features/prayers` with focused domain, data, application, provider, and presentation units.

### Local generation request

`prayer_generation_requests` is a PowerSync local-only table:

- `id`: client UUIDv7 text primary key
- `owner_id`
- `style`
- `reach`
- `grounding`
- `purpose`
- `request_text`
- `beneficiary_choice`
- `surrender_choice`
- `responsibility_choice`
- `alignment_choice`
- `status`: `editing`, `queued`, `generating`, `ready`, or `needs_attention`
- `draft_title`, `draft_body`, `draft_action`
- local-only `generated_title`, `generated_body`, `generated_action` baseline
  fields so edit detection still works after closing and reopening the draft
- `prompt_version`, `provider_disclosure_version`
- nullable `consented_provider` and `consented_disclosure_version`
- nullable `active_attempt_id`, `attempt_started_at`, and `next_attempt_at`
- `attempt_count`, `last_attempt_at`, `failure_code`
- `created_at`, `updated_at`

`prayer_generation_contexts` is also local-only:

- `id`
- `request_id`
- `context_type`: `encounter` or `scripture`
- `source_id`
- `display_label`
- `excerpt_snapshot`
- Scripture translation/book/chapter/verse-range fields when applicable
- `created_at`

Both tables are private to the installation and create no PowerSync CRUD upload. The repository writes a request and its context atomically.

### Accepted prayer records

`personal_prayers` is synchronized:

- `id`, `owner_id`, `title`
- `style`, `reach`, `grounding`, `purpose`
- `current_revision_id`
- `created_at`, `updated_at`, `archived_at`

`personal_prayer_revisions` is synchronized and immutable:

- `id`, `prayer_id`, `owner_id`
- `body`, `action`
- `created_at`, `device_id`

`personal_prayer_links` is synchronized:

- `id`, `prayer_id`, `owner_id`
- `link_type`: `encounter` or `scripture`
- `linked_record_id` for an Encounter
- translation/book/chapter/verse-range fields for Scripture
- `created_at`

Application and server validation require exactly the fields appropriate to the selected link type. Ownership is authoritative from authentication at the server, never from uploaded `owner_id` values.

### Today selection compatibility

The existing `today_prayers.prayer_id` is a foreign key to `library_prayers`; it cannot safely be overloaded with a personal-prayer ID. The migration therefore:

- makes the existing `prayer_id` nullable while retaining its library-prayer foreign key;
- adds nullable `personal_prayer_id` with a foreign key to `personal_prayers`;
- adds a database constraint requiring exactly one of those columns;
- leaves every existing Today row as a valid library selection.

Flutter represents the selection as a typed source plus ID. The Today query unions library wording with the current immutable revision of a personal prayer. Helpful voting remains library-only. Action completion includes the typed source and expected prayer ID in its optimistic-concurrency predicate so a stale personal or library card cannot complete a replacement selection.

### Reminders and prayer sessions

`prayer_reminders` is synchronized and private:

- `id`, `owner_id`, `personal_prayer_id`
- `schedule_type`: `once`, `daily`, or `weekdays`
- `local_time` in `HH:mm`
- IANA `timezone`
- nullable UTC `once_at`
- nullable seven-bit `weekdays_mask`
- `enabled`, `created_at`, `updated_at`

Validation requires `once_at` only for `once`, a non-zero weekday mask only for `weekdays`, and neither for `daily`. A reminder always follows the personal prayer's current revision at the time an occurrence is displayed.

`prayer_reminder_devices` is local-only:

- deterministic `id` from reminder and device IDs
- `reminder_id`, `device_id`
- `enabled_on_device`
- `next_occurrence_at`
- `platform_notification_id`
- `scheduled_timezone`, `updated_at`

This prevents a synced reminder from automatically producing duplicate notifications on every device. The creating device is enabled immediately; another device asks before enabling its local schedule. Web Push subscriptions are server-held per browser installation and follow the same explicit device enablement.

`prayer_sessions` is synchronized and private:

- `id`, `owner_id`, `personal_prayer_id`, `prayer_revision_id`
- nullable `reminder_id` and deterministic `reminder_occurrence_key`
- `source`: `reminder` or `manual`
- `occurred_at`, `local_date`, `timezone`, `device_id`
- nullable `retracted_at`

The confirmation identity and revision cannot be edited. The owner may set `retracted_at` within five minutes for Undo. A unique reminder occurrence may create at most one active session for a user. Publication counts only non-retracted, server-accepted sessions for the submitted revision.

### Narration cache

`prayer_audio_assets` is private server data:

- `id`, `user_id`, `prayer_revision_id`
- `content_hash`
- `provider`, `model`, `voice`, `speed`, `encoding`
- `status`: `queued`, `generating`, `ready`, or `failed`
- private object key, byte size, optional duration, failure code
- `created_at`, `updated_at`, nullable `expires_at`

The unique cache key is `(user_id, prayer_revision_id, content_hash, provider, model, voice, speed, encoding)`. The raw object key never synchronizes to Flutter. Authenticated REST endpoints expose status and a short-lived signed playback URL.

`prayer_audio_cache` is local-only device metadata mapping the server asset ID and content hash to a platform cache path or browser cache key. The cache may be evicted without affecting the prayer.

### Publication submissions

`prayer_publications` is synchronized privately to its owner:

- `id`, `owner_id`, `personal_prayer_id`, `prayer_revision_id`
- snapshot `title`, `body`, `action`, `grounding`, `purpose`
- `status`: `pending_review`, `changes_requested`, `rejected`, `published`, or `withdrawn`
- nullable safe `review_note`
- nullable `library_prayer_id`
- `submitted_at`, `reviewed_at`, `published_at`, `withdrawn_at`

The backend separately stores reviewer identity and an immutable audit trail; those fields never enter the owner's sync stream. The public `library_prayers` row contains no user ID or private-source relationship. One revision may have only one active submission. Publication and withdrawal lock the submission and relevant prayer rows in deterministic order.

### Dispatcher

A single `PrayerGenerationDispatcher` owns network state transitions. It:

- watches queued requests while the app is active;
- attempts work immediately after the user consents;
- resamples on application resume and authenticated connectivity changes;
- permits only one active attempt per request;
- uses bounded exponential backoff for transient failures;
- moves a `generating` request back to `queued` when its attempt lease is older than the configured request timeout;
- never retries permanent validation or consent failures automatically;
- cannot block the prayer library, Today, Record, or Remember features.

The UI watches the local database as its source of truth. No success state depends on an in-memory callback surviving navigation or process death.

## 8. Laravel architecture

### Endpoint

`POST /api/prayer-drafts` is protected by `auth:sanctum` and configurable per-user and per-IP rate limiters. Initial limits are 10 attempts per authenticated user per hour, 30 per user per day, and 30 per IP per hour. The request contains a stable local request UUID, a generation-attempt UUID, prompt/disclosure versions, structured choices, and explicit context snapshots.

Laravel:

1. authenticates the user;
2. validates enums, sizes, context count, reference structure, and consent version;
3. derives a privacy-preserving provider `user_id` from the authenticated user's public ID;
4. applies per-user and per-IP limits;
5. calls the configured provider through `PrayerDraftProvider`;
6. validates or repairs the structured result;
7. returns the validated draft without logging its contents.

Concurrent duplicate attempt IDs are collapsed. A successful response may be retained only in a short-lived encrypted idempotency cache so a lost HTTP response can be replayed without a second provider charge. It is not a durable prayer record and expires within ten minutes. After Flutter has committed the returned draft locally, it calls `DELETE /api/prayer-drafts/attempts/{attemptId}` to purge the cache immediately; failure to acknowledge is harmless because expiry remains authoritative.

### Provider abstraction

```text
PrayerDraftProvider
  generate(PrayerDraftInput): PrayerDraftResult

DeepSeekPrayerDraftProvider
  Laravel HTTP client
  OpenAI-compatible DeepSeek endpoint
  JSON output mode
  no provider-side conversation or history
```

The initial deployment uses `deepseek-v4-flash` in non-thinking mode. The legacy `deepseek-chat` and `deepseek-reasoner` aliases are not used because DeepSeek discontinued them on 2026-07-24.

Configuration is server-only:

- `AI_PROVIDER=deepseek`
- `DEEPSEEK_API_KEY`
- `DEEPSEEK_BASE_URL=https://api.deepseek.com`
- `DEEPSEEK_MODEL=deepseek-v4-flash`
- a 20-second provider timeout, 350 output-token maximum, the defined rate limits, and a versioned prompt identifier

The interface permits a later provider adapter, but this slice implements no silent fallback. A provider change requires a new disclosure version and renewed user consent.

### Accepted prayer synchronization

Laravel adds migrations, models, policies, and sync mutation handling for personal prayers, revisions, links, reminders, sessions, and publication status. Revisions and prayer-session identities are immutable. Mutations use the established authenticated ownership, replay protection, deterministic lock ordering, alias, and privacy patterns already used by Encounter and prayer-practice synchronization.

### Reminder delivery

Native mobile schedules local notifications from the synchronized reminder so prayer reminders still fire without network access. It uses the platform's normal notification facilities and actionable categories; exact-alarm or draw-over-other-apps permission is not required. When a platform cannot guarantee exact delivery, SoulBuddy uses the closest permitted scheduled delivery and never claims second-level precision.

Laravel's minute scheduler handles due browser reminders for explicitly enabled Web Push subscriptions. It derives deterministic occurrence keys from reminder ID and scheduled UTC instant, claims each occurrence once, and records delivery metadata without prayer text. Notification payloads contain only an opaque occurrence ID, generic copy, and a deep link. The authenticated app resolves the prayer after opening.

Native and web actions converge on the same local session repository and server uniqueness contract. `Snooze 10 minutes` creates a device-local one-time occurrence; it does not change the recurring schedule.

### Narration provider and media

Laravel adds a `PrayerNarrationProvider` interface and initial `DeepgramPrayerNarrationProvider`. Generation uses the Deepgram Aura 2 REST endpoint with:

- `aura-2-athena-en`;
- speed `0.9`;
- MP3 encoding;
- a 2,000-character input ceiling; and
- a bounded timeout and one transient retry.

`POST /api/personal-prayers/{prayer}/revisions/{revision}/audio` authorizes the owner, validates the current consent version, and returns the existing asset or queues one new generation. `GET /api/prayer-audio/{asset}` returns status and, when ready, a short-lived signed URL. The API never accepts arbitrary text; it reads the authenticated immutable revision from the database.

The object store is private. Local development uses Laravel's private disk; deployed environments use private S3-compatible storage. Asset creation is atomic: a database row cannot become `ready` until the complete object and checksum are present. A cleanup job removes expired unreferenced objects and stale failed rows.

Server-only configuration is:

- `TTS_PROVIDER=deepgram`
- `DEEPGRAM_API_KEY`
- `DEEPGRAM_TTS_MODEL=aura-2-athena-en`
- `DEEPGRAM_TTS_SPEED=0.9`
- narration disclosure version, timeout, signed-URL lifetime, and retention period

### Publication and review

`POST /api/personal-prayers/{prayer}/publications` authorizes the owner, locks the selected revision, counts at least 40 server-accepted non-retracted sessions for that revision, validates the privacy-scrubbed snapshot, and creates one pending submission. The server never trusts a client-supplied count.

An audited Artisan command supports `approve`, `request-changes`, `reject`, and `withdraw` transitions for authorized operators. Approval creates a stable UUIDv7 `library_prayers` row from the reviewed snapshot in the same transaction. A second approval attempt is idempotent. Withdrawal archives that library row from new discovery and preserves the audit history. No moderation operation writes private prayer wording to logs.

## 9. Privacy and security

- Provider credentials exist only in the ignored Laravel `.env` and deployment secret store.
- Flutter never receives, stores, or proxies a provider key.
- No secret value appears in source, fixtures, snapshots, logs, exception messages, or CI output.
- Existing keys shared outside the secret store must be revoked before live verification; only rotated values may be used.
- The user explicitly consents before the first provider transmission and after a provider/disclosure change.
- Narration has separate versioned consent because it sends accepted prayer wording to Deepgram.
- Only selected Encounter or Scripture snapshots are transmitted.
- The full encounter history, prayer history, Remember archive, and Today history are never added automatically.
- Laravel request and exception logs exclude request text, context excerpts, generated wording, provider payloads, tokens, and authorization headers.
- Metrics use opaque request identifiers, status codes, latency, and token counts only.
- Input length, output length, rate, timeout, and retry limits cap cost and abuse.
- The privacy notice links to DeepSeek's current policy and accurately states that DeepSeek may process, retain, and use inputs according to that policy.
- The narration notice links to Deepgram's current policy. The deployment does not join Deepgram's Model Improvement Partnership Program.
- Reminder notifications contain generic copy by default and never contain the prayer body.
- Private audio uses authenticated short-lived URLs; object keys and provider responses are never exposed.
- A publication preview is the only path from a private prayer to the public library. Private context and identity are excluded by construction and tested.
- Provider and model identifiers are operational metadata, not presented as spiritual authority.

DeepSeek is selected for this deployment despite its broader data-use and storage policy because the product owner prefers its price and capability. The product must not describe DeepSeek as zero-retention or claim that submitted prayer content cannot be used for model improvement.

## 10. Failure behaviour

- **Offline:** `Saved. Your prayer draft will be prepared when you're connected.`
- **No application session:** preserve the request and explain that account connection is required.
- **Provider timeout or 5xx:** preserve the request, schedule bounded retry, and offer `Try again`.
- **Rate limit:** preserve the request and show a retry time when available.
- **Invalid provider output:** discard it, retain the request, and show a generic focused error.
- **Consent declined or outdated:** do not send; retain the editable request.
- **App closed during generation:** recover from the local request state and retry or reconcile on resume.
- **Draft edited before regeneration:** require replacement confirmation.
- **Save interrupted:** the transaction either creates the prayer, revision, and links together or creates none of them.
- **Sync rejected:** retain the local accepted prayer and surface a private sync issue without implying data loss.
- **Notification permission denied:** keep the schedule and show in-app reminders without repeated permission prompts.
- **Native scheduling unavailable:** keep the reminder enabled in SoulBuddy, explain that background delivery is unavailable, and show it when the app becomes active.
- **Web Push unavailable:** preserve the schedule and use the next-visit in-app reminder.
- **Narration offline or pending:** keep `Listen` disabled with a concise status while the written prayer and confirmation remain usable.
- **Narration generation failed:** retain the prayer, permit a bounded retry, and never fall back to a different voice provider silently.
- **Audio download interrupted:** keep the server asset and resume or redownload without regenerating it.
- **Duplicate reminder action:** return the existing prayer-session result without incrementing the count.
- **Publication below 40:** keep the prayer private and return the authoritative eligible count without creating a submission.
- **Publication needs changes or is rejected:** retain the private prayer and show only the review-safe note.
- **Withdrawal interrupted:** remain in the last committed state; never hide the private source prayer.

Errors never display raw provider responses or private request content. Retry invalidation must not tear down healthy shared database or cross-feature providers.

## 11. Accessibility and responsive behaviour

- Interactive controls have a minimum 48 logical-pixel target.
- Every choice exposes selected/enabled semantics and a meaningful label.
- Progress is conveyed by text and semantics, not colour alone.
- Text remains usable at 200% scaling without clipping or horizontal overflow.
- Mobile uses a single-column step flow with thumb-friendly primary actions.
- Wide web layouts may place compatible choices in two columns but keep reading order intact.
- Focus moves to the new step heading and to generation errors when appropriate.
- Back navigation never loses saved input.
- Motion is short, interruptible, and suppressed when reduced motion is requested.
- Notification actions and the compact reminder surface expose the same clear accessible names.
- Narration exposes play, pause, elapsed time, and loading state to assistive technology.
- `I prayed this` is explicit; the app does not use ambiguous wording such as `Heeded` as the primary confirmation label.

## 12. Testing and evaluation

### Flutter

- Domain parsing and validation tests for every enum and state transition.
- Real PowerSync repository tests for request/context transactions, queue recovery, accepted prayer revisions, links, and Today selection.
- Real PowerSync repository tests for reminder schedules, device enablement, deterministic occurrences, prayer-session deduplication/retraction, and per-revision counts.
- Provider/dispatcher tests for offline, unauthenticated, timeout, retry, resume, duplicate-attempt, and process-reopen paths.
- Widget tests for both dynamic routes, consent, editing, regeneration confirmation, reminder creation, compact reminder actions, narration states, publication eligibility, error recovery, keyboard navigation, semantics, and 200% text scale.
- Router tests for deep links and safe back navigation.
- Platform scheduling adapter tests for permission denial, DST/timezone changes, rescheduling, snooze, cancellation, and generic lock-screen copy.
- Audio cache tests for content-hash reuse, revision changes, interrupted downloads, eviction, signed-URL expiry, and offline playback.
- Real Chrome integration for queue, generation with a fake Laravel provider, editing, acceptance, Today, Web Push/in-app reminder delivery, narration playback, session confirmation, close, and reopen.
- Real Android emulator integration for the same lifecycle using the native database path and an actionable local notification.

### Laravel

- Feature tests for authentication, authorization, validation precedence, consent version, rate limits, idempotency, and safe error codes.
- Provider contract tests using Laravel HTTP fakes for success, malformed JSON, forbidden claims, timeout, 429, 5xx, and repair behaviour.
- Deepgram narration contract tests for cache hits, concurrency, immutable source loading, limits, timeout, invalid audio, checksums, signed URLs, and cleanup.
- Mutation tests for personal prayers, immutable revisions, links, reminders, sessions, retraction window, aliases, multi-install replay, foreign ownership, rollback, and lock ordering.
- Reminder scheduler and Web Push tests for timezone/DST behaviour, occurrence claiming, generic payloads, disabled subscriptions, retry, and duplicate prevention.
- Publication tests for the exact-revision 40-session threshold, retractions, foreign records, snapshot scrubbing, moderation transitions, idempotent approval, withdrawal, and anonymous library rows.
- Log-capture tests proving that private text, excerpts, outputs, notification contents, object keys, provider keys, audio payloads, and authorization headers are absent.
- Migration up/down tests on SQLite plus PostgreSQL integration where a live service is available.

### Content evaluation

A versioned, non-private evaluation set covers:

- both styles;
- both reaches;
- both groundings;
- all purposes;
- every `Before you ask` choice;
- selected and unselected Encounter/Scripture context;
- requests involving status, money, healing, conflict, forgiveness, work, family, and disappointment.

Automated evaluation enforces schema, length, prohibited claims, quotation/reference rules, and action constraints. Human review assesses directness, theological restraint, natural prayer language, grounding accuracy, selflessness, and usefulness. A prompt version is not production-ready until the automated suite passes and its representative outputs receive human approval.

An optional live DeepSeek smoke test uses only synthetic non-private content, runs outside CI, redacts all response text from command output, and requires a rotated environment key. Normal CI uses provider fakes.

## 13. Acceptance journey

On a real Android emulator and in Chrome, a reviewer can:

1. open Prayers and choose `Create personalized`;
2. complete a daily flow without `Before you ask`;
3. go back and complete a situational flow with the examination choices;
4. explicitly attach an Encounter or RSVCE passage;
5. decline provider consent and confirm that nothing is sent or lost;
6. accept consent while offline and see the queued request survive app restart;
7. reconnect with a seeded authenticated Laravel session and receive a DeepSeek draft;
8. edit the title, prayer, and optional action;
9. confirm before replacing an edited draft;
10. save the prayer and select it for Today;
11. set a daily reminder and confirm its private generic notification;
12. open the compact reminder, choose `Listen`, and receive one cached Deepgram narration;
13. choose `I prayed this`, repeat the same occurrence action, and confirm it counts only once;
14. close and reopen the database/app and see the prayer, reminder, local audio cache, Today selection, and session state;
15. record 40 sessions for the exact revision through deterministic test fixtures and see `Publish for others` become available;
16. preview and submit a privacy-scrubbed publication;
17. approve it through the audited review command and see it once in the voted library without contributor identity;
18. withdraw it and confirm it leaves new discovery while the private prayer remains;
19. confirm that no private text, notification body, audio object key, or credential appears in Flutter, Laravel, scheduler, or provider-client logs.

The existing prayer library, Helpful voting, Today, Encounter recording, Remember, and Scripture reading must continue to work offline throughout this journey.

## 14. External references

- [DeepSeek current models and pricing](https://api-docs.deepseek.com/quick_start/pricing/)
- [DeepSeek change log and V4 model names](https://api-docs.deepseek.com/updates)
- [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)
- [Deepgram Aura text-to-speech](https://developers.deepgram.com/docs/text-to-speech)
- [Deepgram Aura voices](https://developers.deepgram.com/docs/tts-models)
- [Deepgram voice controls](https://developers.deepgram.com/docs/tts-voice-controls)
- [Deepgram model-improvement data policy](https://developers.deepgram.com/docs/the-deepgram-model-improvement-partnership-program)
- [Deepgram pricing](https://deepgram.com/pricing)
- [SoulBuddy MVP design](./2026-08-10-soulbuddy-mvp-design.md)
- `C:\dev\soulbuddy\spiritual_wealth_app_framework.md` — product and formation input; it is not application source content.
