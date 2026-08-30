# Today Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dead-end empty-practice message with one factual, reviewed, state-aware next step or encouragement.

**Architecture:** Project local repository facts into a small `TodayGuidanceSnapshot`, evaluate it with a pure deterministic engine, and render one compact card below the covenant slabs. Historical misses come only from stored schedules and completions over seven completed local days; unavailable data disables the dependent rule instead of becoming a negative claim.

**Tech Stack:** Flutter, Riverpod, PowerSync SQLite, existing Today/Goal/Prayer/Remember/Altar/Circle/Persons repositories.

---

### Task 1: Pure guidance model and priority engine

**Files:**
- Create: `apps/soulbuddy/lib/features/today/domain/today_guidance.dart`
- Create: `apps/soulbuddy/lib/features/today/application/today_guidance_engine.dart`
- Test: `apps/soulbuddy/test/features/today/today_guidance_engine_test.dart`

- [ ] **Step 1: Write failing table-driven tests for due routine, two verified misses/no Circle, unexplored features, all-complete encouragement, quiet return, unstable/loading history, stable priority, and `several` for counts above three.**

```dart
test('recommends a Circle only for verified repeated misses', () {
  final card = const TodayGuidanceEngine().select(
    TodayGuidanceSnapshot(
      missedScheduledRoutineCount: 2,
      joinedCircle: false,
      usedGoals: true,
      usedPrayer: true,
      usedMemory: true,
      usedPersons: true,
    ),
  );
  expect(card?.key, TodayGuidanceKey.circleAccountability);
  expect(card?.body, 'You missed two planned routines this week. A Circle can help you stay accountable.');
});
```

- [ ] **Step 2: Run `flutter test test/features/today/today_guidance_engine_test.dart` and confirm missing-type failures.**
- [ ] **Step 3: Implement immutable fact and card values plus the exact deterministic priority order from the approved spec.**
- [ ] **Step 4: Re-run the engine tests and confirm they pass.**
- [ ] **Step 5: Commit with `feat: add deterministic Today guidance engine`.**

### Task 2: Repository-backed factual snapshot

**Files:**
- Create: `apps/soulbuddy/lib/features/today/data/today_guidance_repository.dart`
- Create: `apps/soulbuddy/lib/features/today/data/powersync_today_guidance_repository.dart`
- Create: `apps/soulbuddy/lib/features/today/providers/today_guidance_providers.dart`
- Modify: `apps/soulbuddy/lib/features/today/providers/daily_practice_providers.dart`
- Test: `apps/soulbuddy/test/features/today/today_guidance_repository_test.dart`

- [ ] **Step 1: Write failing PowerSync tests proving feature-use flags, due/completed projection, prior-seven-completed-day boundaries, schedule-only miss counting, Circle membership, and omission when a data source is unavailable.**
- [ ] **Step 2: Run the focused repository test and confirm missing implementation failures.**
- [ ] **Step 3: Implement focused SQL queries over Goals/actions/events, prayers/sessions, daily memories, Persons/occurrences, Altars, and Circle membership. Keep user content out of the returned snapshot.**
- [ ] **Step 4: Extend daily practice availability so actual due Goal actions and Person prayers can produce `act`/`pray` without treating a Circle as a practice.**
- [ ] **Step 5: Re-run repository and daily-practice provider tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: project factual Today guidance state`.**

### Task 3: Compact guidance card and covenant-slab empty behavior

**Files:**
- Create: `apps/soulbuddy/lib/features/today/presentation/today_guidance_card.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/core/presentation/covenant_slabs.dart`
- Modify: `apps/soulbuddy/test/features/today/today_screen_test.dart`
- Modify: `apps/soulbuddy/test/core/presentation/covenant_slabs_test.dart`

- [ ] **Step 1: Write failing widget tests proving the old copy is absent, exactly one guidance card renders, its route is correct, its content updates after completion, screen-reader empty semantics remain factual, and the standard small-phone empty state does not require scrolling.**
- [ ] **Step 2: Run the focused widget tests and confirm old-copy/missing-card failures.**
- [ ] **Step 3: Render a compact covenant-grace card beneath the slabs with one icon, short reviewed title/body, and one action. Remove visible `No practices available today`; retain `No daily routines are set` semantics.**
- [ ] **Step 4: Route each stable guidance key to the correct internal destination and emit only existing preference-respecting selection feedback.**
- [ ] **Step 5: Re-run widget tests at normal and 200% text scale and confirm they pass.**
- [ ] **Step 6: Commit with `feat: guide the next useful step on Today`.**

### Task 4: Full feature-state transitions

**Files:**
- Modify: `apps/soulbuddy/test/features/today/today_screen_test.dart`
- Modify: `apps/soulbuddy/test/features/today/today_guidance_repository_test.dart`

- [ ] **Step 1: Add failing integration tests for Goal/prayer/memory/Person/Circle creation removing the matching unexplored prompt and for all-due completion producing `Remain close`.**
- [ ] **Step 2: Run the integration tests and confirm any missing invalidation/reactivity failures.**
- [ ] **Step 3: Add only the provider invalidations or stream watches required for immediate recomputation; do not add a recommendation-history or dismissal table.**
- [ ] **Step 4: Re-run focused tests and confirm transitions occur without restart.**
- [ ] **Step 5: Commit with `fix: keep Today guidance reactive`.**

### Task 5: Slice verification

**Files:**
- Modify only if verification exposes a regression.

- [ ] **Step 1: Run Flutter format, `flutter analyze`, Today/core presentation tests, and product invariant tests.**
- [ ] **Step 2: Run the complete Flutter test suite.**
- [ ] **Step 3: Build Flutter web and an Android debug APK.**
- [ ] **Step 4: On an Android emulator, verify new-user, missed-routine, unexplored-Persons, Circle-accountability, and completed-routines states with no overflow or required empty-state scrolling.**
- [ ] **Step 5: Commit test-proven corrections with `fix: verify state-aware Today guidance`.**

