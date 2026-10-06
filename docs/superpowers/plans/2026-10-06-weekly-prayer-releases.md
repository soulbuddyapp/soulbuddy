# Weekly prayer releases implementation plan

> **For the implementer:** Use the `executing-plans` skill to execute this plan task by task.

**Goal:** Offer a voluntary weekly prayer release that adds the source’s three prayers and two meditation prayers to a person’s prayer library, retains every supplied word exactly, works offline after download, and sends a single release notice through the channels the person has enabled.

**Architecture:** Model a release separately from its canonical prayer records. Each prayer record stays in `library_prayers`, so it works with Today, Sacred Hours, reminders, narration, and PowerSync exactly like an existing library prayer. `prayer_releases` owns the release metadata and exact preparation text; `prayer_release_items` fixes the five-item order and type; per-user preferences and downloads stay server-authoritative, exposed through authenticated endpoints and mirrored locally for offline filtering.

**Tech stack:** Flutter/Dart with Riverpod, PowerSync SQLite, Laravel/PHP, Pest, FCM, existing account/installation authentication.

## Non-negotiable content contract

The first release is a five-item collection. Source wording, capitalization, punctuation, line breaks, parentheticals, and the repetition counts below are canonical. Do not rewrite, shorten, normalize, paraphrase, spell-correct, or synthesize narration from any other transcript.

The release record stores this preparation text verbatim and displays it before the ordered items:

```text
Before you Pray - Preparation for a graceful prayer
Begin with the sign of the cross. Before petitioning God, clear your mind of all inclinations, occasions or taint of sin. Check if you have any subconscious desires of occasions of sin -  seeds sown through what you saw, what you said, what you touched, or an unlawful desire already planted in your heart; if you have such, determine now that God help you get rid of it; and decide how many times you should say the prayers during your day to stay on guard. Don’t pray carelessly, kneel or stand or vocalize to mean what you say, whatever works best for you.
```

Use the following five entries in this exact order. The `kind` column is product metadata only; it must never alter the source wording.

### 1. Prayer — `Daily Prayer Against Temptations`

```text
+
Jesus humbled himself unto death, even death on a Cross
May I not regress in my transformation journey to be as Christ

I acknowledge that no good intention comes from my flesh, and it is the Spirit in me that speaks good for my soul. And it’s the spirit of sonship of the same Great and Mighty God; the child spirit of the Alpha and the Omega, the Beginning and the End, the Elohim, the ElShaddai, the King of Kings and the Lord of Lords. The same God who humbled himself and took human form for my sake.

Through the grace and mercy of God, may my mind be healed and my soul sanctified. Heal my mind dear Lord and restore and renew my spiritual vitality today: a heart awake to Your presence, a will ready to obey, and attention available for Your love and to Love.

I reject all thoughts that distract me from Your presence and any selfish desires that objectify others or myself. I reject all selfish attitudes and pleasure that obstruct your presence and perfect will in my life. Let the strength recovered from wasteful wrongdoing become patience, honest work, prayer and generosity. May your goodness and love flow in me and through me without restraint. Help me to guard my mind this day with discipline and to remember that your presence is greater than any other treasure. Protect me from the lures of the world and its devices. Create in me a pure heart and renew a right spirit within me. May your Spirit dear Lord make me whole. Amen.
```

### 2. Meditation prayer — `Brief Meditation`

```text
The Holy Spirit is our greatest gift for transformation. Listen silently in your heart now for good inspirations for your day (not of ego, but of true humble service).

Dear Holy Spirit, help me heed inspirations of discipline or warnings and bear fruits in the good inspirations you have given or will give me today. Amen.
```

### 3. Prayer — `Affirmative Prayer to resist occasions of Sin`

```text
+
I hereby give myself to God and immerse my will in God’s will, that my purpose may be illuminated; that my will may be fully aligned with God’s will; and that my mind may be sanctified in the perfect will of God.
May God free and shield me from all distractions that hold me back from growing in my mission/assignment in this world. Amen
```

