# SoulBuddy ChatGPT Life Planner — release runbook

## Current state

This integration shares SoulBuddy's Laravel API and user table, but introduces its own **life planner tables** for seven-day plans, individual actions, observed check-ins and user-authored reviews. Existing Android and Flutter Goal/Today records are **not yet synced with these new tables**; do not imply cross-device progress parity. The plugin is free to use; no in-ChatGPT digital subscription checkout.

The launch consists of three independently verified gates: backend production release, OAuth identity provider and live connection, then OpenAI plugin submission.

## Seven-day renewal, historical reviews and safe deletion

An approved new plan automatically archives the previous plan only after all seven days have elapsed in the previous plan's own IANA timezone and the new plan begins on a nonoverlapping calendar date. Replacing an upcoming or unfinished plan still requires explicitly approved `replace_active`. Completed plans remain readable until the user creates a new plan or deletes them; passage of time alone does not silently archive records.

`review_week` can now target a specific archived `plan_id`, and `save_weekly_review` can save a review to that user's archived plan without switching the active week. Check-ins are allowed only from the planned local date onward, are serializable against plan replacement and return the actual changed week. Never infer a future action was completed, or treat a missing observation as a spiritual judgment.

The new additive migration `2026_10_29_000000_create_life_planner_deleted_requests.php` creates `life_plan_deleted_requests`. When an owned plan is deliberately deleted, its contents and related rows are removed via foreign-key cascade, but the server retains only `user_id`, opaque `request_id` and marker timestamp. This prevents a delayed, previously approved request from recreating deleted content. The marker itself cascades on full parent-account deletion. Reusing a deleted request ID fails closed; a genuinely new approved plan needs a fresh UUID. Do not prune deletion markers independently during the lifetime of an account or change the deletion behavior without reviewing the privacy notice and retention policy.

Before staging rollout, run schema migrations, then specifically test archival on the eighth calendar day, late review of an archived week, future-day check-in rejection around timezone midnight, deleted-request replay, and full account cascade. Preserve backups and do not run destructive schema rollback automatically.



## Gate 1: OAuth resource security (required before publication)

Use a mature OAuth provider with Authorization Code + PKCE S256, discovery metadata, and CIMD (or DCR and adjusted mcp.json). Configure a resource/API whose audience is exactly `https://sbuddy.elbiblio.com/mcp`. The provider must issue a **JWT RS256 access token** (not merely an ID token) with matching issuer, audience and `life.read`/`life.write` scopes.

