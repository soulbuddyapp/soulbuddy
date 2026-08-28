# Seek, Goals, and External Circles Implementation Plan

**Date:** 2026-08-28  
**Design:** `docs/superpowers/specs/2026-08-28-seek-goals-circles-design.md`  
**Objective:** Reorganize SoulBuddy around Goals and Today, add practical Return/guard/accountability support, replace in-app Circle chat with external Telegram/WhatsApp coordination, and remove synthetic spiritual copy without rewriting mature prayer/Record/Remember infrastructure.

## 1. Implementation principles

1. **Orchestrate; do not rewrite.** Reuse prayer, reminder, Scripture, Voice Tablet, Altar, Record, Remember, local identity, sync, feedback and notification primitives.
2. **No big-bang migration.** Add Goals beside current prayer flows, migrate activation/navigation, then retire obsolete prayer-generation and local Circle-chat surfaces.
3. **Server authority for shared state.** Circle directory, provider binding, schedules and moderation are Laravel-authoritative. Private Goal use remains local-first.
4. **Provider capabilities are explicit.** Telegram and WhatsApp must not share fake feature parity.
5. **No synthetic spiritual content.** Runtime never calls an LLM to produce prayer/exhortation/discussion/recovery/purpose copy.
6. **Every tranche ends green.** Format, analysis, Flutter tests, Laravel tests, migration tests and focused integration tests must pass before the tranche is merged.
7. **Protect existing user data.** No accepted prayer, encounter, Voice Tablet, Altar, reminder or local Circle text is deleted without a tested migration/export path.

## 2. Current implementation to preserve

The current repository already has useful foundations:

- `apps/soulbuddy/lib/app/router.dart` has the five-destination stateful shell;
- `today_prayers` provides a dated prayer/action selection;
- `personal_prayers`, revisions, links, reminders and sessions are durable primitives;
- `voice_tablets`, altar items/rituals and notification handling are substantial reusable infrastructure;
- first-prayer onboarding has durable progress, Speak/Write paths and failure recovery;
- `encounters`, Scripture and Remember are already local-first;
- Laravel already provides authenticated mutation boundaries and installation sessions;
- Circles are explicitly `Table.localOnly`, making them safe to replace rather than unwind from a production chat system.

Do not duplicate these capabilities under Goals.

## 3. Target architecture

### 3.1 Flutter feature structure

Add:

```text
features/goals/
  domain/
  data/
  application/
  providers/
  presentation/

features/guards/
  domain/
  data/
  presentation/

features/circles/
  domain/                 # replace local-chat domain with directory/config model
  data/
  application/
  providers/
  presentation/
```

Keep prayers as a separate resource feature even after its shell destination is removed.

### 3.2 Goal tables

Recommended synchronized/private schema:

#### `goals`

- `owner_id`
- `starter_key` nullable (`closer_to_god`, `stop_control`, `direction`, `difficult_time`, `other`)
- `mode` internal (`actionable`, `petition`, `mixed`)
- `status` (`active`, `paused`, `completed`, `archived`)
- `current_revision_id`
- `position`
- `created_at`
- `updated_at`
- `archived_at`

Indexes: owner/status/position; owner/updated.

#### `goal_revisions`

- `goal_id`
- `owner_id`
- `title`
- `current_situation` nullable
- `why_it_matters` nullable
- `created_at`
- `device_id`

Preserve revisions instead of overwriting important Goal text.

#### `goal_links`

Typed links to existing records:

- `goal_id`
- `owner_id`
- `link_type` (`personal_prayer`, `library_prayer`, `encounter`, `voice_tablet`, `circle`, `scripture`)
- corresponding target identifier or Scripture coordinates
- `role` (`primary_prayer`, `supporting_prayer`, `primary_circle`, `support`, `reference`)
- `created_at`
- `archived_at`

Validate at application/server boundaries that exactly one target shape is populated.

