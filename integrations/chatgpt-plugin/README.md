# SoulBuddy Life Planner — ChatGPT plugin package

A portable ChatGPT/Codex plugin packaging the SoulBuddy Laravel MCP life-planning capability.

- `plugin.json`: portable Agent Plugins metadata.
- `mcp.json`: production Streamable HTTP URL and mixed public/OAuth auth declaration.
- `skills/setup/SKILL.md`: initial 7-day planning and opt-in reminder workflow, with task guidance under `skills/setup/references/`.
- `assets/icon.svg`: brand icon.

The server currently has no built-in authorization-code issuer. Account linking is deliberately **disabled by default** until an established OAuth provider has been configured in the production environment with proper PKCE and verified-email identity mapping.

## Scope
`get_planning_guide` and `get_connection_management` are public. The latter returns a provider account-management link only when it is configured and passes same-origin HTTPS checks; the link does not itself revoke access. All account-specific reads require `life.read` and writes require `life.write`. The MCP server stores only explicitly confirmed plans/check-ins/reviews, never generative prayers or a holiness score.

## Before submission
This is a development package, **not a published plugin**. Complete the release gates in [deployment guide](../../docs/deployment/chatgpt-life-planner.md). OpenAI submission requires real public support, privacy and terms pages matching actual data-handling practices; we deliberately omit unverified URLs and don't invent policies. A verified publisher identity and functioning OAuth review account are also required. Do not list before production checks pass.

Documentation: https://developers.openai.com/plugins/build/plugins