**Stable account identity (PR #20, not production):** The exact (OAuth issuer, subject) is now the account key, never the email address. Read-only calls do not create users. An unlinked provider identity can check its status. New account creation requires explicit approval and a verified email claim; when the email is already used by another local user, the service refuses to take over that account.

Existing verified SoulBuddy owners can authenticate to the existing Laravel API and explicitly request a ten-minute, one-use 128-bit code from POST /api/account/chatgpt/link-codes with confirmed=true. Only the hash is stored. They then approve linking from the authenticated ChatGPT tool using the same code. The code, matching verified email, issuer, subject and live introspection must all succeed. Unverified installations cannot link. Users can unlink from the authenticated SoulBuddy API at POST /api/account/chatgpt/unlink, which immediately removes local access but **does not revoke provider tokens**.

**Mobile code-entry support is implemented in the feature branch, not yet published.** Settings → ChatGPT life planner can request, display and copy a ten-minute code after email verification, show connection status and unlink after confirmation. The code is stored only in in-memory UI state, hidden when the app leaves the foreground and not logged or saved to app storage. Users still need the OAuth-authenticated ChatGPT tool to finish linking. Verify with Flutter CI and an actual release build before advertising this to installed Android users. Existing accounts (including old synthetic staging accounts) will not be backfilled by email. Back up the staging database, then link through an authenticated verified local session or recreate only explicitly approved synthetic test records. Do not infer ownership from a matching email; email reassignment cannot transfer a plan to a different provider subject.

**Release blocker: live revocation and disconnect.** The resource server verifies the signed JWT locally and then checks the same token against the configured introspection endpoint on every protected call. It fails closed if the response is unavailable, inactive, malformed, or reports a different subject. On 2026-10-28, a real staging ChatGPT access token remained active after the user disconnected the account in ChatGPT, and the API accepted a read with that same token. Explicitly revoking that token at Keycloak made introspection report inactive and the API denied it. Implement and verify a user-accessible provider-side grant or session revocation path before publication; do not claim ChatGPT disconnect immediately revokes the provider grant. Also verify that any refresh token is invalidated, other sessions remain appropriately scoped, and stale access is denied immediately.

### Staging candidate: Keycloak

Use a dedicated staging Keycloak realm and a separate staging Laravel database and HTTPS host; never connect staging to production personal records. Keycloak supports introspection and token revocation. Its [MCP guidance](https://www.keycloak.org/securing-apps/mcp-authz-server) labels resource indicators and CIMD experimental, so prove compatibility before choosing it for production. Prefer a pre-registered ChatGPT client where practical rather than opening dynamic client registration. Do not enable experimental features or public registration on an existing shared identity service without reviewing their effect.

For the staging candidate, configure an API/resource client allowed to introspect and issue a separate confidential client credential for the Laravel resource server. Keycloak 26.6.2 and newer [require the introspecting client in the token audience](https://www.keycloak.org/docs/latest/upgrading/index.html); retain the exact MCP resource audience and configure the introspector's audience as required. Do not enable the deprecated audience-check bypass. Verify `life.read`, `life.write`, `sub`, email and email-verification claims in actual access tokens and introspection responses. Verify resource binding end to end; the selected provider must not silently ignore the `resource` parameter. The introspection client must be authorized only for this resource and its secret must stay in protected server configuration.

Use the exact issuer string from the provider's discovery metadata, including whether it ends in `/`; the server does not normalize it. Verify the provider's metadata, access-token `iss`, callback, and resource audience together in a real staging authorization flow.

### Temporary staging deployment (2026-10-28)

An isolated test deployment on the existing host exposes `https://sbuddy.elbiblio.com/sb-stage/mcp` and its resource metadata at `https://sbuddy.elbiblio.com/sb-stage/.well-known/oauth-protected-resource`. Its Laravel API uses a separate SQLite database under `/var/snap/docker/common/soulbuddy/staging/life-planner-938bbef`; it contains commit `938bbef`, the life-planner service from `0d89a34`, and the identity, controller and service configuration from `3db4e9c`. It does not use production personal records. Backups of the files and protected environment changed for access controls end in `.before-access-controls-3db4e9c`; backups before the reminder change end in `.before-reminders-0d89a34`.

The staging identity service is a separate Keycloak 26.8.1 container and PostgreSQL database on an internal Docker network. Its `soulbuddy-staging` realm has registration disabled, brute-force protection enabled, and a pre-registered public PKCE client with the ChatGPT callback. Resource indicators are experimental in this Keycloak configuration. The test reviewer is synthetic; protected staging credentials are stored on the host under `/var/snap/docker/common/soulbuddy/staging/keycloak-https-938bbef`, not in this repository. The Nginx snippet is `/etc/nginx/snippets/soulbuddy-mcp-staging-938bbef.conf`; a pre-change site backup is `/etc/nginx/sites-available/sbuddy.before-mcp-staging-938bbef`. The public identity route exposes the realm and static resources, while the admin route is blocked.

An isolated probe completed authorization code with PKCE, checked issuer, audience and scopes, made an authenticated MCP read, and confirmed that an explicitly revoked token was rejected. The probe reached the host's Nginx locally while preserving the public hostname and TLS validation. A personal ChatGPT staging plugin was subsequently connected to the synthetic reviewer account. ChatGPT's automatic OAuth discovery initially failed, so its public client, scopes, issuer, endpoints, resource and PKCE were entered manually, and its generated callback was registered in the staging client. A read-only ChatGPT tool call returned the expected empty active plan.

The host's general Nginx dotfile rule also blocked the standard discovery paths. The staging snippet now has exact-match routes for `/.well-known/oauth-protected-resource/sb-stage/mcp` and `/.well-known/oauth-authorization-server/sb-stage-auth/realms/soulbuddy-staging`; both returned HTTP 200 externally. Its pre-change backup is `/etc/nginx/snippets/soulbuddy-mcp-staging-938bbef.before-discovery.conf`. ChatGPT subsequently discovered the staging issuer, endpoints, resource and scopes automatically. It selected dynamic client registration because Keycloak advertises a registration endpoint, but an anonymous registration request was rejected by the trusted-host policy. The existing staging connection uses the pre-registered public client; select and validate an actual client registration strategy for production rather than relying on the advertised endpoint.

A later call to the personal connector returned `oauth_token_invalid_grant` and requested reauthentication. Reconnection initially failed because the proxy response buffer was too small for the identity provider's response headers; increasing the staging realm proxy buffer to 32 KiB resolved that failure, and ChatGPT reconnected and read the plan. The staging realm has a 5-minute access-token lifetime and a 30-minute SSO idle timeout; the idle timeout is a plausible cause of the invalid refresh grant, but it has not been proven. Investigate session and refresh-token behavior before release.

During the disconnect test, a disposable copy of the actual staging access token was held in a mode-0600 file inside the API container. While it was still unexpired, ChatGPT disconnect did not make it inactive and a direct read with it succeeded. Explicit revocation then made introspection return inactive and the same read fail. The temporary token file and capture instrumentation were removed afterward, and the staging connection was restored. This test did not prove what happens to the refresh token; do not use the result to make claims about refresh-grant revocation.

As a possible user-controlled mitigation, the staging Keycloak account console's **Applications → End application session** action was also tested while a real ChatGPT access token was active. After the user ended the staging application's session, introspection returned inactive and the API rejected the same token. Keycloak documents this action as ending online and offline sessions for that application, but it does not remove consent and browser SSO can start a new session; see the [Keycloak account-console documentation](https://www.keycloak.org/docs/latest/server_admin/). The test did not exercise the actual ChatGPT refresh token. A production solution still needs a discoverable user flow, accurate copy about both ChatGPT disconnect and provider-side session termination, provider and access-control review, and verified refresh and reconnect behavior. Do not assume that terminating an identity-provider session automatically revokes consent or guarantees that every provider's outstanding tokens are invalidated.

The ChatGPT test does not establish that disconnect revokes its grant or that the deployment is ready for production. The staging API uses PHP's built-in server, containers have no restart policy, and the Nginx identity upstream points to a Docker container IP that may change if it is recreated. Repair the upstream and validate Nginx before restarting a recreated identity container. Do not use this staging deployment for real users or rely on it surviving a host restart.

### Identity migration and refresh/revocation release acceptance

Before deploying this change to isolated staging, apply the new additive identity and one-time-code migrations and back up any existing synthetic tester data. Confirm an unlinked OAuth identity cannot read data or create a user silently; verify both explicit new-account creation and secure one-time linking into a pre-existing verified SoulBuddy user. Attempt replay, expired, mismatched and cross-account linking codes, and verify unlink denies a still-active OAuth token. No email-based migration or automatic user merges are permitted.

For actual provider reliability (not mock tests), verify the complete sequence with disposable non-sensitive accounts: (1) connect ChatGPT using PKCE and read an authorized plan; (2) after the access token's five-minute lifetime, prove ChatGPT can refresh and read again without prompting for credentials; (3) disconnect in ChatGPT and independently check whether the provider grant and token remain active; (4) end the SoulBuddy application session at the identity provider and verify both outstanding access and refresh grants are unusable, while the MCP API fails closed; (5) reconnect the same subject and confirm it reaches only its explicitly bound user; (6) repeat a scheduled daily read across token expiry and separately verify notification delivery. Record outcomes and errors, never token or personal reflection values. A passing local PHPUnit suite cannot replace this test.

The older staged API and Keycloak reviewer account may not contain the new identity schema. Do not point this code at real production personal data until the new reviewer flow and the provider refresh/disconnect matrix have been observed successfully.

For rollback, remove only the staging include from the active Nginx site, validate with `nginx -t` and reload; stop the staging API, identity and database containers after confirming no test is in progress. Retain the protected staging database and credentials until their owner authorizes deletion. Do not restore the entire old site file over subsequent production changes.

Configure only in the protected production `.env` (do not commit credentials):

```dotenv
APP_URL=https://sbuddy.elbiblio.com
CHATGPT_OAUTH_ISSUER=https://YOUR-OAUTH-PROVIDER.example/
CHATGPT_OAUTH_AUDIENCE=https://sbuddy.elbiblio.com/mcp
CHATGPT_OAUTH_JWKS_URL=https://YOUR-OAUTH-PROVIDER.example/.well-known/jwks.json
CHATGPT_OAUTH_INTROSPECTION_URL=https://YOUR-OAUTH-PROVIDER.example/introspect
CHATGPT_OAUTH_INTROSPECTION_CLIENT_ID=YOUR-RESOURCE-CLIENT-ID
CHATGPT_OAUTH_INTROSPECTION_CLIENT_SECRET=YOUR-RESOURCE-CLIENT-SECRET
CHATGPT_OAUTH_ACCOUNT_MANAGEMENT_URL=https://YOUR-OAUTH-PROVIDER.example/account/
CHATGPT_OAUTH_EMAIL_CLAIM=https://soulbuddy.app/email
CHATGPT_OAUTH_VERIFIED_CLAIM=https://soulbuddy.app/email_verified
```

Have your provider add the two namespaced email claims to the **access token** and make email-verified=true only after actual email verification. The provider itself must expose `openid`/`email` UserInfo for OpenAI workspace-domain protections. The introspection endpoint must support OAuth client-secret Basic authentication and return boolean `active` and the same `sub` as the signed token. It must use HTTPS, and redirects are rejected. Provider failures deny protected calls; plan for availability and latency monitoring without logging tokens or reflections.

The optional account-management URL must be HTTPS, share the issuer's origin, contain no credentials, query or fragment, and lead to a provider control that has been verified to end the person's SoulBuddy application session. `get_connection_management` is available without a token so a person can find those controls after disconnecting; it only returns a link and does not revoke anything. A configured link does not clear the release blocker: verify actual access-token and refresh-token behavior and the user's full disconnect flow with the production provider.

Do not mistake `ChatGPT_OAUTH_ISSUER` for SoulBuddy's Laravel URL. Avoid reusing installation secrets or PowerSync tokens. The provider must echo the OAuth `resource` argument through the flow. Configure ChatGPT's discovered callback redirect URL before testing. Tokens, authorization codes and private reflections must not appear in logs.

## Gate 2: Deploy backend safely

The existing production architecture at `sbuddy.elbiblio.com` is immutable Laravel releases, both Nginx's `/var/www/soulbuddy/current` and confined Snap Docker mirror `/var/snap/docker/common/soulbuddy/releases/<commit>`. Follow [existing runbook](./sbuddy.elbiblio.com.md) for the actual host path and rollback.

1. Wait for PHP CI (feature, authorization, existing Goal and account regressions) and review migrations. Merge only after approval.
2. Fetch the reviewed commit on the host into **new** immutable release directories; never deploy an unreviewed feature branch to production.
3. Install production Composer dependencies, link protected `.env` and writable `storage`, run `php artisan migrate --force`, refresh route/config caches, then atomically switch **both** mirror and Nginx release pointers to the same commit; restart `soulbuddy-api`.
4. Confirm Nginx forwards `Authorization` to PHP-FPM (the configuration now includes `fastcgi_param HTTP_AUTHORIZATION $http_authorization;`); TLS and redirects must not drop OAuth bearer headers.
5. Configure narrowly scoped production metadata routes ahead of the general dotfile denial for both `/.well-known/oauth-protected-resource/mcp` and `/.well-known/oauth-protected-resource`. Route them to the Laravel protected-resource handler; do not disable the dotfile rule globally. Verify the configured identity provider's standard discovery paths too.
6. Verify health `/up`, MCP anonymous initialize/tools/list and `get_planning_guide`, protected resource discovery and then fully authenticated write/read/delete. Confirm no server stack traces or secrets in tool responses.
7. Roll back both pointers and container if regressions appear. Preserve migrated data on rollback; do not roll back migrations automatically. Keep existing prayer, Goal and install sessions intact.

Example smoke tests after deployment (all demo data in a disposable account):

```bash
curl -i https://sbuddy.elbiblio.com/.well-known/oauth-protected-resource
curl -i -H 'Content-Type: application/json' https://sbuddy.elbiblio.com/mcp \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}'
curl -i -H 'Content-Type: application/json' https://sbuddy.elbiblio.com/mcp \
  --data '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

Use MCP Inspector to perform OAuth connection with a real nonproduction identity and test authorization, token expiry, wrong issuer and audience, cross-user isolation, denial of unapproved mutations, and account deletion. Then repeat from ChatGPT.

## Gate 2a: Mobile account-linking acceptance

The new Flutter Settings section is separate from the ChatGPT OAuth provider and uses the existing installation's Sanctum token. Confirm in an Android/iOS test build that the user can verify email, request a one-use code, copy it into the ChatGPT linking tool and subsequently see the connected state. Verify the code is not in device storage, is hidden on backgrounding, expires server-side after ten minutes and that generating another code invalidates the earlier code.

Unlinking via the app removes SoulBuddy's provider-to-user association, but does not delete the life plan, revoke access tokens at Keycloak or disconnect ChatGPT's own connection. Validate this exact distinction in the interface. Reconcile the installed app release version and backend migration before enabling the UI in production.

The Laravel scheduler deletes expired link-code hashes once daily. Verify that the server cron is active and the new command runs after schema migration; no historical migration of email-based associations is allowed.


## Gate 3: Public Plugin Directory

- The portable package is in `integrations/chatgpt-plugin`. Plan history includes archived plans and supports paged discovery and deletion; verify those flows with the reviewer account.
- Provide *reviewed, live* product website, support, privacy policy and terms URL. Policies must explain personal planning notes, spiritual data sensitivity, hosting, retention, sharing, and deletion.
- Verify the publisher business/individual identity and MCP domain on OpenAI Platform; confirm the organization role can submit plugins.
- Provide a reviewer OAuth account with no MFA, SMS or email OTP blockers and seeded **non-sensitive** sample plan. Never disclose real personal reflection content.
- Open https://platform.openai.com/apps-manage and submit the production remote MCP endpoint under **With MCP**, inspect tool scan and errors, add five positive and three negative test cases from `review-cases.md`.
- Record observed OAuth, security and privacy review outcomes. Submission and approval are separate from GitHub deployment.

## Not in the MVP

A Flutter-native rendering of the seven-day planner; cross-device synchronization with local-first Goals; paid entitlements; a SoulBuddy-operated notification service; clinical counseling; generated prayers; spiritual scoring. Each needs its own reviewed tranche. Opt-in reminders through ChatGPT scheduled tasks are being implemented and require a real scheduled-run and notification-delivery test before they can be advertised.
