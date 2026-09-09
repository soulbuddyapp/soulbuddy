# Personal Practice Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the confusing Goals landing page with one personal workspace for created Goals and Prayers.

**Architecture:** Keep persisted data in the existing Goal and PersonalPrayer providers. Add a small presentation-only created-item adapter in the Goals screen to merge the two provider results, filter, sort, and route rows without changing repositories.

**Tech Stack:** Flutter, Riverpod, GoRouter, flutter_test.

---

### Task 1: Define the workspace behavior with widget tests

**Files:**
- Modify: `apps/soulbuddy/test/features/goals/goals_screen_test.dart`

- [ ] **Step 1: Write failing tests**

Add provider overrides for `personalPrayersProvider` and tests that expect:

```dart
expect(find.text('My practice'), findsOneWidget);
expect(find.text('What you\'ve created'), findsOneWidget);
expect(find.text('My prayer · daily'), findsOneWidget);
```

and after selecting the Goals filter:

```dart
expect(find.text('My prayer · daily'), findsNothing);
expect(find.text('Take the next faithful step'), findsOneWidget);
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test --no-pub test/features/goals/goals_screen_test.dart`

Expected: failure because the existing screen has no merged private-prayer list or workspace controls.

### Task 2: Build the merged personal-work list

**Files:**
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart`

- [ ] **Step 1: Add presentation-only item and ordering types**

Create a private item representation that carries title, updated time, item type, route, and Goal-only status. It must merge `visibleGoalsProvider` and `personalPrayersProvider` without changing their repositories.

- [ ] **Step 2: Add filter and sort controls**

Use compact ChoiceChips for All, Goals, and Prayers and a `PopupMenuButton` for Recent, A–Z, and Goal priority. Default to Recent.

- [ ] **Step 3: Render compact merged rows**

Use one row treatment with an item-type icon and label. Keep Goal priority movement available only under Goal priority sorting.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `flutter test --no-pub test/features/goals/goals_screen_test.dart`

Expected: PASS.

### Task 3: Consolidate creation and discovery

**Files:**
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart`
- Test: `apps/soulbuddy/test/features/goals/goals_screen_test.dart`

- [ ] **Step 1: Write failing route-control tests**

Test that the single Create control exposes Goal, Prayer, Meditation, and Browse prayer library actions.

- [ ] **Step 2: Implement the Create sheet**

Use a modal bottom sheet with four 48dp ListTiles. Preserve existing routes: `/welcome/goal`, `/prayers/create`, `/prayers/meditation`, and `/prayers`.

- [ ] **Step 3: Run the focused test and verify it passes**

Run: `flutter test --no-pub test/features/goals/goals_screen_test.dart`

Expected: PASS.

### Task 4: Verify the application

**Files:**
- Modify: `apps/soulbuddy/test/features/goals/goals_screen_test.dart`

- [ ] **Step 1: Add large-text coverage for the workspace controls**

Verify the list and Create control remain scrollable at 320px width and 200% text scale.

- [ ] **Step 2: Run verification**

Run: `flutter analyze; flutter test --no-pub test/features/goals/goals_screen_test.dart; flutter test --no-pub`

Expected: no analyzer issues and a passing test suite.
