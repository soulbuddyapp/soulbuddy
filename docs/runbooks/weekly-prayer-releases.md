# Weekly prayer releases

A weekly prayer release is a fixed five-item collection. The release owns the
ordering and the exact preparation text; each item is also a canonical
`library_prayers` record, so an added collection works through Today, Sacred
Hours, reminders, narration, and helpful votes exactly like any other library
prayer.

Release slug: `renewed-mind-and-guarded-heart-v1`.

## Content rules that must not drift

- The checked-in artifact is `services/api/resources/prayer-releases/renewed-mind-and-guarded-heart-v1.json`.
  It is the only source of the release wording.
- `ReleaseContent` refuses to decode an artifact that fails its own checks:
  missing fields, duplicate or non-contiguous `sort_order`, an unknown `kind`,
  a `content_sha256` that does not match the UTF-8 `title + "\n" + body`, or a
  repetition profile whose steps cannot rebuild their own source lines.
- A one-character edit anywhere in a body therefore fails before seeding or
  serving. `tests/Unit/PrayerReleases/ExactReleaseContentTest.php` also pins the
  exact wording, including `It’s`, `God’s`, `sin -  seeds`, `mission/assignment`,
  `o Lord`, and the `(x50)` / `(x10)` suffixes.
- `Memorare` has no supplied body. `ReleaseContent` rejects it outright and the
  API never exposes it.
- No item carries an invented action prompt; `action` stays `null`.

## Publish workflow

1. **Place the artifact.** Write or update
   `resources/prayer-releases/<slug>.json`. Compute each `content_sha256` from
   `sha256(title + "\n" + body)` over UTF-8. Add `practice` only where a paced
   profile rebuilds the item body exactly.

2. **Validate.** Run:

   ```powershell
   cd services/api
   php artisan test tests/Unit/PrayerReleases/ExactReleaseContentTest.php
   ```

   A red run means the artifact and its declared content no longer agree. Fix the
   artifact; never adjust the checksum to hide a wording change.

3. **Review the hashes.** Before deployment, compare each item's
   `content_sha256` with the value the app will serve:

   ```powershell
   php artisan tinker --execute="dump(App\Domain\PrayerReleases\ReleaseContent::fromJsonFile(resource_path('prayer-releases/renewed-mind-and-guarded-heart-v1.json'))->items[3]->contentHash());"
   ```

4. **Seed.** Register `PrayerReleaseSeeder` after `PrayerLibrarySeeder` (already
   done in `DatabaseSeeder`) and run:

   ```powershell
   php artisan db:seed --class=PrayerReleaseSeeder
   ```

   The seeder is idempotent: deterministic UUIDs, five canonical prayers, five
   ordered item links, no duplicates. Helpful counts, an earlier publish date,
   and an existing archive are all preserved.

5. **Set `published_at`.** The date comes from `PRAYER_RELEASE_PUBLISHED_AT`
   (default `2026-10-05 07:00:00` UTC) and is read by the publisher, never
   `now()`. Set the environment variable before deploying a later release:

   ```dotenv
   PRAYER_RELEASE_PUBLISHED_AT=2026-10-12 07:00:00
   ```

   A release is visible in discovery only after this date, and it stays invisible
   once `archived_at` is set.

6. **Scheduler health.** The notice command runs every minute:

   ```powershell
   php artisan schedule:list
   php artisan prayer-releases:notify
   ```

   `prayer-releases:notify` reports accepted and failed counts and removes
   invalid tokens. It exits non-zero when any delivery failed.

7. **Verify the ledgers.** One row per release, person, and channel. A second run
   must not add rows:

   ```sql
   SELECT release_id, channel, count(*) FROM prayer_release_deliveries
   GROUP BY release_id, channel;
   ```

   Telegram deliveries are recorded in the same ledger with
   `channel = 'telegram'` and `telegram_connection_id` set.

8. **Rollback.** Set `archived_at`; never delete a release row. Downloads and
   existing selections survive, and added content keeps working offline:

   ```php
   App\Models\PrayerRelease::where('slug', $slug)
       ->update(['archived_at' => now()]);
   ```

## Notices and links

The FCM notice carries an in-app `route` of `/prayers/releases/{slug}`. The app
honours it only when the value parses as that exact shape; an unknown or
absolute value opens nothing rather than stranding someone on a blank screen.

**There is no app deep link.** The app publishes no web route for a release and
registers no Android App Links domain, so `https://<app url>/prayers/releases/<slug>`
returns 404 and would open a browser rather than the app. The Telegram notice
therefore carries no URL and tells the person to open SoulBuddy and choose
Prayers. Adding a real link requires a served route, an `assetlinks.json`, and an
`android:autoVerify` intent filter in `AndroidManifest.xml` — do not add a URL to
the Telegram message before all three exist.

## Deployment order

Release the server before the app binary. Old clients ignore the release tables
entirely; new clients must handle an empty release response safely, which they do
because discovery is cached locally and an empty list simply renders nothing.

## Migrations

Three tables, then one more for delivery:

1. `2026_10_06_000000_create_prayer_release_tables.php` — `prayer_releases`,
   `prayer_release_items`, `prayer_release_preferences`,
   `prayer_release_downloads`.
2. `2026_10_06_000001_create_prayer_release_deliveries_table.php` — the delivery
   ledger, unique on `(release_id, user_id, channel)`.
3. `2026_10_06_000002_create_affirmation_prayer_sessions_table.php` — immutable
   counted prayer sessions.

Run `php artisan migrate --force` before seeding. The PowerSync client schema
carries the matching local tables; a schema bump ships with the app binary, and
`prayer_release_downloads` and `affirmation_prayer_sessions` are account-owned.
Merge `infra/powersync/prayer-releases.sync-rules.yaml` into the sync service
configuration so a session reaches the account that owns it and no other account
ever sees it.

## Monitoring

Watch, per the release week:

- accepted and failed counts from `Prayer release delivery summary.`;
- stale scheduler runs (no success for two expected Monday windows);
- `invalid_tokens_removed` growth, which indicates a client registration problem
  rather than a content problem.

Alert only operational staff. Notification diagnostics carry a status and an error
code; they never carry a device token, a notice body, or a provider message.

## Manual device verification

On a physical Android device, with the server deployed:

1. Open Settings and turn on `Weekly prayers`; confirm the stored IANA zone.
2. Confirm no release card appears in Prayers before the release is published.
3. At Monday 07:00 local, confirm exactly one notice arrives and that its body
   names only the collection title.
4. Open Prayers, add the collection, and confirm the compact row reads `Added`.
5. Reopen the detail and confirm the five entries, their order, and their exact
   punctuation, including the leading `+` and the `(x50)` / `(x10)` suffixes.
6. Turn on airplane mode, force-stop, and reopen: the collection must still read
   and open.
7. Open `New Adam repetitions`, choose `Be still before God`, and confirm the
   recollection is skippable and silent until prayer begins deliberately.
8. Confirm the count advances only on `Continue`, that `Hear again` does not
   advance it, and that a group of ten lowers the sound rather than stopping it.
9. Background the app mid-prayer and confirm sound stops and does not return
   until an explicit action.
10. Select a release prayer for Today and for a Sacred Hour, and confirm both
    behave as they do for any library prayer.
