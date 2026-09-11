# Sacred Hour Meditation Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Sacred Hour from prayer directly into contextual meditation, make its Today audio control persistent and reliable, and link daily prayer to the full Scripture chapter.

**Architecture:** The session controller owns the transition after durable prayer recording. The Today card owns a short-lived, injectable audio player and derives labels from explicit card state. Daily Scripture preserves catalogued chapter coordinates and opens the existing bundled Scripture reader.

**Tech Stack:** Flutter, Riverpod, GoRouter, audioplayers, Flutter widget tests.

---

### Task 1: Advance from prayer to meditation

**Files:**
- Modify: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_session_controller.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`

- [ ] Write a failing widget test that taps `I prayed`, expects no `Continue to work`, then expects the exact meditation heading and subtitle.
- [ ] Run `flutter test test/features/sacred_hours/sacred_hour_session_test.dart`; it must fail because recording does not change phase.
- [ ] Change `recordPrayer` so it awaits persistence, then sets `prayerRecorded: true` and `phase: SacredHourSessionPhase.work` in one notification. Remove the Continue button. Replace the work copy with the approved exact copy. Retain the prayer phase when persistence throws.
- [ ] Run the same test; it must pass.
- [ ] Commit only these three files as `feat: move sacred hour from prayer to meditation`.

### Task 2: Open contextual reflection capture from a meditation prompt

**Files:**
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`

- [ ] Write a failing callback expectation for a prompt tap: mode is `write`; prompt is the chosen prompt; title starts with the prompt and a local date.
- [ ] Run `flutter test test/features/sacred_hours/sacred_hour_session_test.dart`; it must fail because chips only select a value.
- [ ] Replace selected-chip state with a prompt callback. Build the date through `MaterialLocalizations.formatShortDate(DateTime.now())`. Stop Sacred Hour audio and push `/remember/capture` with `mode=write`, `source=sacred-hour`, `title`, and `prompt`. Keep router forwarding `initialTitle` and `initialBodyPrompt` so `RecordScreen` opens its editor form rather than the generic choice view. Remove the redundant Speak and Write action row.
- [ ] Run the same test; it must pass.
- [ ] Commit the three files as `feat: open sacred hour reflections in context`.

### Task 3: Add Today Sacred Hour play/pause controls and state-aware labels

**Files:**
- Modify: `apps/soulbuddy/lib/features/sacred_hours/data/sacred_hour_repository.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/data/powersync_sacred_hour_repository.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/providers/sacred_hour_providers.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_today_card.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_today_card_test.dart`

- [ ] Write failing tests with an injected fake `MeditationSoundBedPlayer`: an active hour says `Open`, never `Begin`; tapping the keyed audio control starts the saved bed and shows a pause icon; a completed state says `Complete`.
- [ ] Run `flutter test test/features/sacred_hours/sacred_hour_today_card_test.dart`; it must fail because the current card is stateless and lacks audio.
- [ ] Add `watchOccurrenceStatus(String id, DateTime dueAt)` to the Sacred Hour repository, implement its owner-scoped `sacred_hour_occurrences` query in the PowerSync repository, and expose the stream through a family provider.
- [ ] Make the card stateful with an optional player for tests. In `initState`, load `MeditationSoundPreferences`; play the saved bed and volume on a play tap; stop it on pause, visibility loss, and dispose. Map labels as upcoming `Begin`, active `Open`, completed `Complete`. Bind `_SacredHourTodaySection` to the occurrence-status provider so a completed active occurrence cannot present Begin.
- [ ] Run the same test; it must pass.
- [ ] Commit the three files as `feat: add sacred hour audio controls to today`.

### Task 4: Link daily prayer to the full Scripture chapter

**Files:**
- Modify: `apps/soulbuddy/lib/features/scripture/domain/daily_scripture.dart`
- Modify: `apps/soulbuddy/lib/features/scripture/presentation/daily_scripture_screen.dart`
- Test: `apps/soulbuddy/test/features/scripture/daily_scripture_screen_test.dart`

- [ ] Write a failing router-harness test that locates `Read full chapter` under the prayer and asserts its destination is `/remember/scripture/<encoded book>/<chapter>`.
- [ ] Run `flutter test test/features/scripture/daily_scripture_screen_test.dart`; it must fail because the model discards catalogued book/chapter and the action is absent.
- [ ] Require a non-empty `book` and positive `chapter` in `DailyScripture.fromJson`, expose typed getters, then add the chapter action below the daily prayer. Call the existing `_open` helper so reading audio stops before the already screen-awake destination opens.
- [ ] Run the same test; it must pass.
- [ ] Commit the three files as `feat: link daily prayer to full scripture chapter`.

### Task 5: Verify the integrated flow

**Files:**
- Modify only if verification finds a defect: `apps/soulbuddy/lib/**` and `apps/soulbuddy/test/**`

- [ ] Run `flutter test test/features/sacred_hours/sacred_hour_session_test.dart test/features/sacred_hours/sacred_hour_today_card_test.dart test/features/scripture/daily_scripture_screen_test.dart`; it must pass.
- [ ] Run `flutter analyze --no-pub lib test/features/sacred_hours test/features/scripture`; it must report no issues.
- [ ] Run `flutter build apk --debug`; it must produce an installable APK under `build/app/outputs/flutter-apk/`.
- [ ] Commit only any verification repair as `test: verify sacred hour meditation flow`.

## Self-review

- Tasks 1–4 cover prayer completion, approved meditation copy, immediate reflection capture, state-aware Sacred Hour audio, and full-chapter access.
- Each task names concrete files, a failing test, an implementation, a verification command, and a commit.
- Existing controller, player, router, reader, and model names are used consistently.
