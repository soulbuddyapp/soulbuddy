# SoulBuddy Living Vine Visual Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a reusable, accessible Living Vine design system and apply it consistently to the four primary SoulBuddy journeys without gamification or layout bloat.

**Architecture:** Extend the existing primitive/semantic/component design layers with botanical roles, then render a small set of contextual compositions through one code-native Flutter painter and wrapper widget. Primary screens consume named variants while retaining their existing data, navigation, and business logic.

**Tech Stack:** Flutter Material 3, Dart `CustomPainter`, widget/golden-free structural tests, Android emulator and physical-device verification.

---

### Task 1: Add botanical design tokens

**Files:**
- Modify: `apps/soulbuddy/lib/core/design/app_colors.dart`
- Create: `apps/soulbuddy/lib/core/design/living_vine_tokens.dart`
- Modify: `apps/soulbuddy/test/core/design/app_theme_test.dart`

- [ ] Add a failing theme test that expects light and dark botanical semantic roles to remain distinct from the canvas and readable beside their intended surfaces.
- [ ] Run `flutter test test/core/design/app_theme_test.dart` and confirm the new token API is missing.
- [ ] Add primitive blossom and fruit values, semantic botanical roles, and component measurements without introducing raw colors in feature widgets.
- [ ] Run the focused theme test and confirm it passes.
- [ ] Commit with `feat: add Living Vine design tokens`.

### Task 2: Build the accessible Living Vine primitive

**Files:**
- Create: `apps/soulbuddy/lib/core/presentation/living_vine.dart`
- Create: `apps/soulbuddy/test/core/presentation/living_vine_test.dart`

- [ ] Write failing widget tests for the four named variants, decorative semantics exclusion, stable compact sizing, dark theme rendering, and reduced-motion final-state behavior.
- [ ] Run `flutter test test/core/presentation/living_vine_test.dart` and confirm it fails because the component does not exist.
- [ ] Implement `LivingVine` and a focused painter with deterministic curves, tapered-looking layered strokes, and restrained leaves, blossoms, fruit, memorial, and intertwined variants.
- [ ] Keep animation optional, brief, and disabled through `MediaQuery.disableAnimations`.
- [ ] Run the focused tests and confirm they pass.
- [ ] Commit with `feat: add Living Vine visual primitive`.

### Task 3: Apply the system to Today and Prayers

**Files:**
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_start_guide.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_intro.dart`
- Modify: `apps/soulbuddy/test/features/today/today_prayer_test.dart`
- Modify: `apps/soulbuddy/test/features/prayers/prayer_library_flow_test.dart`

- [ ] Add failing tests that expect contextual vine variants while preserving current calls to action and filter behavior.
- [ ] Add compact-shell and 200% text assertions proving decorative elements do not create overflow or hide primary actions.
- [ ] Run the focused Today and Prayer tests and observe the intended failures.
- [ ] Add a branch-led Today header and a restrained leafy Prayer introduction, yielding decorative height at large text scale.
- [ ] Run the focused suites and confirm they pass.
- [ ] Commit with `feat: bring Living Vine to daily prayer`.

### Task 4: Apply memorial and interwoven variants

**Files:**
- Modify: `apps/soulbuddy/lib/features/remember/presentation/remember_screen.dart`
- Modify: `apps/soulbuddy/lib/features/circles/presentation/circles_screen.dart`
- Modify: `apps/soulbuddy/test/features/record/record_remember_flow_test.dart`
- Modify: `apps/soulbuddy/test/features/circles/circles_flow_test.dart`

- [ ] Add failing tests for the memorial and interwoven variants in empty and populated flows.
- [ ] Assert existing search, create, privacy, and navigation behavior remains reachable at compact width and large text.
- [ ] Run the focused suites and observe the new visual expectations fail.
- [ ] Add one memorial composition to Remember and one interwoven composition to Circles without decorating each record or Circle card.
- [ ] Run the focused suites and confirm they pass.
- [ ] Commit with `feat: extend Living Vine through memory and circles`.

### Task 5: Verify, review, merge, and install

**Files:**
- Review all files changed in Tasks 1-4.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze` and the complete `flutter test` suite.
- [ ] Run `flutter build web --debug` and `flutter build apk --debug`.
- [ ] Inspect Today, Prayers, Remember, and Circles in light/dark themes and on a compact Android emulator, including 200% text and reduced motion.
- [ ] Review for raw colors, duplicated semantics, excessive decorative height, scroll regressions, painter repaint churn, and any accidental progress metaphor.
- [ ] Fix each Critical or Important finding through a failing regression test.
- [ ] Merge the verified branch into `main`, install the exact APK on the connected physical device with `adb install -r`, and launch it without clearing app data.

