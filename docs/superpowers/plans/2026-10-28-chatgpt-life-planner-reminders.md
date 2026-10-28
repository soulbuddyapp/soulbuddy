# SoulBuddy Daily Reminders Implementation Plan

> **For agentic workers:** Execute in this session with test-first changes and evidence from a real staging task.

**Goal:** Enable users to opt in to a daily ChatGPT task that reports the appropriate plan state and today's commitments.

**Architecture:** Add a protected, read-only daily-plan MCP tool that derives the plan-local date and returns minimal data. Extend plugin onboarding guidance to request explicit scheduling preferences and use ChatGPT's scheduler; validate the scheduler with a one-time staging run before making delivery claims.

**Tech Stack:** Laravel, Pest, ChatGPT plugin skills and scheduled tasks, isolated Keycloak staging.

### Task 1: Daily read behavior

**Files:** `services/api/app/Domain/LifePlanning/LifePlannerService.php`, `services/api/app/Http/Controllers/Chatgpt/McpController.php`, `services/api/tests/Feature/Chatgpt/LifePlannerMcpTest.php`.

- [ ] Add failing tests for `no_plan`, `upcoming`, `today`, `finished`, time-zone boundaries, owner isolation, `life.read` and exclusion of notes and other days.
- [ ] Implement the daily-plan service and declare the authenticated, read-only MCP tool.
- [ ] Run ChatGPT, auth, account and Goal regressions with `OPENSSL_CONF=C:\php\extras\ssl\openssl.cnf`.

### Task 2: Opt-in scheduling workflow

**Files:** `integrations/chatgpt-plugin/skills/setup/SKILL.md`, `integrations/chatgpt-plugin/review-cases.md`, `docs/deployment/chatgpt-life-planner.md`.

- [ ] Add scheduling instructions covering consent, time, time zone, setup, active plans, future plans, finished plans, authorization errors and platform availability.
- [ ] Add review scenarios for reminder setup and privacy. State that a proposed task is not active until confirmed by ChatGPT.
- [ ] Update the deployment runbook without claiming delivery is verified before an end-to-end test.

### Task 3: Staging verification

- [ ] Deploy the reviewed daily-read files only to the isolated staging API, retaining backups.
- [ ] Refresh the personal staging plugin's tool list and verify `get_daily_life_plan` against the synthetic reviewer.
- [ ] Schedule a disposable one-time ChatGPT task using the staging plugin; inspect the completed run and independently verify notification delivery if available.
- [ ] Record observed results and remaining blockers, update PR #20, and preserve the existing production environment.
