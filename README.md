# SoulBuddy

SoulBuddy is a local-first Christian spiritual companion for prayer, practical spiritual growth, and remembering meaningful encounters.

The repository contains:

- `apps/soulbuddy`: Flutter application for iOS, Android, and authenticated web.
- `services/api`: Laravel application and authoritative API.
- `docs/superpowers`: approved product design and implementation plans.
- `tool`: local development utilities, including RSVCE preparation.

The implemented slices record an Encounter locally, preserve it across database reopen, mark lasting encounters as Altars, and open indexed RSVCE Scripture on mobile and web. They also provide a bundled prayer library, private Helpful choices, a prayer and optional action for Today, and action completion that survives a real local database reopen. A guided flow can formulate a private prayer request from explicit choices and selected Encounter or RSVCE context, queue it offline, prepare a guarded DeepSeek draft after reconnect, and let the user edit it before saving or using it for Today. Laravel provides an authenticated, idempotent mutation boundary, canonical community Helpful totals, short-lived PowerSync credentials, and the server-owned prayer-draft policy.

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

Personalized requests and their selected context snapshots remain local-only until the user confirms the DeepSeek disclosure. An offline confirmation stays queued in the local database and resumes from the same request after reconnect or restart. Only the confirmed choices and explicitly selected records are sent; raw request, context, draft, and token values must never be written to logs or test diagnostics. Accepted prayers, immutable revisions, their Encounter/Scripture links, and typed Today selections are private synchronized records.

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

### Configure DeepSeek safely

Revoke and rotate any API credential that has ever been pasted into chat, source code, a shell command, or logs. Put only the rotated DeepSeek credential in the ignored `services/api/.env`; never commit it or paste it into a command whose arguments may be recorded.

```dotenv
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=replace-with-a-rotated-key
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-flash
PRAYER_DRAFT_PROMPT_VERSION=1
PRAYER_DRAFT_DISCLOSURE_VERSION=deepseek-1
```

The Flutter build should use matching non-secret configuration and the authenticated Laravel base URL:

```powershell
flutter run `
  --dart-define=SOULBUDDY_API_URL=http://10.0.2.2:8000 `
  --dart-define=SOULBUDDY_PRAYER_DRAFT_PROVIDER=deepseek `
  --dart-define=SOULBUDDY_PRAYER_DRAFT_DISCLOSURE_VERSION=deepseek-1
```

For a local authenticated smoke check, seed a development user and application session first. Use one synthetic request only, and report status, latency, and provider token counts—never the request, selected context, generated prayer, session token, or provider key. Live provider calls are deliberately excluded from CI.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_integration.ps1
```

The browser script matches the installed Chrome version to the official ChromeDriver release in a temporary directory, then runs three network-independent flows at a mobile viewport: Encounter save/relaunch/Scripture; prayer filter/Helpful/Today/action completion/database reopen; and guided personalized prayer/offline queue/authenticated reconnect/edit/accept/Today/database reopen.

Run the personalized flow on the Android 14 emulator as well:

```powershell
Set-Location apps/soulbuddy
flutter test integration_test/personalized_prayer_flow_test.dart -d emulator-5554
```

See [the approved product design](docs/superpowers/specs/2026-08-10-soulbuddy-mvp-design.md), [the foundation plan](docs/superpowers/plans/2026-08-10-foundation-local-first-vertical-slice.md), [the prayer-library plan](docs/superpowers/plans/2026-08-11-prayer-library-practices.md), and [local-first invariants](docs/architecture/local-first.md).
