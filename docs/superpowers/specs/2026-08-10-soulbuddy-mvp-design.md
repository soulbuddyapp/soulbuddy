# SoulBuddy MVP Design

**Status:** Approved product direction; written specification awaiting final review  
**Date:** 2026-08-10  
**Product:** SoulBuddy  
**Platforms:** Flutter for iOS, Android, and authenticated web

## 1. Purpose

SoulBuddy is a humble spiritual companion built to aid a person's soul in its journey: growing in spiritual character and building spiritual wealth.

Spiritual wealth means blessings and graces that bear fruit beyond one moment or one person, enriching families and future generations and becoming riches in heaven. The app does not replace a person's relationship with God, prayer, Scripture, conscience, church, family, or spiritual guidance. It serves the user as a guide, memory helper, and practical aid.

The product is Christian-first and ecumenical. Users may choose Catholic or general Christian grounding, but the default experience does not require explicit Catholic doctrines or fixed Catholic prayer formats.

## 2. Product principles

1. **God is central; the app is a tool.** SoulBuddy never presents itself as a spiritual authority or substitute for a personal relationship with God.
2. **Remembering is a duty, not decoration.** The app makes it easy to record, revisit, meditate on, and pass on the deeds of the Lord and a person's meaningful spiritual encounters.
3. **Action completes reflection.** Prayer should be able to lead to a small, concrete practice, commitment, or act of love.
4. **Options reduce friction.** Prefer clear choices and short prompts over broad, open-ended journaling questions.
5. **The Gospel governs the voice.** Copy should use clear, direct language grounded in Scripture and Christ's teaching. It must not imitate Jesus, invent sayings, or use cosmetic Christian phrases.
6. **Private by default.** A person's prayers, encounters, lessons, people, and commitments remain private unless that person deliberately shares a specific item.
7. **Local first.** Ordinary use must feel instant and remain useful without connectivity. The network synchronizes the experience; it does not gate it.
8. **No bloat.** Every screen and feature must serve prayer, practice, remembering, or trustworthy fellowship.

## 3. MVP audience and boundaries

The MVP serves adults who want a simple, structured Christian spiritual practice. It supports individuals and small, invitation-only Circles.

The MVP includes:

- a daily home experience;
- a prayer library ordered by community votes;
- guided prayer personalization;
- daily practices and commitments;
- structured recording and remembering;
- Scripture linking and reading from a local RSVCE source;
- invitation-only Circle conversations and structured sharing;
- optional AI-assisted prayer drafting;
- offline-first mobile and web behavior;
- moderation and content administration sufficient to operate the MVP.

The MVP excludes:

- public social feeds or follower counts;
- spiritual scoring, competitive streaks, leaderboards, or claims to measure holiness;
- anonymous public chat;
- clergy directories, sacramental records, donations, marketplace, or billing;
- live audio rooms, video, typing indicators, and presence;
- automatic theological interpretation of personal encounters;
- AI claims of revelation, prophecy, divine intent, or God's direct speech;
- full-featured collaborative document editing;
- child accounts.

## 4. Information architecture

The primary navigation is:

`Today · Prayers · Record · Remember · Circles`

### Today

Today is the smallest useful daily path. It surfaces:

- the selected prayer for today;
- one chosen or suggested practice;
- one short invitation to record or remember;
- unfinished commitments that are appropriate today;
- a subtle entry to recent Circle activity.

The screen must remain useful offline and must not become a dashboard of metrics. Completion is recorded without celebration effects that turn prayer into performance.

### Prayers

The Prayers area has two primary choices:

1. **Choose from the library**, ordered by votes with filters for purpose and grounding.
2. **Create personalized**, using a short sequence of choices.

Personalization choices include:

- style: daily/affirming or situational/special;
- reach: personal or encompassing/selfless;
- grounding: Catholic, general Christian, or another approved Christian framework added later;
- purpose or situation from a controlled list;
- optional selected Scripture, encounter, person, family, lesson, or commitment.

The result is an editable draft. The user owns the final wording. A generated prayer is clearly labelled as a draft, not revelation.

Each prayer may be paired with one practical action. Actions are concise, selectable, editable, and optional.

