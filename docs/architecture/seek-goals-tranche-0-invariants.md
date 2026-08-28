# Seek / Goals / Circles — Tranche 0 Architecture Invariants

**Canonical design:** `docs/superpowers/specs/2026-08-28-seek-goals-circles-design.md`  
**Implementation plan:** `docs/superpowers/plans/2026-08-28-seek-goals-circles-implementation.md`  
**Tracker:** #1, with implementation issues #2–#13

This note freezes the legacy boundaries that must not expand while SoulBuddy moves to Goals, Goal-centric Today, Return, reviewed spiritual content, and externally hosted Circles. It is an inventory and migration guard, not a second product specification.

## 1. Primary navigation invariant

Primary navigation must remain one coherent SoulBuddy product. Do not add `Recovery`, `Freedom`, `Purpose`, `Coaching`, or `Addiction` as shell destinations. Those concerns are expressed through Goals and contextual actions.

The regression guard lives at:

- `apps/soulbuddy/test/architecture/product_invariants_test.dart`

The planned shell migration from `Prayers` to `Goals` belongs to Tranche 3 / #3; Tranche 0 deliberately does not change navigation yet.

## 2. `SyntheticSpiritualContent` rule

User-facing spiritual material may come only from:

1. Scripture with reference/provenance;
2. deliberately human-authored/reviewed SoulBuddy material;
3. the user's own words.

No new runtime AI/provider path may feed prayer, exhortation, Bible-study discussion, recovery/Return, or direction/discernment copy. Existing prayer generation is frozen legacy surface and is removed only after the reviewed-content replacement is ready.

Architecture guards:

- Flutter freezes the existing direct prayer-generation runtime boundary by source allowlist.
- Laravel freezes the existing `PrayerDraftProvider` / `GeneratePrayerDraft` boundary by source allowlist.

When legacy generation files are removed in Tranche 6 / #7, shrink the allowlists in the same change. Adding a new provider surface requires an explicit architecture decision and must not be used for spiritual copy.

## 3. Prayer-generation kill switch

Two independent controls exist so an app binary is not the only safety boundary:

| Boundary | Flag | Default | Behavior when false |
| --- | --- | --- | --- |
| Flutter | `--dart-define=SOULBUDDY_PRAYER_GENERATION_ENABLED=false` | `true` during migration | `PrayerGenerationDispatcher` claims the queued request, marks it `generation_disabled`, and performs **zero** `PrayerDraftApi` calls. The background worker therefore cannot bypass the switch. |
| Laravel | `PRAYER_GENERATION_ENABLED=false` | `true` during migration | authenticated `POST /api/prayer-drafts` returns `503 {"code":"generation_disabled"}` before provider generation. New clients classify this as terminal rather than retryable. |

The flags default to `true` only to avoid breaking the still-live personalized-prayer UX before Tranche 6 replaces it. Production can disable the Laravel flag independently, and a release can additionally compile the Flutter flag off.

This switch does **not** delete or rewrite:

- accepted `personal_prayers`;
- `personal_prayer_revisions`;
- reminders/sessions/Voice Tablets/Altars linked to those prayers;
- already prepared local draft data.

Historical accepted prayers therefore keep rendering through the existing saved-prayer routes and repositories.

## 4. DeepSeek / prayer-generation entry-point inventory

### Flutter user and worker entry points

- `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart` — exposes the personalized path through `PrayerLibraryIntro`.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_intro.dart` — selects the personalized route.
- `apps/soulbuddy/lib/features/prayers/presentation/personalized_prayer_screen.dart` — gathers request/context and confirms external processing before `prepareDraft`.
- `apps/soulbuddy/lib/features/prayers/providers/personal_prayer_providers.dart` — owns the personalized controller plus generation repository/API/dispatcher/worker providers.
- `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_screen.dart` — first-prayer external-processing choice with prepared-prayer fallback.
- `apps/soulbuddy/lib/features/onboarding/providers/first_prayer_providers.dart` — creates/queues/dispatches onboarding generation requests and falls back to the bundled library.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_draft_screen.dart` — can request another generated draft; accepting an existing draft creates durable personal-prayer data.
- `apps/soulbuddy/lib/app/app.dart` — starts the prayer-generation retry worker.

### Flutter generation boundary and local persistence

- `apps/soulbuddy/lib/features/prayers/application/prayer_generation_dispatcher.dart` — single outbound dispatch boundary; Flutter kill switch is enforced here.
- `apps/soulbuddy/lib/features/prayers/application/prayer_generation_worker.dart` — retries queued requests through the dispatcher.
- `apps/soulbuddy/lib/features/prayers/data/prayer_draft_api.dart` — provider-facing API contract and safe error taxonomy.
- `apps/soulbuddy/lib/features/prayers/data/laravel_prayer_draft_api.dart` — authenticated Laravel transport.
- `apps/soulbuddy/lib/features/prayers/data/prayer_generation_repository.dart` and `powersync_prayer_generation_repository.dart` — local request lifecycle persistence.
- `apps/soulbuddy/lib/core/database/app_schema.dart` — `prayer_generation_requests` and `prayer_generation_contexts` are local-only migration-era tables.

