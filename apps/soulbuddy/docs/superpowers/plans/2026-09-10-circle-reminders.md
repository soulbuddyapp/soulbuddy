# Circle Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schedule a daily local reminder for a Circle and open that Circle when the notification is selected.

**Architecture:** A secure-storage repository owns device-local reminder settings. A Circle reminder coordinator translates those settings into shared native notification requests and emits route events. The Circle detail control edits settings and the app listens for route events.

**Tech Stack:** Flutter, Riverpod, flutter_secure_storage, flutter_local_notifications, timezone, flutter_test.

---

### Task 1: Persist Circle reminder settings

**Files:**
- Create: `lib/features/circles/domain/circle_reminder.dart`
- Create: `lib/features/circles/data/circle_reminder_repository.dart`
- Test: `test/features/circles/circle_reminder_repository_test.dart`

- [ ] Write a failing test that saves a Circle time, reloads it, and removes it.
- [ ] Run `flutter test --no-pub test/features/circles/circle_reminder_repository_test.dart` and confirm it fails because the repository does not exist.
- [ ] Implement validated JSON serialization, serialized writes, and change notifications.
- [ ] Re-run the repository test and confirm it passes.

### Task 2: Schedule and route Circle notifications

**Files:**
- Create: `lib/features/circles/application/circle_reminder_coordinator.dart`
- Modify: `lib/features/prayers/application/prayer_reminder_scheduler.dart`
- Modify: `lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Modify: `lib/features/circles/providers/circle_providers.dart`
- Modify: `lib/app/app.dart`
- Test: `test/features/circles/circle_reminder_coordinator_test.dart`
- Test: `test/app/app_navigation_test.dart`

- [ ] Write failing tests for daily scheduling, cancellation after removal, and a notification response that emits a Circle identifier.
- [ ] Run the Circle coordinator test and confirm it fails because the coordinator and notification kind do not exist.
- [ ] Add the Circle notification kind, native `Open Circle` action, local-time scheduler, Riverpod providers, and application route listener.
- [ ] Re-run the coordinator and navigation tests and confirm they pass.

### Task 3: Add the Circle reminder control

**Files:**
- Create: `lib/features/circles/presentation/circle_reminder_sheet.dart`
- Modify: `lib/features/circles/presentation/circle_detail_screen.dart`
- Test: `test/features/circles/circles_flow_test.dart`

- [ ] Write a failing widget test that opens the Circle reminder sheet and displays the selected daily time.
- [ ] Run `flutter test --no-pub test/features/circles/circles_flow_test.dart` and confirm it fails because the control is absent.
- [ ] Add the concise time picker, saved-time label, and removal action.
- [ ] Re-run the Circle flow test and confirm it passes.

### Task 4: Verify and package

**Files:**
- Verify: `test/features/circles/`, `test/app/app_navigation_test.dart`

- [ ] Run Circle and app-navigation tests, then `flutter analyze --no-pub`.
- [ ] Build `android\\gradlew.bat assembleRelease`, copy the APK to `.artifacts/orientation/soulbuddy-latest-android.apk`, and install it with `adb install -r` when the connected device is available.
- [ ] Commit the implementation with `feat: add Circle reminders`.
