# Sensory Feedback and Daily Remembrance Implementation Plan

> **Execution:** Follow test-driven development for every behavior change. Keep each task independently green and request code review before integration.

**Goal:** Make SoulBuddy calm, responsive, and useful every day through semantic sensory feedback, a polished prayer reminder, typed spiritual memories, and a private daily remembrance practice.

**Architecture:** Add a device-local feedback/preferences layer behind Riverpod interfaces; evolve the encounter lineage into typed memory records with immutable revisions and append-only reflections; add a deterministic local daily-recall selector; preserve owner-scoped Laravel/PowerSync synchronization; and build focused Flutter surfaces that degrade safely on web, reduced-motion, sound-off, and offline environments.

**Stack:** Flutter 3 / Dart 3.9, Riverpod 3, GoRouter, PowerSync/SQLite, Flutter local notifications, a focused cross-platform audio player, Laravel 13 / PHP 8.3, Pest 4.

**Design:** `docs/superpowers/specs/2026-08-12-sensory-feedback-daily-remembrance-design.md`

## Task 1: Establish semantic feedback and local preferences

**Create:**

- `apps/soulbuddy/lib/core/feedback/app_feedback.dart`
- `apps/soulbuddy/lib/core/feedback/app_feedback_service.dart`
- `apps/soulbuddy/lib/core/feedback/app_feedback_preferences.dart`
- `apps/soulbuddy/lib/core/feedback/app_feedback_providers.dart`
- `apps/soulbuddy/lib/core/feedback/platform_feedback_driver.dart`
- `apps/soulbuddy/lib/core/feedback/platform_feedback_driver_io.dart`
- `apps/soulbuddy/lib/core/feedback/platform_feedback_driver_web.dart`
- `apps/soulbuddy/test/core/feedback/app_feedback_service_test.dart`
- `apps/soulbuddy/test/core/feedback/app_feedback_preferences_test.dart`

**Modify:**

- `apps/soulbuddy/lib/core/database/app_schema.dart`
- `apps/soulbuddy/pubspec.yaml`

### Steps

1. Write failing tests for semantic intents, haptic/sound preference gating, system reduced-motion precedence, web no-op behavior, driver failure isolation, immediate preference changes, and persistence after a real PowerSync database reopen.
2. Add a local-only `app_preferences` table keyed by preference name. Store only device-local booleans/values; never upload them.
3. Define `AppFeedbackIntent` values for selection, saved, prayerCompleted, warning, dismissed, and publicationEligible.
4. Implement a service that translates intents into one bounded haptic, optional sound, and a visual event. Catch driver errors so feedback never blocks the user action.
5. Configure platform audio as ambient/sonification and ensure web degrades safely.
6. Run focused tests, full Flutter tests, `flutter analyze`, and format/diff checks.

## Task 2: Create provenance-safe sound assets and reusable motion

**Create:**

- `tools/audio/generate_soulbuddy_tones.dart`
- `apps/soulbuddy/assets/audio/feedback/soft_tap.wav`
- `apps/soulbuddy/assets/audio/feedback/gentle_completion.wav`
- `apps/soulbuddy/assets/audio/feedback/publication_eligible.wav`
- `apps/soulbuddy/assets/audio/feedback/ASSET-MANIFEST.md`
- `apps/soulbuddy/lib/core/feedback/completion_feedback.dart`
- `apps/soulbuddy/test/core/feedback/completion_feedback_test.dart`
- `apps/soulbuddy/test/core/feedback/audio_asset_contract_test.dart`

**Modify:**

- `apps/soulbuddy/pubspec.yaml`

### Steps

1. Write failing asset-contract tests for exact filenames, maximum duration/size, checksum manifest, distinct hashes, and absence of forbidden Elbiblio placeholder hashes.
2. Add a deterministic generator for three restrained original tones. Document generation parameters, date, ownership, checksum, duration, and intended semantic use.
3. Generate the binary assets and register only the feedback directory in Flutter assets.
4. Write failing widget tests for completion check/ripple, one-shot motion, reduced-motion replacement, no infinite animation, semantics announcement, and the rare light-mote limit/duration.
5. Implement a reusable completion surface using Flutter-native animation. Do not add a general confetti dependency.
6. Verify focused tests, full Flutter tests, analysis, and asset size.

## Task 3: Add Sound & touch settings and dark theme

**Create:**

- `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`
- `apps/soulbuddy/lib/features/settings/presentation/sound_touch_settings.dart`
- `apps/soulbuddy/test/features/settings/sound_touch_settings_test.dart`
- `apps/soulbuddy/test/core/design/app_theme_test.dart`

**Modify:**

- `apps/soulbuddy/lib/app/app.dart`
- `apps/soulbuddy/lib/app/router.dart`
- `apps/soulbuddy/lib/core/design/app_colors.dart`
- `apps/soulbuddy/lib/core/design/app_theme.dart`

### Steps

