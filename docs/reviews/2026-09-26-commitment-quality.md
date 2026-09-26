# Commitment flow and media review — 26 September 2026

## Result

The approved Commitment journey is implemented through finalization, daily practices, reminders, preparation review, meditation, listening, and optional private reflection. The branch is a release candidate; physical-device listening and live PowerSync deployment validation remain open.

The first-use flow now survives leaving and continuing a draft, requires declaration review, and creates one linked Goal with the chosen practices atomically. Existing onboarding drafts retain their original route. Finalization retries do not duplicate saved records. A database-backed widget test exercises the complete first-use path, including leaving and continuing.

## Experience

- Ivory surfaces, golden artwork, compact controls, and restrained shadows follow the approved visual direction. Invitation and summary screenshots were rendered from the Flutter widgets and visually inspected.
- The journey and meditation routes suppress global prayer overlays. Long names wrap outside artwork; guide choices wrap at larger text sizes.
- Narration defaults to 0.85x with adjustable speed, complete transcripts, and synchronized highlighting. Following a transcript scrolls its own reading area without moving the playback controls.
- Leaving or backgrounding a session pauses audio and the foreground timer. Continuing requires an explicit action. Navigation does not record a completed session.
- The previous meditation sound preference is restored. A late preference load cannot override a new selection. Personal-prayer narration requires explicit consent; private content is not included in route parameters.
- Ten-day preparation review records the user's decision without spiritual scores or claims of spiritual readiness.

## Finished media

The invitation uses a licensed excerpt of Scott Buckley's **Aphelion**. Five older generated musical tones have been replaced with distinct licensed recordings: **Resolutions**, **Aurora**, **Affirmations**, **First Snow**, and **A Kind Of Hope**. Original sources, CC BY 4.0 attribution, excerpt edits, and checksums are documented in the asset manifests and credited in Settings.

The five meditation masters measure approximately −20.4 to −20.5 LUFS. Their playback gain is 0.22, keeping the music below the narration. Checks cover decoding, clipping, distinct source hashes, duration, and loop boundaries. Seven finished neural-voice recordings cover invitation, readiness, three guides, listening, and the short notification. Full text and caption files are bundled. The old soundscape generator cannot overwrite the curated music.

Visual evidence and a 45-second invitation audition render are under `artifacts/commitment-review/`. The audition combines narration at 0.85x with an Aphelion excerpt; it approximates the voice/music balance and is not an exact capture of the app's phase transitions. Music: “Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au. [Original recording](https://www.scottbuckley.com.au/library/aphelion/) · [License](https://creativecommons.org/licenses/by/4.0/). The render is trimmed, mixed, and faded.

Automated signal checks do not establish subjective musical quality. Human listening on a phone speaker and headphones remains pending. The narration manifest identifies the synthetic voice provider and does not assert additional provider rights.

## Verification

- Final full Flutter suite: **785 tests passed**, including the transcript-scroll regression and the database-backed journey integration test.
- Flutter analyzer: **no issues**. All 83 changed/new Dart files passed formatting without changes.
- Android ARM64 debug APK and release web build: **successful**, including the final bounded-transcript change.
- Laravel suite: **214 tests / 1,199 assertions passed**.
- Media verifier unit tests: **14 passed**. All eight Commitment audio assets and five curated music recordings passed their asset checks.
- The actual Flutter finalizer's 16-operation upload fixture, including five practices, is accepted by Laravel and can be replayed without duplicate records. Ownership derives from the authenticated user.
- SQLite migration tests preserve populated Goal action history while adding the new practice kind. Other database-engine migration branches have not been executed locally.

## Release gates

1. Install and listen on a physical Android device, including notification audio, screen-awake behavior, interruptions, and speaker/headphone balance. ADB listed no connected device on either active server port during the final check.
2. Apply backend migrations and merge the reviewed six-table PowerSync rules fragment into the existing deployment. Validate it against the actual PowerSync instance and verify isolation with two accounts. Do not replace existing buckets or replicate local draft/narration-cache tables. See `docs/deployment/commitment-sync.md`.
3. Build and validate the signed production bundle after those gates. No Play Store upload or production deployment was performed in this review.

The final debug APK is `apps/soulbuddy/build/app/outputs/flutter-apk/app-debug.apk`. Signing credentials, local test configuration, dependency directories, and build logs are excluded from the commit.