### 4. Meditation prayer — `New Adam repetitions`

```text
Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)
In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)
```

### 5. Prayer — `Daily Prayer to join our hearts to the heart of Jesus`

```text
Heavenly Father, Your Word says that out of the abundance of the heart, the mouth speaks. Purify the heart from which my words and actions flow. Remove bitterness, pride, laziness, lust and all forms of licentiousness from my life. Fill me deeply with your Love, that I may truly be a light wherever I go. Sanctify my mind that I may recognize your daily presence in thanksgiving. Grant me your passion so that I may have great strength and courage to carry out Your will. Give me your peace and serenity that I may stand resolute in temptations/trials. I renounce all works of evil today. In moments of distraction or boredom, fill me with your Word. Where I have sinned, lead me to repentance, confession and healing. Do not let shame lead me to excuses or keep me from abiding in You.

Jesus my Redeemer, order my steps in your words.
May all my steps, words and works today, be to the glory of Your name.

Amen.
```

`Memorare` has no supplied body. Do not add it to the release, library, narration queue, notification, or user interface until its full source wording is supplied.

## Data model and release rules

- Use release slug `renewed-mind-and-guarded-heart-v1` and a stable UUID namespace/constant for deterministic ids.
- Add `content_sha256` to every item. The seeder computes the hash from UTF-8 `title + "\\n" + body`; narration generation and tests must use that exact hash.
- Store title separately from body. The leading `+` belongs to the first and third prayer bodies because it is source content.
- Map the three prayer items to `PrayerPurpose.daily`; map the two meditation-prayer items to `PrayerPurpose.guidance`. Set `grounding=general_christian` and `language_style=christian` for all five. These tags must not change the text.
- Store no invented action prompt. `action` remains `null` for all five entries.
- A release is visible in discovery after `published_at`; it is playable/selectable only after the signed-in person adds it. Once added, all five exact items remain offline and survive later release archival.
- Subscription is opt-in and independent of adding a particular release. A subscription permits delivery notices; it must never auto-add a prayer collection.
- A release download is idempotent. One account’s download neither changes another account’s library nor adds it to Today.
- Narration default remains 0.85x. An audio asset can be attached only when its transcript hash matches `content_sha256`; otherwise spoken playback must use the exact in-app text or remain unavailable. Never read a substitute script.

## Affirmation-prayer practice

The fourth item, `New Adam repetitions`, remains one `meditation_prayer` release item with two exact repetition steps. It also has a structured `affirmation_repetition` practice profile:

| Step | Exact text | Target |
| --- | --- | ---: |
| 1 | `Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus` | 50 |
| 2 | `In moments that distract me from your perfect will, let Satan be rebuked o Lord` | 10 |

The visible prayer copy must preserve the source’s `(x50)` and `(x10)` forms. The structured profile removes only those suffixes for paced repetition and must prove that each profile phrase plus its suffix reconstructs the original source line exactly.

### Gospel-shaped practice principles

This is a product interpretation, not a claim about what Jesus would build in software. The feature should reflect the patterns the Gospels show:

- **Truth before technique:** the prayer’s exact words lead; sound, counting, and visuals remain quiet support.
- **Freedom and consent:** each person explicitly starts, pauses, resumes, or ends the practice. There is no auto-start, streak penalty, spiritual rank, or compulsory count.
- **Mercy without shame:** an unfinished practice is simply paused or ended. The app does not label anyone weak, impure, late, or failed.
- **Attention over performance:** show only the current line, a calm count, elapsed practice time, and compact controls. No timer races, confetti, score, comparison, or noisy prompts.
- **Faith that bears fruit:** completion can offer one optional quiet response—prayer, Scripture, a note, or a concrete act of love—without treating it as a transaction for grace.
- **Care for the whole person:** do not promise a theta state, subconscious reprogramming, healing, deliverance, or a clinical outcome. Music supports focus and prayer; it is optional and must never mask the spoken words.

