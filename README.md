# SoulBuddy

SoulBuddy is a local-first Christian spiritual companion for prayer, practical spiritual growth, and remembering meaningful encounters.

The repository contains:

- `apps/soulbuddy`: Flutter application for iOS, Android, and authenticated web.
- `services/api`: Laravel application and authoritative API.
- `docs/superpowers`: approved product design and implementation plans.
- `tool`: local development utilities, including RSVCE preparation.

The implemented slice records an Encounter locally, shows it immediately in Remember, preserves it across database reopen, marks lasting encounters as Altars, and opens indexed RSVCE Scripture on supported native targets. Laravel provides an authenticated, idempotent mutation boundary and short-lived PowerSync credentials.

## Prepare the local RSVCE asset

```powershell
powershell -ExecutionPolicy Bypass -File tool/prepare_rsvce.ps1
```

The source defaults to `C:\dev\catholicdaily-flutter\assets\rsvce.db`. Use `-Source <path>` to select another local copy. The generated asset is ignored by Git.

## Run Flutter

```powershell
Set-Location apps/soulbuddy
flutter pub get
dart run powersync:setup_web
flutter run
```

No API or PowerSync service is required for local recording. The upload connector reads `SOULBUDDY_API_URL` and `SOULBUDDY_POWERSYNC_URL` at compile time; the authentication milestone will supply its Laravel application-session token. Empty values keep startup in local-only mode.

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

Remote sync also requires `POWERSYNC_JWT_AUDIENCE` and a strong `POWERSYNC_JWT_SECRET`. The issuer defaults to `APP_URL`, and credentials expire after 600 seconds unless `POWERSYNC_JWT_TTL_SECONDS` is changed.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
Set-Location apps/soulbuddy
flutter build web --debug
```

See [the approved product design](docs/superpowers/specs/2026-08-10-soulbuddy-mvp-design.md), [the implementation plan](docs/superpowers/plans/2026-08-10-foundation-local-first-vertical-slice.md), and [local-first invariants](docs/architecture/local-first.md).
