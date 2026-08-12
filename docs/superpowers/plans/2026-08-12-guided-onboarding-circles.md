# Guided Onboarding and Circles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give new users a calm guided start on Today and Prayers, and replace the Circles placeholder with a durable local-first private Circle experience.

**Architecture:** Keep presentation improvements inside focused Flutter widgets. Add a small Circle domain/repository boundary backed by owner-scoped PowerSync tables, then connect it through Riverpod and nested routes. Network-only social controls remain explicitly unavailable until their authenticated Laravel boundary exists.

**Tech Stack:** Flutter, Material 3, Riverpod, GoRouter, PowerSync/SQLite, flutter_test.

---

### Task 1: Guided Today empty state

**Files:**
- Modify: `apps/soulbuddy/test/features/today/today_prayer_test.dart`
- Create: `apps/soulbuddy/lib/features/today/presentation/today_start_guide.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`

- [ ] Add a widget test asserting one composed guide, three concrete steps, a working primary prayer action, and a working secondary Record action when both streams are empty.
- [ ] Run `flutter test test/features/today/today_prayer_test.dart` and confirm the guide assertions fail.
- [ ] Implement `TodayStartGuide` with a decorative semantic-color focal graphic, concise steps, and 48dp Material controls.
- [ ] Render the guide only when both Today streams resolve empty; retain independent retry handling.
- [ ] Run the focused tests and confirm they pass at normal and 200% text scale.

### Task 2: Progressive Prayer library

**Files:**
- Modify: `apps/soulbuddy/test/features/prayers/prayer_library_flow_test.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_intro.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_filters.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart`

- [ ] Add tests asserting filters start collapsed, expand from a labelled control, summarize active choices, and remain recoverable when no prayers match.
- [ ] Run the focused test and confirm the new finders fail.
- [ ] Add a compact framework-grounded prayer intro and a subordinate personalized-prayer action, without ranking claims.
- [ ] Place existing filters inside an accessible `ExpansionTile`-style disclosure without nested horizontal page scrolling.
- [ ] Run focused tests at phone width and 200% text scale.

### Task 3: Local-first Circle repository

**Files:**
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/circles/domain/circle.dart`
- Create: `apps/soulbuddy/lib/features/circles/domain/circle_message.dart`
- Create: `apps/soulbuddy/lib/features/circles/data/circle_repository.dart`
- Create: `apps/soulbuddy/lib/features/circles/data/powersync_circle_repository.dart`
- Create: `apps/soulbuddy/test/features/circles/powersync_circle_repository_test.dart`

- [ ] Add real-database tests for create/watch/open/send, owner isolation, validation, ordering, and persistence after reopen.
- [ ] Run the focused repository test and confirm it fails because the boundary is absent.
- [ ] Add local-only `circles`, `circle_members`, and `circle_messages` tables so the UI cannot imply cross-device delivery.
- [ ] Implement owner-scoped transactional creation and message writes with UUIDv7 identifiers and normalized timestamps.
- [ ] Run focused repository tests and ensure local-only writes create no upload CRUD.

### Task 4: Circle creation and conversation UI

**Files:**
- Create: `apps/soulbuddy/lib/features/circles/providers/circle_providers.dart`
- Replace: `apps/soulbuddy/lib/features/circles/presentation/circles_screen.dart`
- Create: `apps/soulbuddy/lib/features/circles/presentation/create_circle_sheet.dart`
- Create: `apps/soulbuddy/lib/features/circles/presentation/circle_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Create: `apps/soulbuddy/test/features/circles/circles_flow_test.dart`

- [ ] Add widget tests for the private empty guide, validated creation, list/detail navigation, offline message send, unavailable network controls, retry, and 200% text scaling.
- [ ] Run the focused widget test and confirm the UI/repository provider APIs are missing.
- [ ] Wire auto-disposed Riverpod streams through shared database and local identity providers.
- [ ] Implement the empty guide, creation sheet, Circle cards, and quiet conversation composer.
- [ ] Add `/circles/:circleId` routing while preserving top-level navigation state.
- [ ] Run focused tests and Flutter analysis.

### Task 5: Verification and physical-device delivery

**Files:**
- Modify only files required by verification findings.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test integration_test`.
- [ ] Run `flutter analyze` and `flutter test`.
- [ ] Run the repository verification script from the workspace root.
- [ ] Build `flutter build apk --debug`.
- [ ] Install with `adb -s A5CS024315010411 install -r build/app/outputs/flutter-apk/app-debug.apk`.
- [ ] Launch and inspect Today, Prayers, Circles, Circle creation, and conversation on the physical device.
- [ ] Commit only feature files and leave `spiritual_wealth_app_framework.md` untouched.