### Affirmation-prayer session behavior

1. The detail view exposes `Begin affirmation prayer` only for a release item with an `affirmation_repetition` profile.
2. Setup is deliberately short: selected sound (defaulting to the saved meditation preference), sound level, spoken guide on/off, and pace. Default spoken pace is 0.85x. Offer 0.70x, 0.85x, 1.0x, and 1.15x only.
3. During a step, show the one exact phrase, `n of target`, a restrained circular progress mark, pause, and end. The primary response is `I have prayed this`; one deliberate tap advances by one. Do not auto-increment merely because audio played.
4. If spoken guide is enabled, narration reads the exact phrase once at the chosen pace, then leaves a calm pause. `Hear again` repeats the current phrase but does not advance the count. A person may speak it aloud or silently before advancing.
5. Use the selected music bed only after a deliberate start. Loop it at the saved low volume and duck it while the guide speaks. Stop guide and music immediately on pause, end, navigation away, audio-focus loss, or app backgrounding. Explicit resume is required after foregrounding.
6. Keep the display awake while the session is active, following the existing meditation and prayer behavior. Restore in-progress state after configuration changes and process recreation; never resume sound without an explicit tap.
7. After the fiftieth first-step repetition, transition quietly to the second exact phrase at `0 of 10`. After the tenth second-step repetition, record a completed affirmation-prayer session. Ending early records the completed counts and an `ended_early` outcome.
8. The completion surface offers `Close`, optional `Pray`, optional `Reflect`, and optional `Choose for today`. It must not show badges, streaks, comparative language, or promises of internal transformation.

### Additional implementation task: Add counted affirmation-prayer sessions

**Files:**
- Modify: `services/api/resources/prayer-releases/renewed-mind-and-guarded-heart-v1.json`
- Modify: `services/api/app/Domain/PrayerReleases/ReleaseContent.php`
- Create: `services/api/database/migrations/2026_10_06_000002_create_affirmation_prayer_sessions_table.php`
- Create: `services/api/app/Models/AffirmationPrayerSession.php`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Create: `services/api/app/Domain/Sync/ApplyAffirmationPrayerSessionMutation.php`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/affirmation_prayer.dart`
- Create: `apps/soulbuddy/lib/features/prayers/application/affirmation_prayer_session_controller.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/affirmation_prayer_session_screen.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/core/router/app_router.dart`
- Create: `services/api/tests/Feature/PrayerReleases/AffirmationPrayerSessionTest.php`
- Create: `apps/soulbuddy/test/features/prayers/application/affirmation_prayer_session_controller_test.dart`
- Create: `apps/soulbuddy/test/features/prayers/presentation/affirmation_prayer_session_screen_test.dart`

1. Extend the JSON schema with optional `practice`. For this source item only, require `mode: "affirmation_repetition"` and two ordered steps containing `phrase`, `target_count`, and `source_line`. Validation must reject a profile that cannot reconstruct `source_line` as `phrase + " (x" + target_count + ")"`.
2. Persist immutable session records with `user_id`, `release_item_id`, `local_date`, `started_at`, `ended_at`, `outcome` (`completed`, `ended_early`), `step_one_count`, `step_two_count`, selected sound key, selected narration speed, and timestamps. Enforce counts `0..50` and `0..10`; completion requires exactly 50 and 10.
3. Add `affirmation_prayer_sessions` as a supported, account-scoped sync table. The server validates ownership, release-item eligibility, bounds, immutable terminal state, and timestamps. The client may save progress locally, but the server accepts only an immutable terminal record; it must never accept a forged completed record with incomplete counts.
4. Write the controller against an injectable clock, narration player, sound-bed player, and session repository. It owns step transition, count advance, pause/resume, audio ducking, lifecycle stop, screen-awake state, and durable terminal save. It must be unit-tested before UI implementation.
5. Reuse `MeditationSoundBed`, `MeditationSoundPreferencesRepository`, `ScreenAwake`, `PracticeAudioScope`, and the existing audio-focus conventions. Add no frequency-producing or binaural-beat feature and make no neurological claim.
6. Add tests for exact profile parsing, one-tap progression, no progression from audio completion, fifty-to-ten transition, early end, valid completion, double-tap serialization, pause/background audio stop, explicit-only resume, selected sound persistence, 0.85x default, and 2.0 text scale without overflow.

```dart
test('audio replay never advances an affirmation count', () async {
  final controller = buildController(stepOneTarget: 50, stepTwoTarget: 10);

  await controller.begin();
  await controller.hearAgain();

  expect(controller.state.stepOneCount, 0);
  await controller.confirmSpoken();
  expect(controller.state.stepOneCount, 1);
});
```

**Verify:**
```powershell
cd services/api
php artisan test tests/Feature/PrayerReleases/AffirmationPrayerSessionTest.php

