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
- Maintain the existing restrained, Gospel-conscious content voice.

## 3. Out of scope

- Authentication screens or account recovery. This slice consumes the existing application-session boundary.
- Anonymous or client-direct access to an AI provider.
- People, family, lessons, commitments, Circles, chat, audio, or notifications.
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

Laravel adds migrations, models, policies, and sync mutation handling for personal prayers, revisions, and links. Revisions are immutable. Mutations use the established authenticated ownership, replay protection, deterministic lock ordering, alias, and privacy patterns already used by Encounter and prayer-practice synchronization.

## 9. Privacy and security

- Provider credentials exist only in the ignored Laravel `.env` and deployment secret store.
- Flutter never receives, stores, or proxies a provider key.
- No secret value appears in source, fixtures, snapshots, logs, exception messages, or CI output.
- Existing keys shared outside the secret store must be revoked before live verification; only rotated values may be used.
- The user explicitly consents before the first provider transmission and after a provider/disclosure change.
- Only selected Encounter or Scripture snapshots are transmitted.
- The full encounter history, prayer history, Remember archive, and Today history are never added automatically.
- Laravel request and exception logs exclude request text, context excerpts, generated wording, provider payloads, tokens, and authorization headers.
- Metrics use opaque request identifiers, status codes, latency, and token counts only.
- Input length, output length, rate, timeout, and retry limits cap cost and abuse.
- The privacy notice links to DeepSeek's current policy and accurately states that DeepSeek may process, retain, and use inputs according to that policy.
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

## 12. Testing and evaluation

### Flutter

- Domain parsing and validation tests for every enum and state transition.
- Real PowerSync repository tests for request/context transactions, queue recovery, accepted prayer revisions, links, and Today selection.
- Provider/dispatcher tests for offline, unauthenticated, timeout, retry, resume, duplicate-attempt, and process-reopen paths.
- Widget tests for both dynamic routes, consent, editing, regeneration confirmation, error recovery, keyboard navigation, semantics, and 200% text scale.
- Router tests for deep links and safe back navigation.
- Real Chrome integration for queue, generation with a fake Laravel provider, editing, acceptance, Today, close, and reopen.
- Real Android emulator integration for the same lifecycle using the native database path.

### Laravel

- Feature tests for authentication, authorization, validation precedence, consent version, rate limits, idempotency, and safe error codes.
- Provider contract tests using Laravel HTTP fakes for success, malformed JSON, forbidden claims, timeout, 429, 5xx, and repair behaviour.
- Mutation tests for personal prayers, immutable revisions, links, aliases, multi-install replay, foreign ownership, rollback, and lock ordering.
- Log-capture tests proving that private text, excerpts, outputs, keys, and authorization headers are absent.
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
11. complete its action;
12. close and reopen the database/app and see the accepted wording, connection, Today selection, and completion state;
13. confirm that no private text or credential appears in Flutter, Laravel, or provider-client logs.

The existing prayer library, Helpful voting, Today, Encounter recording, Remember, and Scripture reading must continue to work offline throughout this journey.

## 14. External references

- [DeepSeek current models and pricing](https://api-docs.deepseek.com/quick_start/pricing/)
- [DeepSeek change log and V4 model names](https://api-docs.deepseek.com/updates)
- [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)
- [SoulBuddy MVP design](./2026-08-10-soulbuddy-mvp-design.md)
- `C:\dev\soulbuddy\spiritual_wealth_app_framework.md` — product and formation input; it is not application source content.
