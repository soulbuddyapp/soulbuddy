# SoulBuddy

SoulBuddy is a local-first Christian spiritual companion for prayer, practical spiritual growth, and remembering meaningful encounters.

The repository contains:

- `apps/soulbuddy`: Flutter application for iOS, Android, and authenticated web.
- `services/api`: Laravel application and authoritative API.
- `docs/superpowers`: approved product design and implementation plans.
- `tool`: local development utilities, including RSVCE preparation.

The implemented slices record an Encounter locally, preserve it across database reopen, mark lasting encounters as Altars, and open indexed RSVCE Scripture on mobile and web. They also provide a bundled prayer library, private Helpful choices, a prayer and optional action for Today, and action completion that survives a real local database reopen. Laravel provides an authenticated, idempotent mutation boundary, canonical community Helpful totals, and short-lived PowerSync credentials.

SoulBuddy treats prayer and practice as aids to formation, not a way to earn grace or measure holiness. Product decisions should help a person respond to grace, form character, bear outward fruit, and remember what God has done. The app does not turn those aims into a spiritual score, streak, leaderboard, or extra dashboard.

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

No API or PowerSync service is required for local recording or prayer use. At startup, the versioned prayer asset is validated and imported idempotently into a local-only SQLite table. Helpful choices and the dated Today selection are written to the device database immediately, so filtering, selecting, completing an action, and reopening the app remain available offline.

When sync is configured, canonical Laravel prayer rows replace bundled rows with the same stable UUID, and their server-derived Helpful totals control library ordering. Votes and Today selections remain private to the authenticated user. The upload connector reads `SOULBUDDY_API_URL` and `SOULBUDDY_POWERSYNC_URL` at compile time; the authentication milestone will supply its Laravel application-session token. Empty values keep startup in local-only mode.

## Run Laravel

```powershell
Set-Location services/api
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

SQLite is used by default for local development and tests. Production is designed for PostgreSQL; set the standard `DB_*` environment values before migrating.

Remote sync also requires `POWERSYNC_JWT_AUDIENCE`, `POWERSYNC_JWT_KID`, and a strong base64url-encoded `POWERSYNC_JWT_SECRET` matching the PowerSync client-auth key. The issuer defaults to `APP_URL`. Credentials expire after 600 seconds; configured lifetimes must remain between 60 and 3,600 seconds.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_integration.ps1
```

The browser script matches the installed Chrome version to the official ChromeDriver release in a temporary directory, then runs two network-independent flows at a mobile viewport: Encounter save/relaunch/Scripture and prayer filter/Helpful/Today/action completion/database reopen.

See [the approved product design](docs/superpowers/specs/2026-08-10-soulbuddy-mvp-design.md), [the foundation plan](docs/superpowers/plans/2026-08-10-foundation-local-first-vertical-slice.md), [the prayer-library plan](docs/superpowers/plans/2026-08-11-prayer-library-practices.md), and [local-first invariants](docs/architecture/local-first.md).
