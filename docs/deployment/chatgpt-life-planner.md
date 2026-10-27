# SoulBuddy ChatGPT Life Planner — release runbook

## Current state

This integration shares SoulBuddy's Laravel API and user table, but introduces its own **life planner tables** for seven-day plans, individual actions, observed check-ins and user-authored reviews. Existing Android and Flutter Goal/Today records are **not yet synced with these new tables**; do not imply cross-device progress parity. The plugin is free to use; no in-ChatGPT digital subscription checkout.

The launch consists of three independently verified gates: backend production release, OAuth identity provider and live connection, then OpenAI plugin submission.

## Gate 1: OAuth resource security (required before publication)

Use a mature OAuth provider with Authorization Code + PKCE S256, discovery metadata, and CIMD (or DCR and adjusted mcp.json). Configure a resource/API whose audience is exactly `https://sbuddy.elbiblio.com/mcp`. The provider must issue a **JWT RS256 access token** (not merely an ID token) with matching issuer, audience and `life.read`/`life.write` scopes.

The resource server currently maps the *verified email claim* of the trusted access JWT to the corresponding verified SoulBuddy user; unverified installation email is not taken over. Configure verified, normalized email before using this bridge; testing must cover address changes and claims integrity. New email accounts are created as verified SoulBuddy users. Linking to an existing unverified anonymous Android installation is **not supported**; create an explicit merge flow before advertising that feature.

Configure only in the protected production `.env` (do not commit credentials):

```dotenv
APP_URL=https://sbuddy.elbiblio.com
CHATGPT_OAUTH_ISSUER=https://YOUR-OAUTH-PROVIDER.example/
CHATGPT_OAUTH_AUDIENCE=https://sbuddy.elbiblio.com/mcp
CHATGPT_OAUTH_JWKS_URL=https://YOUR-OAUTH-PROVIDER.example/.well-known/jwks.json
CHATGPT_OAUTH_EMAIL_CLAIM=https://soulbuddy.app/email
CHATGPT_OAUTH_VERIFIED_CLAIM=https://soulbuddy.app/email_verified
```

Have your provider add the two namespaced email claims to the **access token** and make email-verified=true only after actual email verification. The provider itself must expose `openid`/`email` UserInfo for OpenAI workspace-domain protections.

Do not mistake `ChatGPT_OAUTH_ISSUER` for SoulBuddy's Laravel URL. Avoid reusing installation secrets or PowerSync tokens. The provider must echo the OAuth `resource` argument through the flow. Configure ChatGPT's discovered callback redirect URL before testing. Tokens, authorization codes and private reflections must not appear in logs.

## Gate 2: Deploy backend safely

The existing production architecture at `sbuddy.elbiblio.com` is immutable Laravel releases, both Nginx's `/var/www/soulbuddy/current` and confined Snap Docker mirror `/var/snap/docker/common/soulbuddy/releases/<commit>`. Follow [existing runbook](./sbuddy.elbiblio.com.md) for the actual host path and rollback.

1. Wait for PHP CI (feature, authorization, existing Goal and account regressions) and review migrations. Merge only after approval.
2. Fetch the reviewed commit on the host into **new** immutable release directories; never deploy an unreviewed feature branch to production.
3. Install production Composer dependencies, link protected `.env` and writable `storage`, run `php artisan migrate --force`, refresh route/config caches, then atomically switch **both** mirror and Nginx release pointers to the same commit; restart `soulbuddy-api`.
4. Confirm Nginx forwards `Authorization` to PHP-FPM (the configuration now includes `fastcgi_param HTTP_AUTHORIZATION $http_authorization;`); TLS and redirects must not drop OAuth bearer headers.
5. Verify health `/up`, MCP anonymous initialize/tools/list and `get_planning_guide`, protected resource discovery and then fully authenticated write/read/delete. Confirm no server stack traces or secrets in tool responses.
6. Roll back both pointers and container if regressions appear. Preserve migrated data on rollback; do not roll back migrations automatically. Keep existing prayer, Goal and install sessions intact.

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

- The portable package is in `integrations/chatgpt-plugin`.
- Provide *reviewed, live* product website, support, privacy policy and terms URL. Policies must explain personal planning notes, spiritual data sensitivity, hosting, retention, sharing, and deletion.
- Verify the publisher business/individual identity and MCP domain on OpenAI Platform; confirm the organization role can submit plugins.
- Provide a reviewer OAuth account with no MFA, SMS or email OTP blockers and seeded **non-sensitive** sample plan. Never disclose real personal reflection content.
- Open https://platform.openai.com/apps-manage and submit the production remote MCP endpoint under **With MCP**, inspect tool scan and errors, add five positive and three negative test cases from `review-cases.md`.
- Record observed OAuth, security and privacy review outcomes. Submission and approval are separate from GitHub deployment.

## Not in the MVP

A Flutter-native rendering of the seven-day planner; cross-device synchronization with local-first Goals; paid entitlements; push reminders from ChatGPT; clinical counseling; generated prayers; spiritual scoring. Each needs its own reviewed tranche.
