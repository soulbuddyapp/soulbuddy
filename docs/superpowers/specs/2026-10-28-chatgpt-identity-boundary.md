# SoulBuddy ChatGPT: Stable OAuth identity boundary

Status: implemented in draft PR #20. Production identity and refresh-token acceptance remain open.

A SoulBuddy record belongs to its immutable internal user ID. Each OAuth link is keyed by exact issuer and subject, not email, because email can change or be reassigned.

### New account
Read-only calls never create accounts. A new account requires confirmed consent and a verified provider email. It must refuse any email already used by another SoulBuddy account, rather than silently joining records.

### Existing account link
The verified SoulBuddy account owner requests a one-time 128-bit code through the authenticated Sanctum API. A separate OAuth-authenticated ChatGPT session submits the code with consent. The two sessions prove control independently. The link requires matching verified emails and no conflicting provider association. Codes are hashed at rest, expire in ten minutes, and cannot be replayed. An authenticated local unlink removes the binding and pending codes immediately without pretending to revoke the provider session.

### Release compatibility
These tables do not modify existing Flutter Goals, prayers or installation sessions. No Android UI exists for link-code issuance yet; user-facing documentation must not claim otherwise. Existing synthetic staged accounts must be deliberately re-linked or recreated after approved staging-only backup, never backfilled by email. Production release also requires verifying an actual ChatGPT refresh after expiry, access/grant revocation, reconnect and scheduled reminder delivery.
