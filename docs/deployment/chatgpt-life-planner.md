# SoulBuddy ChatGPT Life Planner — release runbook

## Current state

This integration shares SoulBuddy's Laravel API and user table, but introduces its own **life planner tables** for seven-day plans, individual actions, observed check-ins and user-authored reviews. Existing Android and Flutter Goal/Today records are **not yet synced with these new tables**; do not imply cross-device progress parity. The plugin is free to use; no in-ChatGPT digital subscription checkout.

The launch consists of three independently verified gates: backend production release, OAuth identity provider and live connection, then OpenAI plugin submission.

## Gate 1: OAuth resource security (required before publication)

Use a mature OAuth provider with Authorization Code + PKCE S256, discovery metadata, and CIMD (or DCR and adjusted mcp.json). Configure a resource/API whose audience is exactly `https://sbuddy.elbiblio.com/mcp`. The provider must issue a **JWT RS256 access token** (not merely an ID token) with matching issuer, audience and `life.read`/`life.write` scopes.

The resource server currently maps the *verified email claim* of the trusted access JWT to the corresponding verified SoulBuddy user; unverified installation email is not taken over. Configure verified, normalized email before using this bridge; testing must cover address changes, reassignment and claims integrity. New email accounts are created as verified SoulBuddy users. Linking to an existing unverified anonymous Android installation is **not supported**; create an explicit merge flow before advertising that feature.

**Release blocker: live revocation and disconnect.** The resource server verifies the signed JWT locally and then checks the same token against the configured introspection endpoint on every protected call. It fails closed if the response is unavailable, inactive, malformed, or reports a different subject. Tests and the isolated Keycloak staging probe cover explicit token revocation. A disconnected ChatGPT connection is not proof that the provider revoked the access token or grant. Test that actual disconnect/revocation changes the provider's introspection response; if not, implement and verify an explicit revocation path before claiming immediate disconnect.

### Staging candidate: Keycloak

