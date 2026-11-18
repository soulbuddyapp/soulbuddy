# SoulBuddy

SoulBuddy is a local-first Christian formation companion built around five primary destinations: **Today · Goals · Record · Remember · Circles**.

The repository contains:

- `apps/soulbuddy`: Flutter application for iOS, Android, and authenticated web.
- `services/api`: Laravel application and authoritative sync/API boundary.
- `docs/superpowers`: approved product design and implementation plans.
- `tool`: local development utilities, including RSVCE preparation.

SoulBuddy helps a person choose and pursue a Goal, respond through Today, record meaningful Encounters, remember what matters, and use prayer and Scripture as resources around that path. Spiritual copy shipped by the app is limited to Scripture with provenance, deliberately reviewed editorial content, or the person's own words. Runtime generative prayer writing is retired and no LLM credential is required or supported for prayer creation.

The current prayer flow offers deterministic reviewed prayers or **Write/Speak your own words**. Reviewed prayer assets use stable IDs plus local editorial metadata for provenance, review state, version, publication, archival state, and tags. Historical local generation-request rows remain readable only so older unfinished/accepted content can be recovered safely; new requests cannot be created, queued, dispatched, or retried.

SoulBuddy treats prayer and practice as aids to formation, not a way to earn grace or measure holiness. Product decisions should help a person respond to grace, form character, bear outward fruit, and remember what God has done. The app does not turn those aims into a spiritual score, streak, leaderboard, or extra dashboard.

## Orientation

The welcome flow and Settings include eight replayable orientation courses with bundled narration, music, and synchronized word/sentence highlighting. Listeners can change playback speed (0.5–1.5×) and text size, seek by tapping a sentence, and continue from their saved position. **Previous** and **Next** switch directly between lessons, saving the current position and opening the adjacent course paused. Manual scrolling pauses automatic following; **Follow narration** restores it. Opening a course never autoplays, and **Skip for now** keeps the existing route into Today.

Course audio and timed text live in `apps/soulbuddy/assets/orientation`; run `python scripts/orientation/verify_assets.py` to check every recording, timing range, and text span. Browser hosting must support byte-range requests for reliable audio seeking. Progress and listening preferences are stored on the device.

The proposed extension connecting courses to Goal actions, reviewed prayers, Sacred Hours, and reflection is documented in `docs/superpowers/specs/2026-09-08-course-daily-practice.md`. That practice setup is not part of the current reader implementation.

## Prepare the local RSVCE asset

```powershell
powershell -ExecutionPolicy Bypass -File tool/prepare_rsvce.ps1
```

The source defaults to `C:\dev\catholicdaily-flutter\assets\rsvce.db`. Use `-Source <path>` to select another local copy. The generated asset is ignored by Git. Preparation validates the source, preserves its 73 books and 36,083 verses, and normalizes the derived database to UTF-8 so the same indexed asset works in browser SQLite/WASM.

## Run Flutter

```powershell
Set-Location apps/soulbuddy
flutter pub get
dart run powersync:setup_web
flutter run
```

No API, PowerSync service, or AI provider is required for local recording, Goals, Scripture, reviewed prayers, or own-words prayer creation. At startup, versioned prayer/editorial assets are validated and imported idempotently into local-only SQLite tables.

When sync is configured, private records such as Goals, Encounters, personal prayers, prayer revisions, votes, Today selections, and supported practice records use the authenticated Laravel/PowerSync boundary. Reviewed/published bundled editorial prayer wording remains authoritative for its stable IDs: an unprovenanced server row with the same ID cannot silently replace reviewed wording. Canonical-only and legacy library rows remain available through normal library reads.

The Flutter build reads `SOULBUDDY_API_URL` and `SOULBUDDY_POWERSYNC_URL` at compile time. Empty values keep startup in local-only mode. There are no prayer-generation provider, model, prompt, or disclosure dart-defines.

**Every build must pass both defines.** A build without them runs normally and silently disables every server-backed capability: saved records never upload, prayer-release notices are never recorded, and nothing warns you. `AppConfig.missingConfiguration()` names the absent values, and a debug build prints them at startup, but that is a safety net rather than the mechanism — pass the defines.

