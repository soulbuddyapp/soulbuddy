# Premium Formation and Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a premium offline formation path with Nuggets, the corrected full course, staged Scripture meditation, reliable Memory playback/discovery, and optional soundscapes.

**Architecture:** Keep orientation progress in the existing local repository, add a small formation catalog/progress layer for the gate and Scripture stages, and reuse the synchronized reader and bundled RSVCE source. Keep Memory audio clean while coordinating a second low-volume audited sound-bed player. Surface flagged encounters directly from the existing encounter stream instead of creating a second Altar data model.

**Tech Stack:** Flutter, Riverpod, GoRouter, audioplayers, record, PowerSync SQLite, SharedPreferences/secure local storage, bundled JSON/MP3/RSVCE SQLite assets.

---

### Task 1: Repair saved-Memory navigation and Android playback

**Files:**
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/application/audioplayers_memory_audio_player.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/presentation/audio_capture_panel.dart`
- Test: `apps/soulbuddy/test/features/remember/remember_capture_test.dart`
- Test: `apps/soulbuddy/test/features/remember/audioplayers_memory_audio_player_test.dart`

- [ ] Write tests proving save returns the created ID to navigation, double-save is blocked, a failed save preserves the draft, and both review/saved players configure media mode plus speech audio context.
- [ ] Run the focused tests and verify each new assertion fails for the missing behavior.
- [ ] Implement in-flight/error save state, direct navigation to `/remember/:id`, and explicit player configuration.
- [ ] Run the focused tests and existing Memory audio tests until green.

### Task 2: Make Altar Memories visible

**Files:**
- Modify: `apps/soulbuddy/lib/features/remember/presentation/remember_screen.dart`
- Modify: `apps/soulbuddy/lib/features/altar/presentation/altar_today_card.dart`
- Modify: `apps/soulbuddy/lib/features/record/providers/encounter_providers.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Test: `apps/soulbuddy/test/features/remember/remember_screen_test.dart`
- Test: `apps/soulbuddy/test/features/altar/altar_today_card_test.dart`

- [ ] Write widget/provider tests proving All, Altar, and Voice filters select the correct records and Today displays the newest unarchived Altar Memory with Open and Listen actions.
- [ ] Run the tests and verify the missing filters/card fail.
- [ ] Add derived encounter providers, filter controls, and an Altar Memory card that links to the existing detail route.
- [ ] Run the focused Remember, Altar, and Today tests until green.

### Task 3: Add non-destructive Memory soundscapes

**Files:**
- Create: `apps/soulbuddy/lib/features/record/audio/domain/memory_soundscape.dart`
- Create: `apps/soulbuddy/lib/features/record/audio/data/memory_soundscape_preferences.dart`
- Create: `apps/soulbuddy/lib/features/record/audio/application/memory_soundscape_coordinator.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/presentation/audio_playback_control.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/presentation/audio_capture_panel.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/providers/memory_audio_providers.dart`
- Test: `apps/soulbuddy/test/features/remember/memory_soundscape_test.dart`
- Test: `apps/soulbuddy/test/features/remember/memory_audio_playback_control_test.dart`

- [ ] Write tests for Quiet/Stillness/Flowing water selection, 15% default, 35% cap, persistence by asset ID, start/stop synchronization, and clean-source preservation.
- [ ] Run the focused tests and verify they fail because the soundscape API/UI does not exist.
- [ ] Implement the local preference and coordinator around the existing audited meditation player, then add accessible chips and a volume control to review/full playback.
- [ ] Run the focused tests and all prayer meditation tests until green.

### Task 4: Rename compact orientation content to Nuggets

**Files:**
- Modify: `apps/soulbuddy/lib/features/orientation/presentation/orientation_library_screen.dart`
- Modify: `apps/soulbuddy/lib/features/orientation/presentation/orientation_reader_screen.dart`
- Modify: `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`
- Modify: `apps/soulbuddy/assets/orientation/ASSETS.md`
- Test: `apps/soulbuddy/test/features/orientation/reader_screen_test.dart`
- Test: `apps/soulbuddy/test/features/orientation/reader_course_navigation_test.dart`

- [ ] Write tests that reject user-facing Course labels and require Nugget labels in library, reader navigation, Settings, and accessibility semantics.
- [ ] Run them and verify the old copy fails.
- [ ] Replace only user-facing labels while preserving stable internal IDs and progress keys.
- [ ] Run all orientation/onboarding tests until green.

### Task 5: Add orientation completion and Today formation routing

**Files:**
- Create: `apps/soulbuddy/lib/features/formation/application/formation_next_step.dart`
- Create: `apps/soulbuddy/lib/features/formation/providers/formation_providers.dart`
- Create: `apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart`
- Modify: `apps/soulbuddy/lib/features/orientation/data/orientation_progress_repository.dart`
- Modify: `apps/soulbuddy/lib/features/orientation/providers/orientation_providers.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/formation/formation_next_step_test.dart`
- Test: `apps/soulbuddy/test/features/formation/formation_today_card_test.dart`