### Record

Record is optimized for speed and memory. The first choice is the record type:

- Encounter
- Lesson
- Commitment
- Prayer

The user then chooses relevant connections rather than facing an empty form:

- People
- Family or Circle
- Scripture
- Existing prayer

Short text is primary. Voice recording is available for encounters and lessons, but saving the record never waits for the audio upload.

### Remember

Remember is a calm archive, not an activity feed. It provides:

- recent encounters;
- Altars: encounters marked for lasting remembrance;
- prayers connected to encounters;
- lessons and commitments;
- views by people, family/Circle, and Scripture;
- resurfacing of meaningful records based on explicit user settings.

The main actions are `Remember`, `Meditate`, `Connect`, `Share`, and `Mark as Altar`. The app does not ask vague questions such as "What good seed was honoured?"

### Circles

Circles are private and invitation-only. Each Circle supports:

- durable text messages;
- structured shares of a prayer, encounter/testimony, lesson, commitment, or Scripture reference;
- simple reactions;
- Circle membership roles: owner, moderator, and member;
- report, mute, remove, and leave controls.

Sharing always creates an explicit shared representation. It never changes the visibility of the private source record. If the source is later edited, the shared item remains a deliberate snapshot unless the user chooses to update it.

## 5. Domain model

### Core records

- **Prayer:** authored, selected, or generated wording used for prayer.
- **Encounter:** a remembered event, answered prayer, deed of the Lord, or meaningful spiritual experience.
- **Lesson:** what the person has understood or learned through Scripture, prayer, a person, family, circumstances, or an encounter.
- **Commitment:** a concrete action or practice the person intends to carry out.

### Connections

- **Person:** someone connected to a record.
- **Family/Circle:** a family relationship or SoulBuddy Circle connected to a record.
- **Scripture reference:** translation, book, chapter, verse range, and optional selected excerpt.

### Derived meanings

- **Answered prayer:** a Prayer connected to an Encounter. It is not a separate record type.
- **Altar:** an Encounter marked for lasting remembrance.
- **Testimony:** an Encounter or Lesson deliberately shared with a Circle.

### Optional sequence

The app supports, but never forces, this sequence:

`Prayer → Encounter → Lesson → Commitment`

Records are linked through explicit relationship rows rather than nullable columns for every possible relationship. IDs are generated on the client using UUIDv7-compatible text identifiers so creation works offline.

Important text records maintain revisions. A concurrent edit from another device must not silently destroy an encounter, lesson, prayer, or commitment. One revision may become current while both remain recoverable.

## 6. Content and language system

SoulBuddy's voice is clear, restrained, warm, and spiritually conscious. It speaks to the user as a child of God without pretending that the app speaks for God.

### Required distinctions

The interface visually and semantically distinguishes:

- direct Scripture quotation;
- Scripture reference;
- paraphrase;
- prayer;
- lesson or learning content;
- personal record;
- AI-generated draft.

### Copy rules

- Keep primary instructions short.
- Put explanations behind `Learn`, `Why this matters`, or contextual tips.
- Prefer choices such as `A person`, `Scripture`, `Prayer`, or `An event` over "What happened?"
- Use "Record this" or "Remember this" when asking the user to preserve an encounter.
- Do not use invented biblical imagery, sentimental church language, or gamified praise.
- Do not say "keep this between you and God"; privacy is a user-controlled setting, and some experiences should be remembered or shared as testimony.
- Do not reduce remembering to Christ's words alone. Support remembrance of Scripture, people, family, lessons, answered prayer, and personal encounters.

Learning content is editorially reviewed, versioned, attributable, and removable without an app release.

## 7. AI behavior

AI assists only where it reduces writing friction.

### Prayer drafting

The server receives the user's selected style, reach, grounding, purpose, and only the private records the user explicitly selects. The generation contract requires:

- concise, editable prayer wording;
- no claim of divine authorship;
- no invented Bible quotation;
- no diagnosis of the user's spiritual state;
- no unsupported claim that an event was caused or spoken by God;
- Scripture references separated from generated wording;
- one optional practical action drawn from approved categories.

