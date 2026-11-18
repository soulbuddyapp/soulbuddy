# Prayer Reminder Audio Implementation Plan

**Goal:** Add usable default prayer narration, supportive reminder sound, and optional person-prayer recordings.

**Architecture:** Bundle versioned narration keyed by approved prayer IDs and exact text hashes. Extend the existing private playback and notification infrastructure without transmitting prayer content in notification payloads. Add device-private recordings using existing capture and storage abstractions. Android and iOS playback capabilities are handled separately.

**Tech stack:** Flutter, Riverpod, audioplayers, existing audio capture, flutter_local_notifications, Android and iOS native APIs.

1. Inventory all built-in prayer sources; write coverage and text-hash tests, synthesize reviewed body text to offline audio using the existing voice workflow, and add a provenance manifest.
2. Add a reliable play/pause/stop control for built-in prayers and connect it to the appropriate reminder/session routes, verifying stale content and player failures.
3. Add supporting generic reminder sounds for all reminder kinds while respecting existing device sound settings and silent configurations; test the native request mapping and notification payload privacy.
4. Build optional person prayer recording using existing capture/private-store components, with preview, replacement, deletion and failure-safe saves; link playback to person reminder entry.
5. Schedule full built-in prayer audio as native Android notification sounds. Package recordings under 30 seconds for iOS and use the short cue for the longer prayer; start full playback after an explicit reminder open when device audio permits. Include per-prayer sound control. Verify timing, sound duration, permissions, interruption and stop behavior on actual devices; report platform limits.
6. Run focused tests, static analysis and platform builds; verify generated audio against source and review the resulting UX. Do not overwrite unrelated user changes.