#### `goal_actions`

- `goal_id`
- `owner_id`
- `body`
- `action_kind` (`next_step`, `guard`, `accountability`, `care`, `other`)
- `schedule_type` (`today`, `once`, `daily`, `selected_days`, `none`)
- `local_time` nullable
- `timezone` nullable
- `once_at` nullable
- `weekdays_mask` nullable
- `enabled`
- `created_at`
- `updated_at`
- `archived_at`

Do not use a racing completion boolean for recurring actions.

#### `goal_action_events`

Append-only events:

- `goal_action_id`
- `goal_id`
- `owner_id`
- `event_type` (`completed`, `skipped`, `retracted`)
- `occurrence_key`
- `occurred_at`
- `local_date`
- `device_id`

Unique logical completion per action/occurrence/user with retraction support.

#### `goal_onboarding_progress` local-only

Replace `first_prayer_progress` only after parity exists. Persist wizard stage, answers, optional temporary voice material and created Goal ID. Reuse the existing cleanup pattern for temporary audio keys.

### 3.3 Guard catalogue

Do not encode platform instructions directly in widgets.

Use an editorial/versioned catalogue, initially bundled and later server-overridable:

```text
GuardDefinition
- id
- goal_context tags
- platform/os
- title
- concise description
- ordered steps
- source/vendor URL where applicable
- content version
- reviewed_at
- archived
```

User state stores only selected/configured guard IDs plus optional private notes; it does not clone the entire instruction body.

### 3.4 Circle server schema

Do not sync external chat messages.

#### `circles`

- `owner_user_id`
- `public_id` UUIDv7
- `name`
- `category` (`accountability`, `daily_exhortation`, `bible_study`)
- `description`
- `visibility` (`public`, `unlisted`, `private`)
- `status` (`draft`, `active`, `paused`, `suspended`, `archived`)
- `created_at`, `updated_at`

#### `circle_provider_bindings`

- `circle_id`
- `provider` (`telegram`, `whatsapp_link`, `whatsapp_groups_api`)
- provider identifiers encrypted/opaque as appropriate
- provider join/open URL where safe
- capability bitset/JSON determined server-side
- `binding_status`
- `bound_at`, `last_verified_at`

Never store provider bot secrets per Circle.

#### `circle_schedules`

- `circle_id`
- `schedule_kind` (`accountability`, `exhortation`, `bible_study`, `reminder`)
- `timezone`
- `local_time`
- `weekdays_mask`
- `content_plan_id` nullable
- `enabled`
- timestamps

#### `circle_schedule_deliveries`

- `schedule_id`
- `occurrence_key`
- provider message ID nullable
- status
- attempted_at / delivered_at
- failure_code nullable

Unique `(schedule_id, occurrence_key)` to make retries idempotent.

#### `circle_content_plans`

References approved editorial content/study sequences. Do not store generated text.

#### `circle_directory_reports`

Minimal report and moderation state for SoulBuddy discovery. Conversation evidence remains on the external provider unless the reporter deliberately supplies specific evidence through a future reviewed flow.

### 3.5 Telegram webhook architecture

Endpoints/services should be isolated from generic API controllers:

```text
app/Domain/Circles/
app/Domain/CircleProviders/Telegram/
app/Jobs/Circles/
```

Recommended endpoints:

- authenticated `POST /api/circles`;
- `GET /api/circles` discovery with safe filters/pagination;
- `GET /api/circles/{publicId}`;
- owner `PATCH /api/circles/{publicId}`;
- owner `POST /api/circles/{publicId}/telegram-binding-token`;
- provider webhook `POST /api/providers/telegram/webhook/<secret-or-verified-route>`;
- schedule CRUD under `/api/circles/{publicId}/schedules`;
- join/open metadata endpoint if required.

The Telegram binding token is short-lived, single-use, random/opaque or signed with nonce persistence, and maps to Circle + owner server-side. Do not embed Goal text or user private data in the `startgroup` parameter.