Private records are not silently added to prompts. Prayer generation is stateless at the model-provider boundary. SoulBuddy stores the user's request and accepted result under its own privacy rules; provider-side storage is disabled where supported and verified.

When offline, personalization choices and the draft request save locally. The request is processed after reconnection. The prayer library and previously saved prayers remain fully usable offline.

## 8. Local-first technical architecture

### Client

- Flutter stable for iOS, Android, and authenticated web.
- Riverpod for dependency injection and state coordination.
- `go_router` with stateful shell navigation for the five primary destinations.
- PowerSync's Flutter SDK for the encrypted local SoulBuddy SQLite database, reactive queries, upload queue, and replication.
- Direct repository interfaces over PowerSync SQL initially; no second ORM on the synced database.
- `flutter_secure_storage` for secrets and local database key material on native platforms.
- `record` and `just_audio` behind focused audio interfaces.
- platform notifications through `flutter_local_notifications` and Firebase Cloud Messaging where needed.

The client is organized by product feature, not by generic technical layer:

```text
app/
core/
features/today/
features/prayers/
features/record/
features/remember/
features/circles/
features/scripture/
features/settings/
```

Each feature owns its domain types, repositories, application services, presentation, and tests. Shared database, authentication, sync, design tokens, and observability live in `core`.

### Backend

- Laravel 13 modular monolith on a supported PHP runtime.
- PostgreSQL as permanent source of truth.
- Redis for queues, caching, and rate limiting.
- Laravel Sanctum for application sessions and a dedicated short-lived JWT endpoint for PowerSync.
- Laravel policies for every private and Circle-scoped mutation.
- PowerSync Open Edition, self-hosted beside the application stack, for PostgreSQL-to-client replication.
- Private S3-compatible object storage for audio and later media.
- Filament for editorial and operational administration.
- Pest for backend tests.
- Laravel Horizon, Pulse, Pennant, Scout, and Scramble where their documented capability is actually used.
- Spatie Activitylog for privileged administrative activity and MediaLibrary for managed media where appropriate.

The Laravel application remains authoritative. PowerSync accepts local client writes through a Laravel batch mutation endpoint; it does not bypass application policies.

### Durable chat

Circle messages are normal replicated records. PowerSync provides durable realtime delivery, offline creation, and recovery. Reverb or Centrifugo is not part of the MVP. A separate realtime service may be added later only for ephemeral features such as typing indicators or presence.

### Web behavior

The Flutter web app is an installable authenticated application, not the public marketing site. It uses PowerSync's OPFS-backed database where available and IndexedDB fallback otherwise. A custom service worker caches the app shell and required static assets. After the user saves important content, the app requests persistent browser storage in an understandable context.

Browser storage remains a cache of server-backed user data. The UI clearly handles private browsing, quota failure, and local storage eviction without presenting them as successful permanent offline storage.

## 9. Synchronization contract

1. Every ordinary read comes from the local database.
2. Every ordinary mutation commits locally first and updates the UI immediately.
3. The local data change and upload-queue entry are atomic.
4. Laravel processes uploaded mutations synchronously inside a database transaction.
5. Temporary server failures retain and retry the queued mutation.
6. Permanent validation or authorization failures are acknowledged without blocking the entire queue and are returned through a synced `sync_issues` record.
7. The client preserves the user's rejected text and shows a clear recovery action.
8. Server-created state returns through PowerSync replication and reconciles with the local optimistic state.
9. Deletions use recoverable archival or tombstones for personal spiritual records; permanent deletion is a separate explicit action.
10. Sync status stays unobtrusive unless data needs attention.

### Conflict rules

- Personal text records preserve revisions; the server selects a current revision without deleting alternatives.
- Commitments use explicit completion events rather than racing boolean counters.
- Prayer votes are unique `(user_id, prayer_id)` rows; aggregate counts are server-derived.
- Circle messages are append-only after a short correction window. Corrections create revisions.
- Reactions are unique per user, message, and reaction type.
- Membership and moderation always use server authority.

### Sync scopes

Each user receives only:

