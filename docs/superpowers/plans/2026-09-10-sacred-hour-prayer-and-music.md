# Sacred Hour prayer and music Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add purpose-aware prayer suggestions and background music to active Sacred Hours.

**Architecture:** A pure suggestion selector ranks prayer records for an hour. The existing repository saves an attached prayer from a lossless hour draft. The Sacred Hour session owns music playback and presents a focused modal for prayer selection and background sound.

**Tech Stack:** Flutter, Riverpod, GoRouter, audioplayers, flutter_test.

---

### Task 1: Prayer ranking and lossless attachment draft

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_prayer_suggestions.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/domain/sacred_hour.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_prayer_suggestions_test.dart`

- [ ] **Step 1: Write failing tests** for morning/evening/custom ordering and `SacredHourDraft.fromHour` retaining every non-prayer field.
- [ ] **Step 2: Run** `flutter test --no-pub test/features/sacred_hours/sacred_hour_prayer_suggestions_test.dart`; expect missing selector and factory errors.
- [ ] **Step 3: Implement** a pure selector and `SacredHourDraft.fromHour`.
- [ ] **Step 4: Re-run** the same test; expect all tests passing.

### Task 2: Prayer-and-music modal

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_music_sheet.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_prayer_music_sheet_test.dart`

- [ ] **Step 1: Write failing widget tests** for the suggested prayer list, attach action, add-prayer action, and the background music picker.
- [ ] **Step 2: Run** `flutter test --no-pub test/features/sacred_hours/sacred_hour_prayer_music_sheet_test.dart`; expect a missing sheet type.
- [ ] **Step 3: Implement** the modal with concise prayer and sound labels.
- [ ] **Step 4: Re-run** the test; expect it to pass.

### Task 3: Active session integration and audio cleanup

**Files:**
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`

- [ ] **Step 1: Write failing widget tests** for selecting and retaining a suggestion, choosing music, and stopping music before a prayer, reflection, or session exit.
- [ ] **Step 2: Run** `flutter test --no-pub test/features/sacred_hours/sacred_hour_session_test.dart`; expect missing controls or callbacks.
- [ ] **Step 3: Implement** repository attachment, player ownership, preference persistence, modal launch, and navigation cleanup.
- [ ] **Step 4: Re-run** the test; expect it to pass.

### Task 4: Verification and release

**Files:**
- Verify: `apps/soulbuddy/test/features/sacred_hours/`

- [ ] **Step 1: Run** the Sacred Hours, sound-preferences, and app navigation tests.
- [ ] **Step 2: Run** `flutter analyze --no-pub`.
- [ ] **Step 3: Build** `android/gradlew.bat assembleRelease`, copy the APK to `.artifacts/orientation/soulbuddy-latest-android.apk`, and install with `adb install -r`.
- [ ] **Step 4: Inspect** the active Sacred Hour on the connected Android device without changing the user’s records beyond the requested music/preference selection.