### 3.6 Scheduling worker

Use durable queue/cron infrastructure before enabling automated Circle delivery. The current production choice of synchronous jobs is not sufficient for unattended scheduled reminders.

Implement:

- scheduler discovers due Circle schedule occurrences;
- creates delivery row transactionally;
- dispatches provider job;
- provider job is idempotent;
- retries use bounded backoff;
- permanent provider errors pause/flag the binding without blocking unrelated schedules;
- no prayer/Goal/private check-in body in logs.

A simple database-backed Laravel queue is sufficient initially if supervised by a durable worker. Redis/Horizon can follow when operational load justifies it.

## 4. Tranche plan

## Tranche 0 — Freeze product invariants and add regression guards

**Goal:** Prevent the old architecture from expanding while the migration is underway.

### Work

- Add design/implementation docs.
- Add tests/lints or code comments enforcing that new shell destinations do not add `Recovery`, `Freedom`, `Purpose`, `Coaching` or `Addiction` as primary navigation.
- Add a `SyntheticSpiritualContent` architecture rule in docs/tests: no new runtime AI call may feed user-facing prayer/exhortation/study/direction copy.
- Add a feature flag that can disable new prayer generation while legacy accepted prayers continue to render.
- Inventory all DeepSeek prayer-generation entry points and all local Circle message entry points.

### Acceptance

- Existing tests remain green.
- No data is removed.
- New work has one canonical design reference.

## Tranche 1 — Goal domain and persistence

**Goal:** Establish Goals without changing navigation yet.

### Flutter

- Add Goal domain types and repository interface.
- Add `goals`, `goal_revisions`, `goal_links`, `goal_actions`, `goal_action_events` to PowerSync schema.
- Implement owner-scoped repository with UUIDv7 IDs and transactional current-revision updates.
- Add query helpers for active Goal list and due Today actions.

### Laravel

- Add equivalent migrations/models/policies/mutation handling.
- Extend sync mutation allowlist and validation.
- Add cross-owner/tamper regression tests.

### Tests

- create/edit/reopen;
- revision preservation;
- owner isolation;
- action recurrence and completion/retraction;
- offline CRUD queue shape;
- Laravel idempotence and authorization.

### Acceptance

A Goal can be created offline, reopened, edited without losing revisions, synced through the authoritative mutation boundary, and linked to an existing prayer/Scripture/encounter.

## Tranche 2 — Guided first Goal

**Goal:** Replace first-prayer activation with first-Goal activation while reusing the durable onboarding machinery.

### Work

- Create `goal_onboarding_progress` and repository.
- Reuse first-prayer Speak/Write audio capture and temporary-audio cleanup abstractions.
- Implement exact first question and starter choices from the design.
- Implement common wizard decisions and starter-specific branching.
- End with a created Goal plus resources/actions, then navigate to Today.
- Preserve `Go to Today` escape behavior.
- Provide migration behavior for a partially completed legacy first-prayer flow: resume old flow once or restart into Goal setup without data loss; choose the least surprising path based on existing persisted stage.

### Copy

All wizard copy is checked into the reviewed content source. No provider-generated text.

### Acceptance

- new user can finish offline using prepared content;
- interrupted flow resumes after process death;
- Speak/Write paths survive permission denial and recovery;
- 200% text scale and small phones remain usable;
- no technical/provider language appears in spiritual UI.

## Tranche 3 — Goals navigation and contextual prayer resources

**Goal:** Make Goals the second primary destination and demote the prayer library from primary IA.

### Work

- Replace shell `Prayers` destination with `Goals` and `/goals` routes.
- Add Goal list/detail/edit/archive/pause surfaces.
- Keep prayer detail routes as secondary resources.
- Add contextual `Add prayer` / `Add Scripture` / `Add Voice Tablet` / `Add reminder` actions from Goal detail.
- Remove prayer-library filtering complexity from new-user activation.
- Add an upgrade prompt for existing beta users with a Today prayer: `Keep this under a Goal` with `Grow closer to God` suggested but not silently created.