Use a dedicated staging Keycloak realm and a separate staging Laravel database and HTTPS host; never connect staging to production personal records. Keycloak supports introspection and token revocation. Its [MCP guidance](https://www.keycloak.org/securing-apps/mcp-authz-server) labels resource indicators and CIMD experimental, so prove compatibility before choosing it for production. Prefer a pre-registered ChatGPT client where practical rather than opening dynamic client registration. Do not enable experimental features or public registration on an existing shared identity service without reviewing their effect.

For the staging candidate, configure an API/resource client allowed to introspect and issue a separate confidential client credential for the Laravel resource server. Keycloak 26.6.2 and newer [require the introspecting client in the token audience](https://www.keycloak.org/docs/latest/upgrading/index.html); retain the exact MCP resource audience and configure the introspector's audience as required. Do not enable the deprecated audience-check bypass. Verify `life.read`, `life.write`, `sub`, email and email-verification claims in actual access tokens and introspection responses. Verify resource binding end to end; the selected provider must not silently ignore the `resource` parameter. The introspection client must be authorized only for this resource and its secret must stay in protected server configuration.

Use the exact issuer string from the provider's discovery metadata, including whether it ends in `/`; the server does not normalize it. Verify the provider's metadata, access-token `iss`, callback, and resource audience together in a real staging authorization flow.

### Temporary staging deployment (2026-10-28)

An isolated test deployment on the existing host exposes `https://sbuddy.elbiblio.com/sb-stage/mcp` and its resource metadata at `https://sbuddy.elbiblio.com/sb-stage/.well-known/oauth-protected-resource`. Its Laravel API uses a separate SQLite database under `/var/snap/docker/common/soulbuddy/staging/life-planner-938bbef`; it contains commit `938bbef` with the path-prefix fix from `e7433d1` and the concise empty-plan message applied. It does not use production personal records.

The staging identity service is a separate Keycloak 26.8.1 container and PostgreSQL database on an internal Docker network. Its `soulbuddy-staging` realm has registration disabled, brute-force protection enabled, and a pre-registered public PKCE client with the ChatGPT callback. Resource indicators are experimental in this Keycloak configuration. The test reviewer is synthetic; protected staging credentials are stored on the host under `/var/snap/docker/common/soulbuddy/staging/keycloak-https-938bbef`, not in this repository. The Nginx snippet is `/etc/nginx/snippets/soulbuddy-mcp-staging-938bbef.conf`; a pre-change site backup is `/etc/nginx/sites-available/sbuddy.before-mcp-staging-938bbef`. The public identity route exposes the realm and static resources, while the admin route is blocked.

An isolated probe completed authorization code with PKCE, checked issuer, audience and scopes, made an authenticated MCP read, and confirmed that an explicitly revoked token was rejected. The probe reached the host's Nginx locally while preserving the public hostname and TLS validation. A personal ChatGPT staging plugin was subsequently connected to the synthetic reviewer account. ChatGPT's automatic OAuth discovery initially failed, so its public client, scopes, issuer, endpoints, resource and PKCE were entered manually, and its generated callback was registered in the staging client. A read-only ChatGPT tool call returned the expected empty active plan.

The host's general Nginx dotfile rule also blocked the standard discovery paths. The staging snippet now has exact-match routes for `/.well-known/oauth-protected-resource/sb-stage/mcp` and `/.well-known/oauth-authorization-server/sb-stage-auth/realms/soulbuddy-staging`; both returned HTTP 200 externally. Its pre-change backup is `/etc/nginx/snippets/soulbuddy-mcp-staging-938bbef.before-discovery.conf`. Retest automatic discovery from ChatGPT: public HTTP checks alone do not prove it works from ChatGPT. A later call to the personal connector returned `oauth_token_invalid_grant` and requested reauthentication. The staging realm has a 5-minute access-token lifetime and a 30-minute SSO idle timeout; the idle timeout is a plausible cause, but the failure has not been traced to it. Investigate session and refresh-token behavior and verify reconnect before release.

The ChatGPT test does not establish that disconnect revokes its grant or that the deployment is ready for production. The staging API uses PHP's built-in server, containers have no restart policy, and the Nginx identity upstream points to a Docker container IP that may change if it is recreated. Repair the upstream and validate Nginx before restarting a recreated identity container. Do not use this staging deployment for real users or rely on it surviving a host restart.

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
CHATGPT_OAUTH_EMAIL_CLAIM=https://soulbuddy.app/email
CHATGPT_OAUTH_VERIFIED_CLAIM=https://soulbuddy.app/email_verified
```

Have your provider add the two namespaced email claims to the **access token** and make email-verified=true only after actual email verification. The provider itself must expose `openid`/`email` UserInfo for OpenAI workspace-domain protections. The introspection endpoint must support OAuth client-secret Basic authentication and return boolean `active` and the same `sub` as the signed token. It must use HTTPS, and redirects are rejected. Provider failures deny protected calls; plan for availability and latency monitoring without logging tokens or reflections.

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

## Gate 3: Public Plugin Directory

- The portable package is in `integrations/chatgpt-plugin`. Plan history includes archived plans and supports paged discovery and deletion; verify those flows with the reviewer account.
- Provide *reviewed, live* product website, support, privacy policy and terms URL. Policies must explain personal planning notes, spiritual data sensitivity, hosting, retention, sharing, and deletion.
- Verify the publisher business/individual identity and MCP domain on OpenAI Platform; confirm the organization role can submit plugins.
- Provide a reviewer OAuth account with no MFA, SMS or email OTP blockers and seeded **non-sensitive** sample plan. Never disclose real personal reflection content.
- Open https://platform.openai.com/apps-manage and submit the production remote MCP endpoint under **With MCP**, inspect tool scan and errors, add five positive and three negative test cases from `review-cases.md`.
- Record observed OAuth, security and privacy review outcomes. Submission and approval are separate from GitHub deployment.

## Not in the MVP

A Flutter-native rendering of the seven-day planner; cross-device synchronization with local-first Goals; paid entitlements; push reminders from ChatGPT; clinical counseling; generated prayers; spiritual scoring. Each needs its own reviewed tranche.