### Laravel provider boundary

- `services/api/routes/api.php` — authenticated `POST /api/prayer-drafts` and attempt acknowledgement.
- `services/api/app/Http/Requests/GeneratePrayerDraftRequest.php` — strict request/consent/context validation.
- `services/api/app/Http/Controllers/Api/PrayerDraftController.php` — authoritative kill switch, idempotent encrypted replay cache, safe provider error mapping.
- `services/api/app/Domain/PrayerDrafts/GeneratePrayerDraft.php` — generation/validation orchestration.
- `services/api/app/Domain/PrayerDrafts/PrayerDraftProvider.php` — provider interface.
- `services/api/app/Domain/PrayerDrafts/DeepSeekPrayerDraftProvider.php` — current external provider implementation.
- `services/api/app/Providers/AppServiceProvider.php` — provider binding and prayer-draft rate limiter.
- `services/api/config/services.php` and `.env.example` — provider and kill-switch configuration.

No item above should gain new spiritual product responsibilities. Tranche 6 / #7 replaces these creation paths with deterministic selection of reviewed content and user-authored prayer paths, then removes obsolete provider code after compatibility tests pass.

## 5. Local Circle-message entry-point inventory

Current Circles are intentionally legacy, device-local pseudo-chat. Do not extend this model while #8 is pending.

### UI / application entry points

- `apps/soulbuddy/lib/features/circles/presentation/circles_screen.dart` — local Circle list/create entry and route into a Circle detail.
- `apps/soulbuddy/lib/features/circles/presentation/circle_detail_screen.dart` — renders local message history, owns the message composer, and calls `sendMessage`.
- `apps/soulbuddy/lib/features/circles/providers/circle_providers.dart` — exposes `circleMessagesProvider` and the local repository.

### Data boundary

- `apps/soulbuddy/lib/features/circles/data/circle_repository.dart` — legacy `watchMessages` / `sendMessage` contract.
- `apps/soulbuddy/lib/features/circles/data/powersync_circle_repository.dart` — owner-scoped reads from and writes to `circle_messages`; writes are explicitly `on_this_device`.
- `apps/soulbuddy/lib/core/database/app_schema.dart` — legacy `circles`, `circle_members`, and `circle_messages` are local-only tables.
- `apps/soulbuddy/test/features/circles/circle_repository_test.dart` and `circles_flow_test.dart` — preserve current local data behavior until migration coverage supersedes them.

Tranche 0 removes none of this data. Tranche 7 / #8 must first offer the explicit `Keep messages as a private Record`, copy, or discard migration before the local composer/history/table model is removed. Old message bodies must never be uploaded automatically into Telegram or WhatsApp.

## 6. Goal-first onboarding migration

New users now enter the resumable first-Goal path at `/welcome/goal`. The reviewed first question and shortcuts are:

**What would you like help with?**

- Grow closer to God
- Stop something fighting to control me
- Find direction
- Get through a difficult time
- Something else

Committed first-Goal decisions are stored locally in `goal_onboarding_progress` and the final Goal/prayer/link/actions are committed atomically. A partially completed legacy first-prayer flow takes resume precedence so existing work is not silently discarded.

Until real trusted-person/Circle linking lands, Goal onboarding does not present an accountability choice. The state machine records `not_now` internally and moves directly to the prayer/resource step. This preserves the future branch without asking the user a question whose answer would currently be discarded.

## 7. Focused onboarding / Goals CI

`.github/workflows/onboarding-goals.yml` is the narrow migration gate. It triggers only when onboarding/Goal client code, the reused onboarding speech/choice components, Goal persistence/sync boundaries, their tests, or the workflow itself changes.

The workflow runs:

- Flutter 3.35.7 on Windows, matching the repository toolchain and the existing PowerSync test helper;
- focused Dart formatting and analyzer checks for onboarding, Goals, shell/database boundaries, and the reused speech/choice components;
- onboarding/Goal architecture and feature tests;
- Laravel PHP 8.4, focused Pint including Goal migrations and the sync entrypoint, authoritative Goal sync tests, and the synthetic-content/kill-switch regressions.

This is intentionally not the complete public-release CI matrix tracked in #13.

## 8. Change rule until the migrations land

Before adding code that touches prayer generation or Circle chat, ask whether it expands one of the frozen boundaries above. If yes, implement against the target reviewed-content or external-Circle architecture instead. Existing legacy behavior may receive only compatibility, migration, security, or shutdown fixes.
