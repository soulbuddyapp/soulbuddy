# SoulBuddy local-first architecture

SoulBuddy treats the device database as the interaction path and Laravel/PostgreSQL as the authority. Recording must not wait for connectivity.

## Invariants

- Flutter reads and writes through repository interfaces backed by PowerSync-managed SQLite.
- An Encounter and its first immutable revision are written in one local transaction.
- Remember observes the local database; it never performs an HTTP read.
- Archiving hides an Encounter without deleting revision history.
- RSVCE is a separate read-only SQLite source. It is indexed locally and never enters synced tables.
- An empty remote configuration leaves the application usable in local-only mode.
- Sync issues are local-only records. Recording one can never create another upload mutation.
- Browser storage persistence is requested only after an important save; denial or lack of support never blocks the save.

## Server mutation semantics

Laravel derives ownership from the authenticated user. Client-supplied owner identifiers are ignored. A mutation batch accepts only Encounter and Encounter-revision operations in this milestone, stores operation UUIDs with user/payload fingerprints for replay safety, validates paired revisions, supports partial Encounter patches, and applies the batch in a database transaction.

Structural request failures return 422. Domain rejections such as unsupported tables, incomplete pairs, operation conflicts, and forbidden ownership return HTTP 200 with accepted/rejected counts so one rejected record need not permanently block later uploads. The Flutter connector validates that these counts account for every submitted operation before completing a local transaction. Transient infrastructure failures remain 5xx and leave the client upload queue pending; permanent request failures create a sanitized local issue and release later writes.

## Private-data boundary

Prayer text, Encounter titles/bodies, Scripture selections, and Circle messages must not be written to application logs, analytics payloads, crash breadcrumbs, or AI requests by default. AI features may receive private records only after explicit selection by the user.

## Current development boundary

Docker is not installed in this workspace, so no local PowerSync service is started. The real local database and Laravel contract are tested independently. When remote URLs are present, the app opens its local database first and starts PowerSync with the Laravel connector. The connector batches each local PowerSync transaction into one authenticated Laravel request, preserves retryable writes, and records sanitized local issues for permanent rejections. Laravel issues ten-minute PowerSync JWTs with a configured key ID using the authenticated user's immutable public UUID; no name, email, prayer, or Encounter text is included in the token.

Remote activation still depends on the later application-authentication milestone supplying a Laravel session token. Until then, or whenever either remote URL is empty, SoulBuddy stays fully usable in local-only mode.
