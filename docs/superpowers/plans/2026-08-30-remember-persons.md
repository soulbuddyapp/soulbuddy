# Remember and Persons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Remember the single capture/recall destination and add a local-first Persons destination for recurring prayer and memory relationships.

**Architecture:** Add a focused Persons feature with its own schema, repository, provider, scheduler, and screens. Reuse the existing memory audio stack inside a shared Remember capture coordinator, keep `/record` as a redirect, and link Persons to memories through a many-to-many join. Extend the Laravel sync mutation boundary with a dedicated handler rather than growing encounter mutation logic inline.

**Tech Stack:** Flutter, Riverpod, GoRouter, PowerSync SQLite, Android/iOS local notifications, Laravel 12, MariaDB, Pest.

---

### Task 1: Person domain, schema, and local repository

**Files:**
- Create: `apps/soulbuddy/lib/features/persons/domain/prayer_person.dart`
- Create: `apps/soulbuddy/lib/features/persons/domain/person_prayer_occurrence.dart`
- Create: `apps/soulbuddy/lib/features/persons/data/person_schema.dart`
- Create: `apps/soulbuddy/lib/features/persons/data/person_repository.dart`
- Create: `apps/soulbuddy/lib/features/persons/data/powersync_person_repository.dart`
- Create: `apps/soulbuddy/lib/features/persons/providers/person_providers.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_database.dart`
- Test: `apps/soulbuddy/test/features/persons/person_repository_test.dart`

- [ ] **Step 1: Write failing repository tests for create, update, archive, daily/weekly/weekday schedules, next due state, and idempotent `recordPrayer`.**
- [ ] **Step 2: Run `flutter test test/features/persons/person_repository_test.dart` and confirm missing type/schema failures.**
- [ ] **Step 3: Implement `PrayerPerson`, `PersonPrayerCadence`, `PersonPrayerOccurrence`, `PersonDraft`, and the three PowerSync tables `prayer_people`, `person_prayer_occurrences`, and `encounter_person_links`.**
- [ ] **Step 4: Implement owner-filtered streams and optimistic local writes using UUIDv7, UTC timestamps, local dates, device timezone, and occurrence keys shaped as `<person-id>:<yyyy-mm-dd>`.**
- [ ] **Step 5: Re-run the focused tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: add local-first prayer persons`.**

### Task 2: Laravel persistence and sync integrity

**Files:**
- Create: `services/api/database/migrations/2026_08_30_000000_create_prayer_people_tables.php`
- Create: `services/api/app/Models/PrayerPerson.php`
- Create: `services/api/app/Models/PersonPrayerOccurrence.php`
- Create: `services/api/app/Models/EncounterPersonLink.php`
- Create: `services/api/app/Domain/Sync/ApplyPersonPrayerMutation.php`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Test: `services/api/tests/Feature/Sync/PersonPrayerMutationTest.php`

- [ ] **Step 1: Write failing sync tests for owner-scoped creation, cross-owner link rejection, immutable occurrence identity, archive preservation, and idempotent replay.**
- [ ] **Step 2: Run `php artisan test --filter=PersonPrayerMutationTest` and confirm missing-table/unsupported-table failures.**
- [ ] **Step 3: Add MariaDB migrations with UUID primary keys, user foreign keys, cadence constraints, nullable local time/timezone, occurrence uniqueness, and cascade rules matching the spec.**
- [ ] **Step 4: Implement the dedicated mutation validator/writer and register its tables in `ApplySyncMutation::SUPPORTED_TABLES`.**
- [ ] **Step 5: Run the focused test and existing sync suite; confirm both pass.**
- [ ] **Step 6: Commit with `feat: sync prayer persons and memory links`.**

### Task 3: Persons navigation and daily-use screens

**Files:**
- Create: `apps/soulbuddy/lib/features/persons/presentation/persons_screen.dart`
- Create: `apps/soulbuddy/lib/features/persons/presentation/person_editor_screen.dart`
- Create: `apps/soulbuddy/lib/features/persons/presentation/person_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/test/app/app_navigation_test.dart`
- Modify: `apps/soulbuddy/test/architecture/product_invariants_test.dart`
- Test: `apps/soulbuddy/test/features/persons/persons_screen_test.dart`

- [ ] **Step 1: Write failing navigation tests for `Today · Goals · Persons · Remember · Circles` and widget tests for empty, populated, add, edit, archive, and prayer-completion states.**
- [ ] **Step 2: Run the navigation and Persons tests and confirm Record-tab/missing-screen failures.**
- [ ] **Step 3: Replace the Record shell branch with Persons, using `Icons.person_outline`, and add `/persons/new` and `/persons/:personId` routes.**
- [ ] **Step 4: Implement compact screens with required name, optional relationship, cadence choices, weekday chips, optional time, and the detail actions `I prayed for them` and `Remember something about them`.**
- [ ] **Step 5: Re-run focused tests including 200% text and small-phone layout cases.**
- [ ] **Step 6: Commit with `feat: add Persons prayer destination`.**

### Task 4: Person prayer reminder scheduling

**Files:**
- Create: `apps/soulbuddy/lib/features/persons/application/person_prayer_reminder_scheduler.dart`
- Create: `apps/soulbuddy/lib/features/persons/application/person_prayer_reminder_coordinator.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Test: `apps/soulbuddy/test/features/persons/person_prayer_reminder_scheduler_test.dart`

