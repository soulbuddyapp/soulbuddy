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

Deployments install production Composer dependencies, link `.env` and
`storage`, run migrations and `PrayerLibrarySeeder`, optimize Laravel, switch
`current`, then restart `soulbuddy-api`. Rollback switches `current` to the
previous release and restarts the same container. Never place provider keys in
Git, build arguments, the Flutter binary, or shell history.

Production choices:

- `DB_CONNECTION=mariadb` with `DB_SOCKET=/run/mysqld/mysqld.sock`
- file cache and sessions; synchronous jobs until a durable worker is needed
- DeepSeek V4 Flash in non-thinking mode for formulated prayer drafts
- Deepgram Aura 2 for consented, server-loaded prayer narration with model
  improvement opt-out; encrypted audio remains in private Laravel storage
- release Flutter builds default to `https://sbuddy.elbiblio.com`
- PowerSync remains an optional later service; authenticated mutation flushes
  support current server-authoritative AI and narration flows without it
