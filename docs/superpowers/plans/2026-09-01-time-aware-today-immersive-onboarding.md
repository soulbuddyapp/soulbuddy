# Time-aware Today and Immersive Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Today promote only a currently relevant Sacred Hour and turn first launch into a short, sensory, spiritually grounded guided ritual.

**Architecture:** Keep Sacred Hour retrieval unchanged and add a pure presentation policy that classifies an hour as active, soon, or hidden. Keep onboarding UI independent of Riverpod by emitting semantic sensory cues through an injected callback; `OnboardingGate` maps those cues to the existing feedback service and preferences.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test, timezone, existing CustomPainter and audio/haptic feedback infrastructure.

---

### Task 1: Today Sacred Hour prominence policy

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_today_window.dart`
- Create: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_today_window_test.dart`

- [ ] **Step 1: Write the failing pure behavior tests**

Test that a Lagos evening hour is hidden at 08:00, becomes upcoming at 21:15, is active at 22:15, and that a 23:30 hour remains active after midnight.

- [ ] **Step 2: Run the test to verify red**

Run: `flutter test test/features/sacred_hours/sacred_hour_today_window_test.dart`

Expected: FAIL because `sacred_hour_today_window.dart` and its classifier do not exist.

- [ ] **Step 3: Implement the pure classifier**

Create `SacredHourTodayWindow.classify(hour, nowUtc, leadTime: const Duration(hours: 1))` returning a value with `phase`, `startsAtUtc`, and `minutesUntil`. Calculate today and previous-day occurrences in `hour.timezone`, preserving cross-midnight behavior.

- [ ] **Step 4: Run the focused test to verify green**

Run the Task 1 test and expect all cases to pass.

### Task 2: Apply the prominence policy to Today

**Files:**
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_today_card.dart`
- Modify: `apps/soulbuddy/test/app/app_navigation_test.dart`
- Create: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_today_card_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert that a distant evening hour is absent on a morning Today screen, an upcoming hour reads `In 45 min`, and an active hour reads `Now` with `Begin`.

- [ ] **Step 2: Run the focused widget tests to verify red**

Expected: the morning test finds the current card and status labels are absent.

- [ ] **Step 3: Filter and label the card**

Classify the provider result in `_SacredHourTodaySection`; return an empty box for hidden hours. Pass the classification to `SacredHourTodayCard` so it renders `Now` or `In N min` and selects `Begin` or `Prepare` without recalculating policy.

- [ ] **Step 4: Run focused Today tests to verify green**

Run both modified test files and expect all cases to pass.

### Task 3: Semantic onboarding feedback

**Files:**
- Modify: `apps/soulbuddy/lib/core/feedback/app_feedback.dart`
- Modify: `apps/soulbuddy/lib/core/feedback/app_feedback_service.dart`
- Modify: `apps/soulbuddy/lib/core/feedback/platform_feedback_driver_io.dart`
- Modify: `apps/soulbuddy/lib/core/feedback/platform_feedback_driver_web.dart`
- Modify: `apps/soulbuddy/test/core/feedback/app_feedback_service_test.dart`

- [ ] **Step 1: Write failing feedback mapping tests**

Add `onboardingStep` and `onboardingSacredHours` intents. Expect the first to use selection haptic plus soft tap, and the second to use light haptic plus the existing sacred gentle chime asset.

- [ ] **Step 2: Run the feedback test to verify red**

Expected: compile failure because the intents and sound are absent.

- [ ] **Step 3: Add minimal enum mappings and asset paths**

Add only the two semantic intents and one `sacredGentleChime` sound enum value. Map native and web drivers to `audio/sacred_hours/sacred_gentle_chime.wav`.

- [ ] **Step 4: Run feedback tests to verify green**

Run `flutter test test/core/feedback/app_feedback_service_test.dart` and expect all mappings to pass.

### Task 4: Immersive onboarding scenes

**Files:**
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_gate.dart`
- Modify: `apps/soulbuddy/test/features/onboarding/onboarding_screen_test.dart`

- [ ] **Step 1: Write failing scene and cue tests**

Assert the four-part copy, visible `Bring / Pray / Act / Remember` rhythm, one cue per user-driven transition, Sacred Hours cue on its reveal, and completed static visuals when animations are disabled.

- [ ] **Step 2: Run onboarding tests to verify red**

Expected: old copy and no sensory cue callback cause assertions to fail.

- [ ] **Step 3: Implement the scene sequence**

Add `OnboardingSensoryCue` and an optional async callback. Replace the static scene visual with a one-shot `AnimationController`-driven natural slab painter that progressively reveals light, incised marks, and waveform response using transform/opacity-safe painting. Keep the current page controller, skip route, Sacred Hours form, large-text scroll fallback, and semantic scene labels.

- [ ] **Step 4: Map cues in `OnboardingGate`**

Read feedback preferences with defaults and emit the corresponding intent without awaiting it. Honor both the system animation setting in the screen and the saved reduced-motion preference supplied by the gate.

- [ ] **Step 5: Run onboarding tests to verify green**

Run the focused onboarding tests and expect all cases to pass without overflow.

### Task 5: Verification and cleanup

**Files:**
- Modify only files required by formatter output.

- [ ] **Step 1: Format and analyze**

Run `dart format lib test` and `flutter analyze`; expect no issues.

- [ ] **Step 2: Run focused and full tests**

Run the Sacred Hour, feedback, onboarding, and navigation tests, then `flutter test`; expect all tests to pass.

- [ ] **Step 3: Build and inspect Android**

Run `flutter build apk --debug`, launch on the connected device or emulator when available, capture Today at morning and evening test times plus all onboarding scenes, and inspect for overflow, contrast, motion, and audio/haptic behavior.

- [ ] **Step 4: Reclaim generated build space after verification**

Preserve the latest APK in `.artifacts`, run `flutter clean`, and report measured disk space before and after. Removed worktrees and build outputs are reproducible; the preserved APK remains recoverable.