### Acceptance

- existing saved prayers/reminders remain reachable;
- direct prayer deep links continue to resolve;
- navigation state survives tab switching;
- Goal is the organizing context, not a duplicate copy of prayer data.

## Tranche 4 — Today Goal composer

**Goal:** Make Today answer what needs attention now across Goals.

### Work

- Add application service that merges due Goal actions, linked prayer resources, existing reminder occurrences and relevant accountability items.
- Group by Goal.
- Generalize old `today_prayers` rendering without immediately dropping the table.
- Support explicit user ordering of active Goals.
- Add action event completion/retraction.
- Limit default visible items to the smallest useful set.

### Acceptance

- Today is fully useful offline;
- no percentage, streak or score;
- action completion survives reopen;
- timezone/day rollover is deterministic;
- existing prayer Today behavior does not regress during migration.

## Tranche 5 — Return and guards

**Goal:** Apply existing prayer/reminder/accountability tools to stopping behaviors without creating a separate recovery product.

### Work

- Add Goal capability/flag indicating Return is relevant; this is internal and not called `freedom-enabled` or similar.
- Add a prominent `Return` action on applicable Goal cards/details.
- Implement five-step Return flow: Move → Close the door → Return to God → Replacement → Do not hide.
- Let the user preconfigure the concrete barrier, prayer/Scripture/Voice Tablet, replacement and accountability destination.
- Add post-event `What door was still open?` Record flow.
- Build versioned guard catalogue and initial device guidance.

### Initial behavior-specific packs

1. pornography / sexual compulsion;
2. gambling;
3. nicotine/tobacco;
4. alcohol with safety gate;
5. digital distraction as a non-diagnostic behavior option.

The common engine is shared; only questions, guards and safety notices vary.

### Safety acceptance

- alcohol flow never advises abrupt unsupported cessation where dependence risk is indicated;
- tobacco flow does not discourage evidence-based cessation care;
- gambling pack points to effective self-exclusion/limits where locally applicable;
- no diagnostic claims;
- no lapse reset or shame copy.

## Tranche 6 — Human-authored content engine and AI prayer retirement

**Goal:** Remove runtime synthetic spiritual prose.

### Work

- Define editorial content schema/JSON contract with stable IDs, versions, provenance, review state and tags.
- Import existing approved library prayers into the content model without changing prayer IDs.
- Add approved Goal starter text, Return copy, guard copy, exhortations and Bible-study questions.
- Replace generated prayer selection with deterministic retrieval/ranking plus own-words Speak/Write.
- Feature-flag DeepSeek generation off.
- Preserve already accepted generated prayers as the user's saved historical content; do not rewrite them.
- Remove generation API routes/provider code/config/database request tables only after telemetry/tests show no supported flow depends on them.

### Acceptance

- clean install can complete every supported Goal without any LLM credential;
- no runtime AI dependency for user-facing spiritual text;
- provenance is inspectable for every bundled/published editorial item.

## Tranche 7 — External Circle backend and discovery/create UI

**Goal:** Replace local private pseudo-chat with the real Circle product: discover/create/configure external groups.

### Backend

- add Circle directory/provider/schedule/content-plan/report schema;
- policies for create/update/discover/join metadata;
- public/unlisted/private visibility;
- moderation/suspension state;
- cursor pagination and category filtering.

### Flutter

Replace current `CirclesScreen` with:

- category discovery: Accountability, Daily Exhortation, Bible Study;
- search/browse results;
- `Create a Circle`;
- Circle configuration detail;
- `Open Circle` handoff;
- no composer or chat history.

### Legacy local Circle migration