- their own private records and relationships;
- approved library and editorial content needed by the client;
- memberships and content for Circles they currently belong to;
- recent Circle history plus pinned or explicitly requested older content;
- their own sync issues and notification state.

Scripture text is not synchronized through PowerSync.

## 10. RSVCE Scripture source

SoulBuddy uses `C:\dev\catholicdaily-flutter\assets\rsvce.db` as its preferred local Scripture source. The database is utilized as read-only application content and is not exposed as a standalone downloadable feature or replicated through SoulBuddy.

The inspected source contains 73 books, 2,029 chapter records, and 36,083 verses. Its existing schema is retained conceptually but wrapped in a dedicated `ScriptureRepository` so the rest of the app never depends on raw table names.

Before application integration, create an optimized application copy with:

- a composite index on `verses(book_id, chapter_id, verse_id)`;
- a unique verse-address constraint where the source data permits it;
- canonical book aliases and normalized reference parsing outside the verse table;
- a manifest containing the source checksum, schema version, display name, canon, and application pack version;
- read-only opening and integrity checks.

The Scripture database is separate from the encrypted PowerSync user database. Mobile builds open the local application copy directly. Web initializes a browser-local read-only copy without blocking the rest of SoulBuddy's startup. Common linked passages may be prefetched after the main local UI is available.

## 11. Privacy and security

- Private records are scoped to their owner at the database, policy, sync-stream, and API layers.
- A Circle cannot query or infer a member's private source record.
- Shared snapshots contain only fields deliberately selected for sharing.
- Local user data is encrypted at rest where supported by the PowerSync Flutter SDK.
- Transport uses TLS.
- Object-storage access uses short-lived signed URLs; storage credentials never reach the client.
- Logs exclude prayer text, encounter text, generated drafts, audio, tokens, and Scripture excerpts.
- Administrative access is least-privilege, protected by strong authentication, and auditable.
- Account sign-out removes local private data and key material from that device after queued-write handling is resolved with the user.
- Account deletion is explicit, confirmed, queued for server processing, and followed by local erasure.

## 12. Performance and experience budgets

On representative mid-range mobile hardware:

- previously synchronized Today content appears from local storage without waiting for authentication refresh or sync;
- local mutation feedback is visible within 100 ms at the 95th percentile;
- common indexed local queries complete within 50 ms at the 95th percentile;
- application startup reaches a usable local shell within 2 seconds after a normal warm installation;
- scrolling maintains smooth frame delivery under representative lists;
- audio save records local metadata immediately and never waits for network transfer;
- initial and resumed synchronization are progressive and never blank an already usable screen.

Performance tests include a realistic private archive, a prayer library, multiple Circles, and at least 10,000 recent messages in the local test data. Web testing covers Chrome, Safari, Firefox, storage denial, offline restart, and a cleared browser cache.

## 13. Error handling

Errors are expressed in plain language with a next action:

- offline AI request: `Saved. Your prayer draft will be prepared when you're connected.`
- rejected Circle message: `This could not be shared. Your words are still saved.`
- expired Circle access: `You no longer have access to this Circle.`
- audio upload failure: the record remains saved and offers `Try upload again` or `Remove audio`;
- browser storage denial: the user can continue online and sees that offline availability is limited;
- Scripture initialization failure: prayer and record features remain usable while Scripture shows a focused retry action.

The app never presents a failed remote synchronization as data loss. Unexpected failures are captured without private content and correlated with server diagnostics through opaque identifiers.

## 14. Testing strategy

### Flutter

- unit tests for domain rules, formatting, reference parsing, and conflict behavior;
- repository contract tests against real temporary SQLite databases;
- widget tests for every primary choice flow and failure state;
- golden tests with Alchemist for the five primary destinations and accessibility text scaling;
- Patrol integration tests for onboarding, offline create/edit/restart, reconnection, Circle sharing, and notification deep links;
- accessibility checks for semantics, contrast, touch targets, keyboard navigation, and screen widths.

### Laravel

- Pest unit tests for policies and domain services;
- feature tests for authentication, batch mutation handling, Circle membership, moderation, AI request validation, and signed media URLs;
- PostgreSQL integration tests for constraints, revision preservation, idempotency, and transaction behavior;
- contract tests generated from the OpenAPI description used by Flutter;
- queue and rate-limit tests for AI, notifications, and media.