cd ../../apps/soulbuddy
flutter test test/features/prayers/application/affirmation_prayer_session_controller_test.dart test/features/prayers/presentation/affirmation_prayer_session_screen_test.dart
flutter analyze
```
## Customer-facing copy rules

Add only concise purpose/action copy, and validate it against the repository’s global product-copy rules. Recommended strings:

- Setting: `Weekly prayers`
- Setting detail: `One new prayer collection each week`
- Discovery label: `This week’s prayer`
- Discovery title: `Renewed mind & guarded heart`
- Discovery detail: `Prayer and meditation for purity, discipline, and a renewed mind.`
- Primary action: `Add prayers`
- Added state: `Added`
- Error recovery: `Try again`
- Notice title: `A new prayer collection is ready`
- Notice body: `Renewed mind & guarded heart`

Do not disclose sensitive subject matter in operating-system notification bodies. The detailed collection description may name purity and discipline after the person deliberately opens it.

## Implementation tasks

### Task 1: Make the exact release a checked-in source artifact

**Files:**
- Create: `services/api/resources/prayer-releases/renewed-mind-and-guarded-heart-v1.json`
- Create: `services/api/tests/Unit/PrayerReleases/ExactReleaseContentTest.php`
- Create: `services/api/app/Domain/PrayerReleases/ReleaseContent.php`

1. Add one JSON document containing release metadata, the exact preparation string, and five ordered items. Use JSON strings with explicit `\n` escapes; preserve the two spaces after `-` in `sin -  seeds`.
2. Add `ReleaseContent::fromJsonFile()` to decode, validate required fields, order uniqueness, kinds (`prayer`, `meditation_prayer`), and UTF-8 SHA-256 values before a release can be seeded or served.
3. Write the Pest test before parsing implementation. It must assert exactly five entries, `['prayer', 'meditation_prayer', 'prayer', 'meditation_prayer', 'prayer']`, the two repetitions strings, the preparation double-space, and full equality with fixture constants kept in the test.
4. Add a negative test with a one-character body change that verifies validation rejects the stale checksum.

```php
it('preserves every supplied source character', function () {
    $release = ReleaseContent::fromJsonFile(base_path(
        'resources/prayer-releases/renewed-mind-and-guarded-heart-v1.json',
    ));

    expect($release->items)->toHaveCount(5)
        ->and($release->items[3]->body)->toBe(
            "Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)\n"
            . "In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)",
        );
});
```

**Verify:** `php artisan test tests/Unit/PrayerReleases/ExactReleaseContentTest.php`

### Task 2: Add server persistence and canonical prayer associations

**Files:**
- Create: `services/api/database/migrations/2026_10_06_000000_create_prayer_release_tables.php`
- Create: `services/api/app/Models/PrayerRelease.php`
- Create: `services/api/app/Models/PrayerReleaseItem.php`
- Create: `services/api/app/Models/PrayerReleasePreference.php`
- Create: `services/api/app/Models/PrayerReleaseDownload.php`
- Modify: `services/api/app/Models/LibraryPrayer.php`
- Create: `services/api/tests/Feature/PrayerReleases/PrayerReleasePersistenceTest.php`

1. Create `prayer_releases`: UUID `id`, unique `slug`, title, discovery label/detail, `preparation_text`, `published_at`, `archived_at`, timestamps.
2. Create `prayer_release_items`: UUID `id`, foreign UUID `release_id`, foreign UUID `library_prayer_id`, enum/check `kind`, unsigned `sort_order`, `content_sha256`, nullable `narration_uri`, nullable `narration_content_sha256`, timestamps; unique `(release_id, sort_order)` and `(release_id, library_prayer_id)`.
3. Create `prayer_release_preferences`: `user_id` primary/unique, `weekly_enabled` default false, `notification_enabled` default true, `time_zone` nullable, timestamps.
4. Create `prayer_release_downloads`: UUID `id`, `user_id`, `release_id`, `downloaded_at`, unique `(user_id, release_id)`.
5. Add relationships from `LibraryPrayer` and `User` without changing existing prayer-vote, Today, Sacred Hour, or reminder foreign keys.
6. Test cascade behavior: delete user removes preferences/downloads; release archival preserves downloads and historical selections; duplicate download is rejected by the unique key.

**Verify:** `php artisan test tests/Feature/PrayerReleases/PrayerReleasePersistenceTest.php`

### Task 3: Seed exactly once, without rewriting existing user state

**Files:**
- Create: `services/api/app/Domain/PrayerReleases/PrayerReleasePublisher.php`
- Create: `services/api/database/seeders/PrayerReleaseSeeder.php`
- Modify: `services/api/database/seeders/DatabaseSeeder.php`
- Create: `services/api/tests/Feature/PrayerReleases/PrayerReleaseSeederTest.php`

1. Have `PrayerReleasePublisher` obtain only validated `ReleaseContent` from Task 1.
2. Upsert the release, five canonical `library_prayers`, and their ordered release-item links by deterministic UUID.
3. Preserve `helpful_count` and do not overwrite an existing `published_at` with a later date. The importer must reject content hashes that no longer match the JSON.
4. Set initial release `published_at` explicitly during deployment; use a migration-safe UTC date that product can configure through deployment environment rather than `now()` in a seeder.
5. Register the release seeder after `PrayerLibrarySeeder`.
6. Test two seeder runs produce five links, no duplicates, unaltered source bodies, and no changes to an existing helpful count.

**Verify:** `php artisan test tests/Feature/PrayerReleases/PrayerReleaseSeederTest.php`

### Task 4: Provide authenticated release discovery, preferences, and add operations

**Files:**
- Create: `services/api/app/Http/Controllers/Api/PrayerReleaseController.php`
- Create: `services/api/app/Http/Controllers/Api/PrayerReleasePreferenceController.php`
- Create: `services/api/app/Http/Requests/StorePrayerReleasePreferenceRequest.php`
- Modify: `services/api/routes/api.php`
- Create: `services/api/tests/Feature/PrayerReleases/PrayerReleaseApiTest.php`

1. Add authenticated endpoints:
   - `GET /api/prayer-releases` — published/unarchived release metadata, ordered item metadata, current `added_at`, and current preference.
   - `PUT /api/prayer-release-preference` — accepts `weekly_enabled`, `notification_enabled`, and a valid IANA `time_zone`; disables delivery when weekly opt-in is false.
   - `POST /api/prayer-releases/{prayerRelease}/add` — creates the idempotent download record and returns `added_at` plus the complete release content.
2. Require `auth:sanctum` for all routes, rate-limit add and preference writes, and use the authenticated user only. Never accept `user_id` from the client.
3. Do not expose `Memorare` or unpublished releases.
4. Keep the full five bodies out of discovery responses until add succeeds, unless product later explicitly changes that rule. The app’s native server sync will have canonical records, but UI filtering enforces the same access boundary locally.
5. Test unauthenticated rejection, opt-in update, first add, repeated add, archived release 404, and exact response equality with the artifact.

**Verify:** `php artisan test tests/Feature/PrayerReleases/PrayerReleaseApiTest.php`

### Task 5: Sync server catalog data and per-user adds to the offline client

**Files:**
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_release_api_client.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_release_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_release_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_release.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_repository.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/providers/prayer_providers.dart`
- Create: `apps/soulbuddy/test/features/prayers/data/powersync_prayer_release_repository_test.dart`