- detect legacy local Circles;
- offer `Keep messages as a private Record` / `Copy` / `Discard` explicitly;
- never upload old local messages to Telegram/WhatsApp automatically;
- delete old local tables only after migration coverage and at least one release-cycle compatibility window if needed.

### Acceptance

A user can discover/create a server-backed Circle without any provider automation yet, and the UI makes no claim that SoulBuddy hosts the chat.

## Tranche 8 — Telegram bot binding and Circle rhythm

**Goal:** Make Telegram the first complete automated Circle provider.

### Work

- create SoulBuddy Telegram bot and server configuration using secrets outside Git;
- implement `startgroup` binding token flow;
- keep Telegram Privacy Mode enabled by default;
- capability-detect bot membership/admin rights;
- implement outbound scheduled posts;
- optional pin/topic management only when owner explicitly grants needed admin rights;
- implement `Open Circle` deep links;
- implement membership/binding health checks from service updates without storing conversation traffic.

### Schedule kinds

- Accountability;
- Daily Exhortation;
- Bible Study;
- generic reminder.

### Accountability

Prefer private bot check-in response. Group schedule can invite a check-in; individual status is not posted publicly by default.

### Acceptance

- binding token replay fails;
- wrong user/Circle binding fails;
- webhook authenticity/secret verification is enforced;
- retries do not duplicate posts;
- bot can operate in Privacy Mode for normal schedules;
- admin-only features disappear when rights are absent;
- ordinary Telegram message bodies are not persisted/logged.

## Tranche 9 — WhatsApp provider modes

**Goal:** Support WhatsApp honestly without blocking the product on business-account eligibility.

### `whatsapp_link`

- creator stores validated `chat.whatsapp.com` invite link;
- Join/Open handoff uses the external link;
- SoulBuddy shows no `bot-managed` badge or scheduled-delivery claim;
- local creator reminders may remind the owner to post manually.

### `whatsapp_groups_api`

Implement only after a production-account capability spike confirms:

- Groups API eligibility;
- group creation/invite behavior;
- supported participant limits;
- webhook events;
- outbound group messaging;
- template/session restrictions if any;
- operational/business verification requirements.

Hide the mode behind server capability flag until verified.

### Acceptance

No user can configure an automation the production account cannot actually deliver.

## Tranche 10 — Goal ↔ Circle accountability

**Goal:** Make Circles useful from Today without reproducing conversation.

### Work

- allow a Goal to select primary Circle;
- add due accountability entry on Today;
- `Open Circle` deep link;
- Telegram private check-in option;
- optional trusted-person flow can use provider DM/contact handoff later;
- store only minimal check-in structural state when required.

### Acceptance

A Goal such as `Stop watching pornography` can show prayer, guard, next action and `Open Circle`/check-in on Today, while all conversation remains on Telegram/WhatsApp.

## Tranche 11 — Find direction path

**Goal:** Use the same Goal engine for stagnation and discernment.

### Work

- implement reviewed prompt sequence from the design;
- connect existing Record/Remember resources as optional context selected by the user;
- output one small next action where possible;
- support prayer/wait state where action is genuinely unavailable;
- periodic review asks what became clearer and what happened after the action;
- never infer divine purpose or claim God's private intent.

### Acceptance

The path works fully without AI and produces a Goal useful on Today rather than a static questionnaire result.

## Tranche 12 — Release hardening and cleanup

This redesign should not ship publicly while known release blockers remain.

### Work

- real Android release signing; no debug key in release;
- CI workflow running format/analyze/Flutter tests/Laravel tests/audit and reproducible build prerequisites;
- make RSVCE asset preparation reproducible and legally/distribution-safe for CI/release;
- production PowerSync decision/configuration made explicit or supported flows documented without misleading sync claims;
- account/profile/privacy/delete/sign-out surface completed;
- durable Laravel queue worker for scheduled Circle delivery;
- remove obsolete local Circle chat and prayer-generation code/tables only after migration compatibility passes;
- full Android/iOS/web smoke matrix.

