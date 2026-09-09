# Sacred Piece Visual Guides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give SoulBuddy’s spiritual objects a single accessible icon language and add a restrained light guide to the current practice.

**Architecture:** A core `SacredPiece` enum owns icon, selected-icon, and semantic-label mapping. `SacredPieceMedallion` renders the reusable tactile visual. Existing screens choose a piece from their already-available domain type; no records or routes change.

**Tech Stack:** Flutter, Material icons, Riverpod, `flutter_test`, existing Covenant and Grace theme tokens.

---

### Task 1: Define the visual semantic contract

**Files:**
- Create: `apps/soulbuddy/lib/core/design/sacred_piece.dart`
- Create: `apps/soulbuddy/lib/core/presentation/sacred_piece_medallion.dart`
- Create: `apps/soulbuddy/test/core/design/sacred_piece_test.dart`

- [ ] **Step 1: Write the failing test.**

```dart
test('every SacredPiece has a distinct semantic label and icon', () {
  final labels = SacredPiece.values.map((piece) => piece.semanticLabel).toSet();
  final icons = SacredPiece.values.map((piece) => piece.icon).toSet();
  expect(labels, hasLength(SacredPiece.values.length));
  expect(icons, hasLength(SacredPiece.values.length));
});

testWidgets('SacredPieceMedallion exposes its piece label', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: SacredPieceMedallion(piece: SacredPiece.prayer),
  ));
  expect(find.bySemanticsLabel('Prayer'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails.**

Run: `flutter test --no-pub test/core/design/sacred_piece_test.dart`

Expected: FAIL because `SacredPiece` and `SacredPieceMedallion` do not exist.

- [ ] **Step 3: Write the minimal implementation.**

```dart
enum SacredPiece {
  today, prayer, goal, person, remember, altar,
  circle, scripture, meditation, sacredHour, orientation;
}
```

Implement a switch for the listed pieces with Material outline icons, unique semantic labels, and filled selected icons. Render a 48dp circular `Semantics` surface; selected state has a gold border and is not the only status signal. The widget exposes `decorative` to exclude purely ornamental appearances from accessibility.

- [ ] **Step 4: Run the test to verify it passes.**

Run: `flutter test --no-pub test/core/design/sacred_piece_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add apps/soulbuddy/lib/core/design/sacred_piece.dart apps/soulbuddy/lib/core/presentation/sacred_piece_medallion.dart apps/soulbuddy/test/core/design/sacred_piece_test.dart
git commit -m "feat: add sacred piece visual language"
```

### Task 2: Make navigation and Today guide the current practice

**Files:**
- Modify: `apps/soulbuddy/lib/app/router.dart:270-380`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_guidance_card.dart:1-70`
- Modify: `apps/soulbuddy/test/features/today/today_guidance_card_test.dart`
- Modify: `apps/soulbuddy/test/app/app_navigation_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
expect(find.byKey(const Key('today-guidance-piece-person')), findsOneWidget);
expect(find.byKey(const Key('nav-piece-today')), findsOneWidget);
expect(find.byKey(const Key('nav-piece-goal')), findsOneWidget);
expect(find.byKey(const Key('nav-piece-remember')), findsOneWidget);
```

- [ ] **Step 2: Run the focused test to verify failure.**

Run: `flutter test --no-pub test/features/today/today_guidance_card_test.dart test/app/app_navigation_test.dart`

Expected: FAIL because the sacred-piece keys are absent.

- [ ] **Step 3: Write the minimal implementation.**

Add `SacredPiece pieceForTodayGuidance(TodayGuidanceKey key)` and replace the raw leading icon with `SacredPieceMedallion(key: Key('today-guidance-piece-${piece.name}'), piece: piece, decorative: true)`. Add a 3dp gold leading rail to the existing card without changing action placement or copy.

Replace `_AppDestination` icon fields with `SacredPiece piece`; keep exact labels and routes. Render the piece icon in each `NavigationDestination` and add `nav-piece-<piece.name>` keys.

- [ ] **Step 4: Run the focused test to verify it passes.**

Run: `flutter test --no-pub test/features/today/today_guidance_card_test.dart test/app/app_navigation_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add apps/soulbuddy/lib/app/router.dart apps/soulbuddy/lib/features/today/presentation/today_guidance_card.dart apps/soulbuddy/test/features/today/today_guidance_card_test.dart apps/soulbuddy/test/app/app_navigation_test.dart
git commit -m "feat: guide daily practice with sacred pieces"
```

### Task 3: Identify created work, formation, and active playback

**Files:**
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart:270-390`
- Modify: `apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart`
- Modify: `apps/soulbuddy/lib/core/playback/spiritual_session_mini_player.dart:1-120`
- Modify: `apps/soulbuddy/test/features/goals/goals_screen_test.dart`
- Modify: `apps/soulbuddy/test/features/formation/formation_today_card_test.dart`
- Modify: `apps/soulbuddy/test/core/playback/spiritual_session_mini_player_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
expect(find.byKey(const Key('collection-piece-goal-active')), findsOneWidget);
expect(find.byKey(const Key('collection-piece-prayer-prayer-1')), findsOneWidget);
expect(find.byKey(const Key('formation-piece-orientation')), findsOneWidget);
expect(find.byKey(const Key('spiritual-session-piece-altar')), findsOneWidget);
```

- [ ] **Step 2: Run the focused test to verify failure.**

Run: `flutter test --no-pub test/features/goals/goals_screen_test.dart test/features/formation/formation_today_card_test.dart test/core/playback/spiritual_session_mini_player_test.dart`

Expected: FAIL because shared piece medallions are not rendered.

- [ ] **Step 3: Write the minimal implementation.**

Use `SacredPiece.goal` and `SacredPiece.prayer` in `_CreatedItemTile`; preserve row height, route, filter, sort, and reorder behavior. Put `SacredPiece.orientation` beside the current Nugget title and retain factual progress text. Convert `SpiritualSessionKind` to a `SacredPiece` in the mini player, including altar, person, memory, sacred hour, and meditation, without changing playback controls.

- [ ] **Step 4: Run the focused test to verify it passes.**

Run: `flutter test --no-pub test/features/goals/goals_screen_test.dart test/features/formation/formation_today_card_test.dart test/core/playback/spiritual_session_mini_player_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart apps/soulbuddy/lib/core/playback/spiritual_session_mini_player.dart apps/soulbuddy/test/features/goals/goals_screen_test.dart apps/soulbuddy/test/features/formation/formation_today_card_test.dart apps/soulbuddy/test/core/playback/spiritual_session_mini_player_test.dart
git commit -m "feat: mark spiritual content with sacred pieces"
```

### Task 4: Validate and package the device release

**Files:**
- Modify only when a validation failure identifies a specific defect.

- [ ] **Step 1: Run static analysis.**

Run: `flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 2: Run the full suite.**

Run: `flutter test --no-pub`

Expected: all tests pass.

- [ ] **Step 3: Build and install the release.**

```powershell
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk C:\dev\soulbuddy\.artifacts\orientation\soulbuddy-latest-android.apk -Force
adb install -r C:\dev\soulbuddy\.artifacts\orientation\soulbuddy-latest-android.apk
```

Expected: a successful release build and `Success` from Android installation, preserving local data.