1. Write failing tests for haptic, sound, reduced-motion, notification-status, narration-status, and Test feedback controls; persisted state; 200% text; keyboard use; and screen-reader labels.
2. Add semantic dark color tokens and `AppTheme.dark()` with contrast assertions.
3. Wire `themeMode` to platform mode while keeping sensory preferences device-local.
4. Add an unobtrusive settings route reachable from the shell without adding a sixth primary navigation destination.
5. Ensure platform reduced motion always wins over an app setting that would enable motion.
6. Verify on 375 px, tablet, web keyboard, light/dark, and 200% text test surfaces.

## Task 4: Redesign the in-app reminder focus card

**Modify:**

- `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_card.dart`
- `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`
- `apps/soulbuddy/test/features/prayers/prayer_reminder_card_test.dart`

### Steps

1. Write failing tests for scheduled time, prayer icon, ochre focus edge, primary Open action, compact completion/snooze actions, overflow Dismiss, due-count summary, and absence of prayer body.
2. Add tests proving one entrance feedback event per immutable occurrence, no repeating animation, navigation remains usable, duplicate completion remains one session, and multiple due reminders do not stack.
3. Add reduced-motion, sound-off, haptic-off, 200% text, compact viewport, screen-reader, and keyboard tests.
4. Implement the compact focus card and one-shot transition without changing occurrence identity or repository semantics.
5. Preserve five-minute Undo even if the due stream removes the card before the session write completes.
6. Verify focused/full Flutter tests and run the card on the Android emulator.

## Task 5: Complete reminder management and notification status

**Modify:**

- `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_sheet.dart`
- `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`
- corresponding reminder scheduler, repository, and widget tests

### Steps

1. Write failing tests for plain-language summary, notification status, Test reminder, pause, remove, permission denied/revoked, double-submit prevention, and timezone preservation.
2. Extend the scheduler interface with test-notification and permission/status capabilities without exposing plugin types to presentation code.
3. Keep system notification copy generic and private. Assert notification scheduling never includes prayer or memory text and never starts narration.
4. Implement pause/remove with exact owner/reminder/device scoping and recoverable generic errors.
5. Add timezone-change and daylight-saving regression tests.
6. Verify widget/unit tests and an emulator notification round trip.

## Task 6: Evolve encounters into typed memory records

**Create:**

- new Laravel migration for memory type, sensitivity, and recall fields
- new Laravel migration/model for append-only `memory_reflections`
- Flutter memory-domain types and repository contracts
- focused PowerSync and Laravel mutation tests

**Modify:**

- `apps/soulbuddy/lib/core/database/app_schema.dart`
- `apps/soulbuddy/lib/features/record/domain/encounter.dart`
- `apps/soulbuddy/lib/features/record/domain/encounter_draft.dart`
- `apps/soulbuddy/lib/features/record/data/encounter_repository.dart`
- `apps/soulbuddy/lib/features/record/data/powersync_encounter_repository.dart`
- `services/api/app/Domain/Sync/ApplySyncMutation.php`
- encounter models, migrations, factories, and tests

### Steps

1. Write migration RED tests proving legacy encounters become type Encounter and retain IDs, revisions, Altar state, links, ownership, and dates.
2. Define allowed types: encounter, promise, left_behind, revelation, scripture, person, family, lesson, testimony.
3. Add `sensitive`, recall enabled/paused, and recall interval fields. Default `left_behind` to sensitive in Flutter while requiring explicit persisted values at the sync boundary.
4. Snapshot user-authored type/sensitivity fields in immutable revisions or otherwise prove revision history remains complete.
5. Add append-only, owner-scoped reflections containing record ID, body, local date, created time, and device ID.
6. Reject unknown fields/types, cross-owner references, immutable revision overwrite, and partial malformed pairs before writes.
7. Preserve legacy encounter mutation compatibility during rollout, with deterministic validation precedence and idempotent operation replay.
8. Run focused real-PowerSync tests, focused Laravel tests, full suites, migration up/down on SQLite, and PostgreSQL structural checks.

## Task 7: Make Record and Remember daily-use ready

**Modify/Create:**

- Record type chooser and generalized memory form
- Remember search/filter controls
- memory card and detail/reflection presentation
- Record/Remember widget and golden tests

### Steps

1. Write failing tests showing every visible Record choice opens a working form; remove all `Coming soon` interactions.
2. Add option-led fields for type, title, body, date, Altar, Sensitive, and Include in daily remembrance. Keep sensitive wording out of SnackBars and semantics summaries.
3. Write failing tests for empty-state Record CTA, type/search filtering, Altar marker, sensitive excerpt masking, Return to this, and dated reflections.
4. Add saved feedback with `View in Remember` and `Record another` while preserving offline-first save.
5. Ensure 200% text, keyboard traversal, screen readers, dark mode, loading/error/offline states, and large lists work.
6. Verify persistence through explicit database close and reopen on Chrome and Android.

## Task 8: Build the deterministic daily remembrance practice