## 5. Content plan recommendations

### 5.1 Starter Goal corpus

Human-review the initial Goal starters before coding the full UI so copy does not get invented ad hoc in widgets.

Minimum starters:

- grow closer to God;
- stop watching pornography;
- stop gambling;
- quit smoking/use of nicotine;
- reduce/stop alcohol with safety routing;
- reduce digital distraction;
- find direction;
- get through grief/difficult season;
- forgive someone;
- repair a relationship;
- pray for another person.

### 5.2 Bible study/exhortation corpus

Start small and curated. A reliable set of 30–60 exhortations and 4–6 short Bible study plans is more useful than hundreds of generic messages.

Each item must have named editorial provenance and source references.

## 6. Testing strategy

### 6.1 Flutter unit/database tests

- Goal revision/current selection;
- owner isolation;
- recurring action occurrence keys;
- Return configuration persistence;
- guard catalogue version handling;
- Goal links to each supported resource type;
- Circle capability rendering;
- legacy Circle migration/export.

### 6.2 Flutter widget/integration tests

- first Goal at phone width and 200% text;
- interrupted onboarding recovery;
- Goals shell navigation;
- Today composition with several Goals;
- Return offline;
- Circle discovery/create;
- Telegram handoff intent creation without requiring Telegram in CI;
- WhatsApp link-only honest copy;
- legacy prayer deep links.

### 6.3 Laravel tests

- Goal mutation authorization/idempotence;
- Circle directory policies;
- visibility boundaries;
- provider binding token expiry/replay/wrong-owner;
- Telegram webhook verification;
- scheduler/delivery idempotence;
- provider failure classification;
- report/suspend/delist;
- zero private body leakage to logs.

### 6.4 Contract tests

Use recorded synthetic provider fixtures rather than live provider calls in CI. Maintain a small manual staging smoke suite against the real Telegram bot and, when available, WhatsApp Groups API.

## 7. Operational/security recommendations

- Separate Telegram bot token from app `.env.example`; document secret name only.
- Rotate provider secrets without changing Circle IDs.
- Store provider chat/group IDs server-side, never as authorization proof from Flutter.
- Rate-limit binding token creation and discovery abuse.
- Verify outbound webhook/endpoint behavior against Telegram documentation on each Bot API upgrade.
- Use provider delivery IDs only for dedupe/diagnostics; do not turn them into conversation storage.
- Add scheduled-delivery health metrics: due, delivered, failed, retry age; no private message bodies.
- Build kill switches per provider and per schedule kind.

## 8. Rollout strategy

### Stage A — internal

Goals + first Goal + Today + Return behind developer flag; no navigation switch for beta users until migration tests pass.

### Stage B — closed beta

Goals becomes primary IA. Telegram Circle discovery/create can be visible with a small curated directory. WhatsApp remains link-only.

### Stage C — controlled public beta

Enable Telegram schedules/accountability after worker reliability and moderation are verified. Publish initial guard packs and direction path.

### Stage D — public launch

Only after release-signing, CI, reproducible assets, privacy/account controls, Circle moderation, schedule reliability and provider operational playbooks pass.

## 9. Definition of done for the programme

The programme is complete when:

1. the primary shell is `Today · Goals · Record · Remember · Circles`;
2. first use creates a Goal, not an isolated prayer;
3. Today is assembled around active Goals;
4. applicable Goals can use Return and configured guards offline;
5. prayers remain first-class resources but are no longer the organizing navigation concept;
6. no runtime system generates synthetic spiritual copy;
7. Circles are real discoverable/configurable external groups rather than local pseudo-chat;
8. Telegram bot binding, schedules, exhortation/Bible-study delivery and accountability work idempotently;
9. WhatsApp never claims capabilities the production account lacks;
10. existing private SoulBuddy data survives migration;
11. known store/release engineering blockers are closed and CI is a mandatory launch gate.