- [ ] Write tests for no progress, partial progress, all-eight completion, replayed completion, missing progress, and deterministic first-unfinished routing.
- [ ] Run them and verify the formation types/providers are absent.
- [ ] Implement a combined progress snapshot and Today card that routes to the first unfinished Nugget, then Scripture after all eight complete.
- [ ] Run focused formation and Today tests until green.

### Task 6: Produce and ship the corrected full course

**Files:**
- Create: `apps/soulbuddy/assets/orientation/full-course.mp3`
- Create: `apps/soulbuddy/assets/orientation/full-course.json`
- Modify: `apps/soulbuddy/assets/orientation/catalog.json`
- Modify: `apps/soulbuddy/lib/features/orientation/domain/orientation_course.dart`
- Modify: `apps/soulbuddy/lib/features/orientation/presentation/orientation_library_screen.dart`
- Modify: `scripts/orientation/verify_assets.py`
- Create: `.artifacts/orientation/full-course/script.txt`
- Create: `.artifacts/orientation/full-course/production-metadata.json`
- Test: `apps/soulbuddy/test/features/orientation/full_course_test.dart`

- [ ] Write an asset test requiring the full item to be optional, excluded from the eight-Nugget completion gate, and free of both retired phrases.
- [ ] Run it and verify the full asset is absent.
- [ ] Build the corrected script from the source transcript, synthesize/assemble the motivational voice with exact word boundaries, and create a synchronized transcript JSON.
- [ ] Add a separate **Read or listen to the full course** library entry without changing Nugget progress IDs.
- [ ] Run the asset verifier, decode the full MP3 with FFmpeg, and run all reader tests.

### Task 7: Add the curated Scripture journey

**Files:**
- Create: `apps/soulbuddy/assets/formation/scripture_journey.json`
- Create: `apps/soulbuddy/lib/features/formation/domain/formation_reading.dart`
- Create: `apps/soulbuddy/lib/features/formation/data/formation_progress_repository.dart`
- Create: `apps/soulbuddy/lib/features/formation/presentation/formation_reading_screen.dart`
- Modify: `apps/soulbuddy/lib/features/scripture/data/scripture_repository.dart`
- Modify: `apps/soulbuddy/lib/features/scripture/data/sqlite_scripture_repository.dart`
- Modify: `apps/soulbuddy/lib/features/formation/providers/formation_providers.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Test: `apps/soulbuddy/test/features/formation/formation_reading_test.dart`
- Test: `apps/soulbuddy/test/features/scripture/sqlite_scripture_repository_test.dart`

- [ ] Write domain/source tests for all 13 ordered stages, valid verse bounds, RSVCE extraction, exact range display, completion advancement, replay, and optional sound.
- [ ] Run them and verify the catalog/range API is absent.
- [ ] Add reviewed static metadata, a ranged Scripture query, local stage progress, and a reading screen with provenance, prompt, sound choices, and completion action.
- [ ] Run all formation and Scripture tests until green.

### Task 8: Connect optional prayer, reflection, and practical seeds

**Files:**
- Create: `apps/soulbuddy/lib/features/formation/domain/formation_practice.dart`
- Create: `apps/soulbuddy/lib/features/formation/presentation/formation_practice_sheet.dart`
- Modify: `apps/soulbuddy/lib/features/orientation/presentation/orientation_reader_screen.dart`
- Modify: `apps/soulbuddy/lib/features/formation/presentation/formation_reading_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/goals/providers/goal_providers.dart`
- Test: `apps/soulbuddy/test/features/formation/formation_practice_test.dart`

- [ ] Write tests proving prompts are reviewed/static, actions are editable, saving is explicit, duplicate creation is prevented, and sensitive reflections stay out of automatic recall by default.
- [ ] Run them and verify the practice surface is absent.
- [ ] Implement one progressive sheet that routes prayer to reviewed content, reflection to Remember, and an editable seed to the existing Goal action flow.
- [ ] Run formation, Goals, Remember, and Today tests until green.

### Task 9: Verify, install, and clean the device test record

**Files:**
- Modify if needed: `README.md`
- Create: `.artifacts/orientation/premium-formation-verification.json`
- Create: `.artifacts/orientation/soulbuddy-latest-android.apk`

- [ ] Run `dart format --output=none --set-exit-if-changed lib test integration_test` and `flutter analyze` in `apps/soulbuddy`.
- [ ] Run the complete Flutter test suite and the orientation asset verifier.
- [ ] Build the Android APK, install it without clearing app data, and exercise record → review → save → immediate playback → Altar → Today on device.
- [ ] Archive the benign diagnostic Memory created on 2026-09-09, confirm the user’s existing Memories remain untouched, and capture only non-sensitive verification facts.
- [ ] Verify small/large text, dark/light mode, reduced motion, portrait/landscape, Back behavior, offline launch, and audio interruption.
- [ ] Copy the final APK to `.artifacts/orientation/soulbuddy-latest-android.apk` and record its SHA-256.