1. Add local tables for release metadata, ordered release items, a local release preference cache, user release downloads, and an exact release-item content cache. Mark account-owned data correctly for PowerSync; ensure the client never syncs a download belonging to another user.
2. Add a one-shot authenticated API client that refreshes preference/discovery metadata on app start, prayer-tab entry, and explicit retry. Cache the last successful response for offline presentation.
3. On `addRelease`, call the API, transactionally persist the response, local download marker, and exact item-content cache. Build item detail from that cache until PowerSync has received the canonical library prayers; link every item to its canonical library-prayer id. A network failure must leave no partial local download.
4. Update `watchLibrary` to exclude `weekly` catalog entries unless their release is locally downloaded, while retaining all existing bundled and standard server prayers. Existing Today/Sacred Hour records always remain resolvable, even if a later archive hides the collection from discovery.
5. Add repository tests for offline reads after add, idempotent add, failed add rollback, and no weekly content in the ordinary library before add.

**Verify:** `cd apps/soulbuddy; flutter test test/features/prayers/data/powersync_prayer_release_repository_test.dart`

### Task 6: Add a compact weekly-prayer experience

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/presentation/weekly_prayer_release_card.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_release_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart`
- Modify: `apps/soulbuddy/lib/core/router/app_router.dart`
- Create: `apps/soulbuddy/test/features/prayers/presentation/weekly_prayer_release_card_test.dart`
- Create: `apps/soulbuddy/test/features/prayers/presentation/prayer_release_detail_screen_test.dart`

1. Place a single compact discovery row above ordinary filters only when a published release exists. It shows label, title, a short purpose line, and one action; it must not render the five bodies or a second library heading.
2. The detail route presents the exact preparation text followed by five ordered, clearly typed entries. Keep typography readable, respect system font scaling, use the existing ivory/gold surface tokens, and avoid an overlay stack.
3. Before add, offer only the compact `Add prayers` action. After add, present the ordered collection and permit each canonical prayer to open in the current prayer detail flow, including Today and Sacred Hour actions.
4. Add `Weekly prayers` preference within existing notification preferences. Its disabled state must prevent future weekly delivery without removing already added content.
5. Default narration speed is 0.85x for release items. Existing selected sound behavior remains unchanged; navigating away stops ambient sound immediately.
6. Widget tests must cover pre-add compact state, add success, five item order, exact text rendering, retry state, preference persistence, and text scale 2.0 without overflow.

**Verify:**
```powershell
cd apps/soulbuddy
flutter test test/features/prayers/presentation/weekly_prayer_release_card_test.dart test/features/prayers/presentation/prayer_release_detail_screen_test.dart
flutter analyze
```

### Task 7: Deliver one weekly notice only to opted-in people

**Files:**
- Create: `services/api/database/migrations/2026_10_06_000001_create_prayer_release_deliveries_table.php`
- Create: `services/api/app/Models/PrayerReleaseDelivery.php`
- Create: `services/api/app/Console/Commands/SendPrayerReleaseNotifications.php`
- Modify: `services/api/app/Domain/Notifications/FirebasePushSender.php`
- Modify: `services/api/routes/console.php`
- Create: `services/api/tests/Feature/PrayerReleases/PrayerReleaseNotificationTest.php`

1. Add a delivery ledger table or unique delivery record keyed by `(release_id, user_id, channel)` so retries never duplicate a weekly notice.
2. Schedule the command every minute, following the existing local-time pattern. Deliver at Monday 07:00 in each opted-in person’s selected IANA time zone. If the scheduler runs late, send once after 07:00 on the release week; do not backfill previous weeks.
3. Target only authenticated installations with an active token and an opt-in preference. FCM uses a distinct `soulbuddy_weekly_prayers_v1` channel, stable notification tag per release, high Android priority, and data route `/prayers/releases/{slug}`.
4. Reuse the existing token invalidation and failure logging behavior. Record delivery only after FCM acceptance. Do not include sensitive subject matter in title/body.
5. Add a Telegram delivery adapter only when the existing Telegram companion preference is enabled; it sends the same title and deep link and writes its own channel ledger entry. It must not be introduced as a separate unlinked delivery path.
6. Test UTC conversion, opt-out exclusion, multi-installation same-account dedupe policy, retry after FCM failure, invalid-token cleanup, exactly-one delivery after acceptance, and safe notification copy.

**Verify:** `php artisan test tests/Feature/PrayerReleases/PrayerReleaseNotificationTest.php`

### Task 8: Wire release narration only after transcript validation

**Files:**
- Modify: `services/api/app/Domain/PrayerReleases/PrayerReleasePublisher.php`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_detail_screen.dart`
- Create: `services/api/tests/Feature/PrayerReleases/PrayerReleaseNarrationTest.php`
- Create: `apps/soulbuddy/test/features/prayers/presentation/prayer_release_narration_test.dart`