**Create:**

- `apps/soulbuddy/lib/features/remember/domain/daily_memory.dart`
- `apps/soulbuddy/lib/features/remember/data/daily_memory_repository.dart`
- `apps/soulbuddy/lib/features/remember/data/powersync_daily_memory_repository.dart`
- `apps/soulbuddy/lib/features/remember/providers/daily_memory_providers.dart`
- `apps/soulbuddy/lib/features/remember/presentation/daily_remembrance_card.dart`
- `apps/soulbuddy/lib/features/remember/presentation/daily_remembrance_screen.dart`
- repository/provider/widget tests

**Modify:**

- `apps/soulbuddy/lib/core/database/app_schema.dart`
- `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- `apps/soulbuddy/lib/app/router.dart`

### Steps

1. Write failing repository tests for local-date stability, local-midnight refresh, priority groups, paused/excluded records, interval eligibility, non-repetition, deterministic choice, choose-another, postponement, and offline reopen.
2. Store only presentation/occurrence state in a local-only daily recall table. Keep user-authored memory and reflection data synchronized.
3. Build the Recall view with original record/date, Scripture links, previous reflections, Remembered, Add what I understand now, Pray with this, and Not today.
4. Prove `Pray with this` only preselects context and still requires the existing DeepSeek disclosure before sending content.
5. Bind every action to the displayed record/date identity to prevent midnight or overlapping-write races.
6. Add lifecycle resume and bounded wall-clock resampling like the Today prayer provider.
7. Use gentle saved feedback only; assert no score, streak, failure language, particles, or confetti.
8. Verify focused/full tests and date rollover on the emulator.

## Task 9: Polish Today and navigation

**Modify:**

- `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- `apps/soulbuddy/lib/app/router.dart`
- shared presentation components and tests

### Steps

1. Write failing tests for the two useful empty-state actions, selected prayer, next relevant reminder, and one daily remembrance card.
2. Keep the page non-dashboard: no metrics, streaks, progress rings, or public counts.
3. Add navigation selection haptics once per actual branch change.
4. Verify five-destination layout at compact width and 200% text; use accessible labels/tooltips where visible labels cannot fit.
5. Add restrained loading skeletons and consistent retry/offline surfaces.
6. Run widget, golden, accessibility, and emulator checks.

## Task 10: Integrate rare publication-eligibility feedback safely

**Modify:**

- prayer-session repository/provider/presentation code
- relevant Flutter and Laravel tests

### Steps

1. Write failing tests proving eligibility is computed from exactly 40 non-retracted sessions for one owned current revision and cannot be triggered twice by duplicate occurrences or replay.
2. Emit the rare feedback only on the transition from 39 to 40, not when reopening a prayer already at 40+.
3. Show factual copy such as `You can now prepare this prayer to share` with `Not now`. Do not publish anything in this slice.
4. Add reduced-motion, sound-off, haptic-off, and screen-reader tests.
5. Assert no spiritual-value claim, score, ranking, or routine milestone animation exists.

## Task 11: Real-device and production verification

**Create/Modify:**

- Chrome integration coverage for preferences, memories, recall, and reminders
- Android integration coverage for haptics driver invocation, notification action, process restart, and daily recall
- verification scripts and concise architecture/README documentation

### Steps

1. Run Flutter analyze and the complete Flutter test suite.
2. Run Laravel Pint, complete Pest suite, Composer strict validation, and locked audit.
3. Run real Chrome integration from a clean database through Record -> Remember -> Today recall -> reflection -> restart.
4. On the Android emulator, install a fresh debug APK and verify:
   - cold launch and local database initialization;
   - light/dark themes and 200% text;
   - Record/Remember offline flow;
   - reminder permission, scheduling, delivery, snooze, completion, Undo, pause, and removal;
   - sound/haptic toggles and reduced motion;
   - process kill/restart and database reopen;
   - local-midnight recall refresh;
   - frame timing with no continuous animation.
5. Build Flutter web and Android debug/release artifacts.
6. Search bundles and logs for private fixture text, API keys, prayer bodies, memory text, and disallowed audio hashes.
7. Run `git diff --check`, inspect generated-output hygiene, and ensure `spiritual_wealth_app_framework.md` remains untouched/untracked.
8. Request independent code review. Fix every Critical and Important issue, rerun complete verification, then merge through the normal branch workflow.

## Required guardrail assertions

- Feedback failure never changes repository success/failure.
- No private body appears in notifications, logs, analytics, or semantic labels for collapsed sensitive records.
- No unverified Elbiblio asset is bundled.
- No automatic narration or ambient audio exists.
- No confetti package or infinite pulse is introduced.
- No streak, score, ranking, level, spiritual-capital counter, or shame copy appears.
- The app does not certify a revelation, covenant, or divine interpretation.
- Daily recall, recording, reflection, and preference changes work offline.
- All actions remain bound to immutable displayed identity across midnight, stream refreshes, and delayed writes.