- [ ] **Step 1: Write failing tests for daily/weekly/weekday scheduling, timezone changes, archive cancellation, permission denial, notification payload routing, and stable notification IDs.**
- [ ] **Step 2: Run the focused scheduler test and confirm missing implementation failures.**
- [ ] **Step 3: Reuse the existing reminder gateway to schedule `Remember <name> in prayer`, with private route payload `/persons/<id>` and the platform acknowledgement action where supported.**
- [ ] **Step 4: Add a coordinator that reconciles schedules at startup, after edits, and after timezone changes without duplicating notifications.**
- [ ] **Step 5: Re-run focused tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: schedule person prayer reminders`.**

### Task 5: Merge Record into Remember with voice always available

**Files:**
- Create: `apps/soulbuddy/lib/features/remember/presentation/remember_capture.dart`
- Create: `apps/soulbuddy/lib/features/remember/presentation/forget_quickly_card.dart`
- Modify: `apps/soulbuddy/lib/features/remember/presentation/remember_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Test: `apps/soulbuddy/test/features/remember/remember_screen_test.dart`
- Test: `apps/soulbuddy/test/features/record/encounter_form_test.dart`

- [ ] **Step 1: Write failing tests for Speak/Write on Remember, `/record` redirect, expanded first-memory reflection, collapsed returning-user reflection, and microphone availability beside `What happened?`.**
- [ ] **Step 2: Run focused tests and confirm missing controls/copy/redirect failures.**
- [ ] **Step 3: Extract the existing Record state machine into `RememberCapture`, embed it in Remember, and keep `RecordScreen` as a compatibility wrapper only if route redirection cannot preserve a pending capture.**
- [ ] **Step 4: Adapt `EncounterForm` to create, review, replace, and discard a `MemoryAudioDraft` while written text remains editable. Generate a private date-based title for audio-only saves.**
- [ ] **Step 5: Add the reviewed reflection card, force it expanded for zero memories, and keep standard empty-state content within the first phone viewport.**
- [ ] **Step 6: Redirect Today capture actions and `/record` to `/remember/capture`; re-run focused tests.**
- [ ] **Step 7: Commit with `feat: make Remember the memory capture home`.**

### Task 6: Link Persons and memories

**Files:**
- Modify: `apps/soulbuddy/lib/features/record/domain/encounter_draft.dart`
- Modify: `apps/soulbuddy/lib/features/record/data/powersync_encounter_repository.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- Modify: `apps/soulbuddy/lib/features/persons/data/person_repository.dart`
- Modify: `apps/soulbuddy/lib/features/persons/data/powersync_person_repository.dart`
- Modify: `apps/soulbuddy/lib/features/persons/presentation/person_detail_screen.dart`
- Test: `apps/soulbuddy/test/features/persons/encounter_person_link_test.dart`

- [ ] **Step 1: Write failing tests for multi-person linking, owner filtering, preselection from Person detail, linked-memory display, and link cleanup after encounter deletion/archive.**
- [ ] **Step 2: Run the focused test and confirm missing link behavior.**
- [ ] **Step 3: Add `personIds` to `EncounterDraft`, transactionally write join rows after encounter ownership checks, and add optional Person chips/picker to the form.**
- [ ] **Step 4: Add `watchLinkedMemories(personId)` and render results on Person detail; route `Remember something about them` to `/remember/capture?person=<id>`.**
- [ ] **Step 5: Re-run focused repository/widget tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: connect Persons with remembered encounters`.**

### Task 7: Slice verification

**Files:**
- Modify only if verification exposes a regression.

- [ ] **Step 1: Run Flutter format, `flutter analyze`, and all Record/Remember/Persons/navigation tests.**
- [ ] **Step 2: Run the complete Flutter test suite.**
- [ ] **Step 3: Run Laravel migration tests and the complete sync feature suite.**
- [ ] **Step 4: Build Flutter web and an Android debug APK.**
- [ ] **Step 5: Commit test-proven corrections with `fix: verify Remember and Persons workflows`.**