### Synchronization

- two-device convergence tests;
- airplane-mode creation and restart tests;
- duplicate upload and idempotency tests;
- expired-token recovery tests;
- permanent validation failure without queue blockage;
- concurrent private-record edit preservation;
- membership removal while offline;
- large initial sync and incremental sync performance;
- web OPFS and IndexedDB fallback tests.

All feature implementation follows test-driven development: a behavioral test is written and observed failing before production behavior is added.

## 15. Visual design direction

The interface should feel quiet, attentive, mature, and personal rather than ecclesiastical, ornamental, or wellness-generic.

- Use restrained typography, generous but efficient spacing, and a warm neutral foundation.
- Use color to communicate hierarchy and state, not to decorate every card.
- Keep Scripture, personal records, and generated material visually distinct.
- Avoid dashboards full of cards, excessive gradients, glowing effects, fake parchment, religious clip art, and streak celebrations.
- Motion should clarify navigation, recording, completion, and relationship between records. It must be quick, interruptible, and reduced when the platform requests reduced motion.
- Mobile interactions are thumb-friendly. Web layouts become wider and denser where useful without turning into a separate product.

The detailed token system and component specifications will be created as a dedicated design-system workstream using the approved product language and the installed Flutter-focused design guidance.

## 16. Delivery workstreams

The product is too broad for one safe implementation plan. Delivery is divided into working, testable increments:

1. **Foundation and local-first vertical slice:** Flutter/Laravel workspaces, design foundations, authentication boundary, PowerSync integration, local database, application shell, Today, quick Encounter recording, and Remember list.
2. **Prayer library and practices:** library, voting, prayer detail, Today selection, actions, and commitments.
3. **Guided prayer personalization and AI:** choice flow, provider abstraction, safety contract, offline request queue, editing, and accepted prayer storage.
4. **Remembering relationships:** people, family/Circle links, Scripture links, Altars, lessons, revision history, meditation, and resurfacing.
5. **Circles:** invitations, membership, durable chat, structured sharing, reactions, moderation, and offline rejection recovery.
6. **Audio and notifications:** encounter audio, transfer queue, playback, reminders, push notifications, and deep links.
7. **Administration and operational readiness:** Filament content management, moderation tools, observability, backups, privacy operations, performance testing, and deployment hardening.

Each workstream receives its own implementation plan and ends in demonstrably usable software. The first workstream proves the architecture before AI, chat, or media becomes a dependency.

## 17. Acceptance criteria for the first vertical slice

The first increment is accepted when a signed-in test user can:

1. open SoulBuddy on Flutter mobile or web and see previously stored Today content immediately;
2. disconnect the network;
3. record an Encounter using short guided choices;
4. see it immediately in Remember;
5. close and reopen the app and still see the Encounter;
6. reconnect and observe successful synchronization to Laravel/PostgreSQL;
7. open a second client and receive the Encounter;
8. edit the Encounter concurrently and recover both revisions;
9. open a linked RSVCE passage from the local Scripture repository;
10. complete the flow with no network-blocking spinner and no loss of entered text.

## 18. Research references

- PowerSync Flutter SDK: https://docs.powersync.com/client-sdks/reference/flutter
- PowerSync backend integration: https://docs.powersync.com/configuration/app-backend/client-side-integration
- PowerSync write validation: https://docs.powersync.com/handling-writes/handling-write-validation-errors
- PowerSync encryption: https://docs.powersync.com/client-sdks/advanced/data-encryption
- PowerSync Flutter web support: https://docs.powersync.com/client-sdks/frameworks/flutter-web-support
- PowerSync licensing: https://powersync.com/legal/licensing-terms
- Flutter web offline guidance: https://docs.flutter.dev/platform-integration/web/faq
- Browser persistent storage: https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist
- Laravel 13 release notes: https://laravel.com/docs/13.x/releases
- Superdesign Skill: https://github.com/superdesigndev/superdesign-skill
- Design Superskills: https://github.com/ericgandrade/design-superskills
