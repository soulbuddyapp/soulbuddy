# SoulBuddy Signature Illustration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one distinctive, framework-grounded illustration to Today without introducing visual bloat or forcing the first-use empty state to scroll.

**Architecture:** Generate one project-owned raster asset, bundle it through Flutter, and render it through a focused responsive widget inside `TodayStartGuide`. Keep image sizing and semantics in that widget while the existing Today screen continues to own navigation and data state.

**Tech Stack:** Flutter, bundled WebP/PNG asset, widget tests, Android emulator/device verification.

---

### Task 1: Generate and validate the signature asset

**Files:**
- Create: `apps/soulbuddy/assets/images/soulbuddy_olive_memorial.webp`
- Create: `apps/soulbuddy/test/core/design/signature_illustration_asset_test.dart`
- Modify: `apps/soulbuddy/pubspec.yaml`

- [ ] Write an asset contract test that expects `assets/images/soulbuddy_olive_memorial.webp`, decodes it through `rootBundle`, and asserts a non-empty payload below 500 KB.
- [ ] Run `flutter test test/core/design/signature_illustration_asset_test.dart` and confirm it fails because the asset is absent from the bundle.
- [ ] Generate the approved olive-tree-and-memorial illustration with no text, people, halos, scores, or gamification symbols.
- [ ] Isolate and compress the selected artwork as WebP while preserving visual quality on high-density phones.
- [ ] Add the asset directory to `pubspec.yaml`.
- [ ] Run the focused contract test and confirm it passes.

### Task 2: Integrate the responsive Today visual

**Files:**
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_start_guide.dart`
- Modify: `apps/soulbuddy/test/features/today/today_prayer_test.dart`

- [ ] Add widget expectations for the semantic illustration label and bundled image.
- [ ] Add a 320×640 real-shell test asserting both Today actions and the empty-state end marker remain above bottom navigation at normal text scale.
- [ ] Add a 200% text-scale test asserting no overflow and reachable actions.
- [ ] Run the focused Today tests and confirm the new illustration finders fail.
- [ ] Add a focused responsive illustration widget that uses a compact landscape composition at normal phone scale and yields space at large text sizes.
- [ ] Keep the existing minimal prayer, surrender, action, and remembrance copy unchanged.
- [ ] Run the focused Today tests and confirm they pass.

### Task 3: Verify, review, merge, and install

**Files:**
- Review all files changed in Tasks 1–2.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `flutter build web --debug` and `flutter build apk --debug`.
- [ ] Request independent code and visual-quality review; fix every Critical or Important finding with a regression test.
- [ ] Inspect Today in both light and dark themes on the Android emulator.
- [ ] Commit, fast-forward into `main`, install the exact verified APK on the connected physical device with `adb install -r`, and launch it without clearing app data.
