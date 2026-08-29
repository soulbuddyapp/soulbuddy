# SoulBuddy local-first architecture

SoulBuddy treats the device database as the interaction path and Laravel/PostgreSQL as the authority. Recording must not wait for connectivity.

## Invariants

- Flutter reads and writes through repository interfaces backed by PowerSync-managed SQLite.
- An Encounter and its first immutable revision are written in one local transaction.
- Remember observes the local database; it never performs an HTTP read.
- Archiving hides an Encounter without deleting revision history.
- Versioned bundled prayer and editorial manifests are validated and imported idempotently into local-only tables that never enter the upload queue.
- Reviewed/published editorial bundled prayer IDs are authoritative for their stable wording. An unprovenanced canonical row with the same ID cannot replace that reviewed wording. Canonical-only and legacy library rows remain available through normal library reads, and canonical Helpful totals remain server-derived data rather than client-supplied mutation fields.
- Helpful votes and dated Today selections are private owner-scoped rows. They are written optimistically to local SQLite and remain usable while sync is unavailable.
- RSVCE is a separate read-only SQLite source. It is indexed locally and never enters synced tables.
- An empty remote configuration leaves the application usable in local-only mode.
- Sync issues are local-only records. Recording one can never create another upload mutation.
- Browser storage persistence is requested only after an important save; denial or lack of support never blocks the save.
- A recorded memory keeps its audio bytes only on the device that captured them: app-private files on Android/iOS and IndexedDB in the browser. Only the Encounter text and revision use the sync queue.
- Audio metadata is local-only and owner-scoped. Playback never uploads a recording or sends it to Laravel, AI, TTS, analytics, or logs.
- Removing audio first deletes its owned metadata, then its private bytes. Interrupted byte cleanup is retried by non-logging orphan cleanup, while the written memory remains intact.
- New spiritual copy is never produced by a runtime generative provider. Supported sources are Scripture with provenance, reviewed editorial content, and the user's own words.
- Historical `prayer_generation_requests` and their contexts are compatibility-only local records. They are owner-scoped and read-only; they cannot be created, edited, queued, claimed, retried, or dispatched.
- Accepting a historical ready draft may create the durable `personal_prayer`/revision/link records, but must not mutate the retired generation archive. Older rows that already contain an accepted-prayer pointer remain readable for backward compatibility.

## Server mutation semantics

Laravel derives ownership from the authenticated user. Client-supplied owner identifiers are ignored. A mutation batch accepts supported private record operations, stores operation UUIDs with user/payload fingerprints for replay safety, validates references and paired revisions where required, supports partial updates where defined, and applies the batch in a database transaction.

Prayer vote counts are canonical server data. Database triggers keep totals correct for direct, bulk, and cascading changes; client writes cannot set `helpful_count`. Alias rows reconcile installation-local mutation IDs to one semantic vote per user/prayer and one Today selection per user/local date. Every private lookup and mutation is scoped to the authenticated user, including replay and delete paths.

Structural request failures return 422. Domain rejections such as unsupported tables, incomplete pairs, operation conflicts, and forbidden ownership return HTTP 200 with accepted/rejected counts so one rejected record need not permanently block later uploads. The Flutter connector validates that these counts account for every submitted operation before completing a local transaction. Transient infrastructure failures remain 5xx and leave the client upload queue pending; permanent request failures create a sanitized local issue and release later writes.

## Private-data boundary

Prayer text, Encounter titles/bodies, Scripture selections, Circle messages, Goal notes, and other private formation data must not be written to application logs, analytics payloads, crash breadcrumbs, or generative-AI requests. Runtime generative AI is not a supported destination for spiritual content or private formation context.

Prayer narration is the narrow external-processing exception described below: only the exact immutable saved-prayer revision may be sent, and only after explicit disclosure and consent. User-recorded memory audio remains device-local and is never part of that narration request.

## Current development boundary

The real local database and Laravel contract are tested independently. When remote URLs are present, the app opens its local database first and starts PowerSync with the Laravel connector. The connector batches each local PowerSync transaction into one authenticated Laravel request, preserves retryable writes, and records sanitized local issues for permanent rejections. Laravel issues ten-minute PowerSync JWTs with a configured key ID using the authenticated user's immutable public UUID; no name, email, prayer, Encounter text, Goal text, or other private formation content is included in the token.

On a configured release, SoulBuddy exchanges the installation's existing local owner/device UUIDs and a 256-bit secret held in secure storage for a scoped Laravel session token. The server hashes the installation secret, never logs it, and will not let another device claim an existing owner identity. When the API is not configured or cannot be reached, SoulBuddy remains usable in local-only mode and retries bootstrap on a later app start.

## Formation guardrails

Local-first performance serves the spiritual purpose: the app should be easy to reach when a person needs to pray, act, or remember. Features are evaluated by whether they support a response to grace, form character, encourage outward love and responsible action, or preserve spiritual memory for the person, family, and those who come after them.

These are qualitative product guardrails, never calculated accounts. Helpful ordering describes the usefulness of shared prayer copy; it is not spiritual rank. SoulBuddy has no spiritual-capital score, points, streak rewards, leaderboard, or achievement dashboard, and practice completion produces no public state or celebratory reward.

## Prayer narration

Prayer narration is distinct from user-recorded memory audio and from prayer authorship. SoulBuddy sends only the authenticated user's exact immutable saved-prayer revision to the Laravel API after an explicit disclosure and consent. Laravel creates one Deepgram Aura MP3 per content and voice configuration, encrypts the cached asset in private storage, and returns short-lived authenticated playback access. The app caches the returned bytes in its local-only reminder-device row for offline replay.

`Play prayer when opened` is off until the disclosure is accepted and the exact revision is ready. System notifications remain silent. An in-app reminder may autoplay once only after an explicit open and only when the platform can affirm an appropriate audio route and interruption state; otherwise the visible `Play prayer` button remains available. Playback never creates a prayer session. Only `I prayed this` does.