1. Extend the existing narration request flow with release-item metadata and transcript-hash validation. The server must refuse to attach an asset when `narration_content_sha256 !== content_sha256`.
2. Start narration only from the exact visible item content, with the existing 0.85x default. Audio focus and lifecycle behavior must stop sound when the prayer/detail route is left.
3. Do not ship placeholder voice content or produce an audio asset from a modified transcript.
4. Test valid hash playback, mismatch rejection, 0.85x initialization, and route-pop audio stop.

**Verify:**
```powershell
php artisan test tests/Feature/PrayerReleases/PrayerReleaseNarrationTest.php
cd apps/soulbuddy
flutter test test/features/prayers/presentation/prayer_release_narration_test.dart
```

### Task 9: End-to-end quality pass and rollout

**Files:**
- Modify: `services/api/README.md`
- Modify: `apps/soulbuddy/README.md` or current engineering notes, if present
- Create: `docs/runbooks/weekly-prayer-releases.md`

1. Document publish workflow: place/validate artifact, review SHA-256, seed, set `published_at`, run scheduler health check, verify FCM/Telegram ledgers, and rollback by `archived_at` without deleting added content.
2. Add monitoring for notification acceptance/failure counts and stale scheduler runs; alert only operational staff, never expose credentials in logs.
3. Run the narrow backend and Flutter suites, then the full repository-required tests and analyzers. Manually verify on a physical Android device: opt-in, notice, add, offline airplane-mode reopen, detail order, exact punctuation, narration speed, sound stop, Today selection, and Sacred Hour selection.
4. Release server before app binary. Old clients simply ignore release tables; new clients must handle an empty release response safely.

**Verify:**
```powershell
cd services/api
php artisan test

cd ../../apps/soulbuddy
flutter test
flutter analyze
```

## Acceptance criteria

- The release has exactly five entries: three `prayer` and two `meditation_prayer` entries, in the listed order.
- `New Adam repetitions` has exactly two counted affirmation steps: 50, then 10; replaying narration never advances either count.
- Every source character, including `It’s`, `God’s`, `sin -  seeds`, `mission/assignment`, `o Lord`, and `(x50)`/`(x10)`, is verified by tests and presented unchanged.
- `Memorare` is absent until complete source wording exists.
- No person receives a weekly release notice unless they opted in.
- Adding the release is explicit, idempotent, and available offline afterward.
- All added prayer entries work through existing Today, Sacred Hour, reminder, and exact-narration paths.
- Existing library prayers, selections, reminders, voice recordings, and account sync retain their behavior.
