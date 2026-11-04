# Background recording playback and sync migration plan

> **For agentic workers:** Execute the tasks in order and verify each before release.

**Goal:** Preserve the live app, support Android system playback controls, and rehearse a private MySQL 8 PowerSync cutover.

**Architecture:** Keep the current playback coordinator and in-app controls. Publish only recording-backed sessions to a foreground media service, route system commands through the existing capture-aware session controller, and use generic notification metadata. Rehearse database import and ownership projection in isolated, memory-backed MySQL before considering a production switch.

**Tech Stack:** Flutter, Riverpod, audio_service, Android media sessions, Laravel, MySQL 8, PowerSync.

---

### Task 1: Reconcile the live application and release candidate

**Files:** conflicted files from `git diff --name-only --diff-filter=U`; existing app and API tests.

- [ ] Preserve inline recording and existing written data while restoring the live prayer-release and guidance features.
- [ ] Run `flutter analyze --no-pub` and the affected Flutter and Laravel tests; resolve behavior regressions rather than dropping tests.
- [ ] Review the combined sync transaction for rollback on every rejection.

### Task 2: Add private system playback controls

**Files:** `apps/soulbuddy/lib/core/playback/`, the recording and prayer playback controls, Android manifest and activity, and focused playback tests.

- [ ] Test session start, pause, resume, stop, seek, microphone capture and generic lock-screen metadata with a fake transport.
- [ ] Attach the system media service to the existing recording session and preserve the in-app player; keep microphone capture authoritative over playback.
- [ ] Test background transitions and real Android notification controls, including speaker, headphones and interruptions.

### Task 3: Prepare and rehearse the MySQL cutover

**Files:** `services/api/database/powersync/2026_11_03_010000_add_powersync_owner_projection.php`, `services/api/tests/Release/PowerSyncOwnerProjectionRehearsal.php`, `infra/powersync/self-hosted.sync-rules.yaml`, and deployment notes. Apply the projection explicitly with `php artisan migrate --force --path=database/powersync` only after the MySQL cutover prerequisites in the runbook are met.

- [ ] Check the migration's complete owner mapping, immutable identity guard, partial-failure handling and rollback restriction against a synthetic MySQL 8 database.
- [ ] Rehearse a private source snapshot, rewrite trigger definers, compare row fingerprints in UTC, apply both migrations, and test two-account initial and live replication.
- [ ] Document the cutover's write freeze, backup restoration, service credentials, source replication settings and post-cutover checks.

### Task 4: Verify and publish the internal release

**Files:** `.github/workflows/publish-playstore.yml` and release documentation.

- [ ] Run the final full Flutter and API suites without overlapping source changes, then verify the exact pull-request commit and platform checks.
- [ ] Verify a supported sync endpoint and private rules, complete Android listening checks and perform the iOS simulator check.
- [ ] Publish the verified signed bundle to Google Play internal testing and confirm its version and track.