`SOULBUDDY_API_URL` alone is enough for saved records to reach Laravel, because uploads are ordinary authenticated posts and need nothing from a sync service. `SOULBUDDY_POWERSYNC_URL` additionally serves records *down* to a device. Without a sync service no user activity has ever reached the server, which is why `formation_activity_events` and `sync_operations` are empty in production.

Saved personal prayers can have once, daily, or selected-day reminders at a local wall time. Reminder schedules and quiet prayer-session records sync privately, while notification enablement remains device-specific. Android and iOS notifications use only the generic text `Prayer reminder` and `Time set aside for prayer`; no prayer title, body, Encounter, Scripture, or user identifier is placed in the notification payload.

The nine bundled library prayers include synthesized offline narration and device-local daily reminders. Android reminders request the full bundled prayer as a notification sound; iOS uses the full sound when it is under 30 seconds and a short spoken cue for the longer prayer. Opening a reminder offers the full prayer, subject to the device’s sound settings. Each built-in reminder has an audio switch. Other native reminder kinds use a generic spoken cue by default when no specific sound has been selected; existing silent and device-sound selections are preserved. OS delivery and audio duration depend on device settings and require device verification.

Person prayer recordings are optional and stored on the device. They can be recorded after saving a person, played, replaced or removed; opening a person reminder can start an existing recording when sound is allowed. Recordings are not sent to notification payloads.

A saved personal prayer may also use opt-in Deepgram Aura narration. Narration is separate from prayer authorship: only the exact immutable saved-prayer revision is sent after explicit disclosure and consent, encrypted narration audio is cached privately, system notifications never play it, and playback itself never records a prayer session.

## Run Laravel

```powershell
Set-Location services/api
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

SQLite is used by default for local development and tests. Production database configuration is supplied through the standard `DB_*` environment values.

Remote sync also requires `POWERSYNC_JWT_AUDIENCE`, `POWERSYNC_JWT_KID`, and a strong base64url-encoded `POWERSYNC_JWT_SECRET` matching the PowerSync client-auth key. The issuer defaults to `APP_URL`. Credentials expire after 600 seconds; configured lifetimes must remain between 60 and 3,600 seconds.

DeepSeek is optional for ranking the server-owned, reviewed catalogue of Goal actions. Configure `DEEPSEEK_API_KEY` only in the ignored Laravel environment; provider output is restricted to exact catalogue entries and the app falls back to the same reviewed actions when the provider is unavailable. DeepSeek does not author prayers or spiritual copy. Prayer-draft routes and client prayer-generation runtime remain retired. Never commit provider or infrastructure secrets or place them in Flutter build arguments.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_integration.ps1
```

The browser script matches the installed Chrome version to the official ChromeDriver release in a temporary directory, then runs the current network-independent mobile-viewport flows:

- Encounter save/relaunch/Scripture.
- Offline audio-memory capture/recovery.
- Reviewed prayer library/Helpful/Today/action completion/database reopen.
- Saved-prayer reminder/session/Undo/database reopen.

The Android-native reminder target requires API 33+ notification permission to be granted through ADB after the freshly installed test starts. It verifies a real private, generic, actionable notification and its `I prayed this` response.

In one terminal, start the test:

```powershell
Set-Location apps/soulbuddy
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/prayer_reminder_android_test.dart
```

While it is waiting for permission, grant it from a second terminal:

```powershell
adb -s emulator-5554 shell pm grant app.soulbuddy.soulbuddy android.permission.POST_NOTIFICATIONS
```

See [the approved product design](docs/superpowers/specs/2026-08-10-soulbuddy-mvp-design.md), [the foundation plan](docs/superpowers/plans/2026-08-10-foundation-local-first-vertical-slice.md), [the prayer-library plan](docs/superpowers/plans/2026-08-11-prayer-library-practices.md), and [local-first invariants](docs/architecture/local-first.md).
