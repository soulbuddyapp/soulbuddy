# SoulBuddy ChatGPT — privacy and publication evidence inventory

**Internal release-review document, not a public privacy policy or legal advice.** Prepared from the current repository; confirm infrastructure, operator identity, actual vendors and applicable law before publishing policy or terms.

## What the implementation demonstrably handles

| Item | Purpose | Storage/flow | User action |
| --- | --- | --- | --- |
| OAuth issuer + subject | Map a ChatGPT identity to one internal SoulBuddy account | Laravel `chatgpt_oauth_identities` including fixed-size SHA-256 lookup key | Authenticated SoulBuddy owner may unlink |
| Verified email | Enroll or link an account only after confirming identity | Existing SoulBuddy `users` account; no private-record lookup by email alone | Existing account owner must approve one-time linking |
| OAuth access token | Authenticate request and check issuer, expiry, audience, scopes and live active status | Passed to configured HTTPS provider introspection endpoint; JWKS responses cached | Provider application-session termination must be tested for revocation |
| One-time link codes | Prove control over existing SoulBuddy account | 128-bit value sent once over authenticated TLS, SHA-256 hash held server-side for 10 minutes; new code invalidates old | Owner can regenerate or unlink; expired hashes scheduled for daily deletion |
| Seven-day plan, daily commitment | Retain approved plan | `life_plans`, `life_plan_items` | Read, replace (archive), explicitly delete |
| Check-in, optional note | Track self-reported daily outcome | `life_plan_checkins` | User confirms write; deleted with owning plan |
| Weekly reflection | Store user-authored review | `life_plan_reviews` | User confirms write; deleted with owning plan |
| ChatGPT scheduled reminder | Optional, external scheduling | ChatGPT scheduled task service (not stored or delivered by SoulBuddy Laravel) | Opt in; task modification/pausing/deletion via ChatGPT |
| Flutter link code display | Move link code between trusted app and ChatGPT | In-memory UI; user-initiated clipboard copy | Code hidden on app background; server expires it |

The stored plan and review are private user content, often indicative of spiritual or religious practices. Handle them as sensitive personal data regardless of whether the user volunteers them. Review of a week never measures holiness. No automatic generated prayer writing is introduced.

## Verify before publishing any privacy policy, terms or support URL

- Legal entity and accountable support/privacy contact; verified operator domain, address and email. Do not invent a contact or insert a placeholder public URL.
- Infrastructure location, cross-border processing, data processors and contractual terms (ChatGPT/OpenAI, OAuth provider, Firebase and Deepgram where opted-in).
- Complete retention and deletion rules for production database backups, cache, application/access logs and account deletion; explicit plan deletion is **not** complete account erasure.
- What third parties receive when the person invokes a tool or enables notification details; ChatGPT itself manages chat history and reminders under its own controls.
- Whether app data is used for training, analytics, product emails or marketing. Do not assert a negative without real operational evidence.
- Required rights, age/access restrictions, lawful basis, breach handling, and privacy-policy versioning in target jurisdictions.
- An accessible `/privacy`, `/terms` and working support destination. Settings currently references `/privacy`, but repository routes do not yet implement that URL. Verify the deployed server before advertising it.
- Confirm existing users have appropriate notices and an opt-in linking choice. A read-only OAuth request must never provision users.

## Completion criterion

A reviewed, publicly reachable privacy notice and terms accurately reflecting deployed processing, plus tested support and deletion channels, are required before Plugin Directory submission. Keep the plugin manifest's legal links unset until verified; a proposal document is not a published policy.
