# SoulBuddy API deployment

`sbuddy.elbiblio.com` runs Laravel in a dedicated PHP 8.3 FPM container. Nginx
is the only public listener. FastCGI is bound to `127.0.0.1:9083`, and the
container reaches the existing host MariaDB only through its Unix socket.

The persistent layout is:

- `/var/www/soulbuddy/releases/<commit>` — immutable application releases
- `/var/www/soulbuddy/current` — active release symlink
- `/var/www/soulbuddy/shared/.env` — production configuration and secrets
- `/var/www/soulbuddy/shared/storage` — private Laravel files and cached,
  encrypted narration audio

The current host uses the confined Snap distribution of Docker. Snap Docker
cannot bind-mount `/var/www`, so each immutable release is mirrored under
`/var/snap/docker/common/soulbuddy/releases/<commit>` for the PHP container.
Its protected environment and writable storage live under
`/var/snap/docker/common/soulbuddy/shared`. Nginx continues to serve the
matching public tree from `/var/www/soulbuddy/current`; both paths must switch
to the same commit during a deployment or rollback.

Deployments install production Composer dependencies, link `.env` and
`storage`, run migrations and `PrayerLibrarySeeder`, optimize Laravel, switch
`current`, then restart `soulbuddy-api`. Rollback switches `current` to the
previous release and restarts the same container. Never place narration or
infrastructure secrets in Git, build arguments, the Flutter binary, or shell
history.

The morning push job runs through Laravel's scheduler. Host cron calls
`docker exec soulbuddy-api php artisan schedule:run` every minute; the host
PHP binary is 8.2 and cannot run this Laravel 13 app. Configure
`FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_PATH` in the protected
shared `.env`. The service account file must be readable by PHP-FPM and must
remain outside releases. The app registers a Firebase token and IANA timezone
per installation after notification permission is granted. The scheduler sends
after 5:30 a.m. local time, records successful sends by local date, and retries
failed sends on later ticks.

On 2026-09-30, the notification-only hotfix went live as
`20260930-notification-recovery-5a855be`: release
`20260921-morning-push-d900ebe` with three notification files from `5a855be`
overlaid. Both the host and Snap mirror release pointers were updated;
health and cron checks passed. Other new API features were not deployed.

Production choices:

- `DB_CONNECTION=mariadb` with `DB_SOCKET=/run/mysqld/mysqld.sock`
- file cache and sessions; synchronous jobs until a durable worker is needed
- no generative prayer provider; new spiritual copy comes from Scripture,
  reviewed editorial content, or the user's own words
- optional DeepSeek Goal guidance can only rank exact actions from the
  server-owned reviewed catalogue; the app falls back locally when it is
  unavailable, and its credential remains in the protected environment
- Deepgram Aura 2 remains available only for consented, server-loaded prayer
  narration with model-improvement opt-out; encrypted audio remains in private
  Laravel storage
- release Flutter builds default to `https://sbuddy.elbiblio.com`
- Android's main manifest owns `INTERNET`; keeping it only in debug/profile
  manifests produces a local-only release APK and is covered by a regression
  test
- PowerSync and authenticated mutation flushes support private synchronized
  records and narration; retired prayer-generation routes are not deployed

Historical local prayer-generation records exist only as a compatibility
archive on devices that created them before retirement. The server exposes no
prayer-draft generation route, prompt, provider configuration, or retry worker.
Accepted historical personal prayers remain ordinary private personal-prayer
records and must not be rewritten or deleted during deployment.

## Deploying audio authoring metadata

Prepare the same reviewed commit in the host and Snap release trees. Before
switching either active pointer, confirm a restorable MariaDB backup and review
all pending migrations: the documented notification hotfix was a partial
release. Run the following from the prepared candidate's Laravel directory
inside the deployment PHP 8.3 container, using its protected `.env` and the
host database socket:

```sh
set -eu
test -f artisan
test -f database/migrations/2026_11_03_000000_add_audio_authoring_metadata.php
php artisan migrate:status
php artisan migrate --pretend --force
```

After reviewing the preview, run `php artisan migrate --force` in that same
candidate and check `php artisan migrate:status`. Confirm the named migration
is marked **Ran**. It adds `personal_prayer_revisions.content_format` (existing
rows default to `text`) and nullable `memory_reflections.audio_encounter_id`.
Finish the normal seeding and optimization steps, switch both pointers to that
commit, and restart `soulbuddy-api` so the sync and narration handlers match
the schema.

Before releasing the client, add those columns to the existing private
PowerSync projections in their deployed configuration. Preserve the existing
owner filters and verify the positive and negative two-account checks in
[the audio release checklist](../immersive-audio.md#release-order). No audio
files or device-local context links belong in the projections.

For recovery, keep the additive columns, the MariaDB data and shared storage.
While recording-capable clients are active, retain compatible sync handlers.
If switching application releases, point **both** release trees at the same
compatible commit and restart the container. The migration refuses to roll
back while audio-authored data exists; do not remove recordings or references
to bypass that guard.
