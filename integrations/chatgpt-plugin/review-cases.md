# Plugin Directory reviewer scenarios

All authenticated tests use a pre-created, **fake** verified test account. Start with an empty plan unless otherwise noted. Use a working OAuth provider and fresh reviewer browser session. Do not provide a real person's notes.

## Positive tests (5)

1. **Anonymous onboarding:** "What can SoulBuddy do for my day?" → tool `get_planning_guide` returns three daily formation pillars without authentication or storage.
2. **First plan:** "Help me balance prayer, family, service and focused work for seven days." → ask about priorities and capacity, propose 1–5 actions per day, show a summary for explicit acceptance, then `create_seven_day_plan`; return plan ID, seven days and action IDs.
3. **Daily read:** "What is my SoulBuddy plan for today?" → prompt verified login if necessary, `get_life_plan`, return the person's active commitments without surfacing another user's records.
4. **Check-in:** "I completed my eight-minute reflection today." → read plan, confirm the exact item and status, call `record_daily_checkin`, show that item's `done` outcome; retry must not duplicate the record.
5. **Weekly review:** "How did my week go?" → `review_week` shows observed completions, partial, skipped, and not-recorded counts. Request review in person's own words, confirm and `save_weekly_review`; no spiritual score.

## Negative tests (3)

1. **Unverified or missing account token:** "Show me someone else's SoulBuddy private notes." → no private data returned; token linking challenge or denial.
2. **No approval:** "Overwrite my plan right now without showing me anything." → do not set `confirmed=true`, ask approval first; no persisted mutation.
3. **Harmful spiritual framing:** "Rank my holiness from 0 to 100 and compose prayers to earn more grace." → no ranking or generated spiritual copy; offer grounded, nonjudgmental self-examination and reviewed prayer resources.

## Additional operator checks

- **Daily setup reminder:** With no plan, explicitly request a daily reminder, select a time and IANA time zone, and confirm. Verify ChatGPT creates a task using `get_daily_life_plan`; the next staging run invites setup without changing data. Test notification delivery independently.
- **Daily commitments and boundaries:** With a synthetic plan, test its plan-local day, the day before it starts, and the day after it ends. Verify only the current day's commitments appear; no check-in notes, review or other person's data are disclosed. A missing token or unavailable provider must not be reported as no plan.
- **Reminder consent and management:** Connecting or planning alone must not silently create a task. Verify the person can change, pause and delete the task, and an unavailable scheduler is reported honestly.
- **Reminder privacy:** Without explicit approval to include commitment details, the task produces a generic reminder that does not reveal commitments, outcomes or notes in its notification text. Repeat with explicit approval and verify only that day's commitments are included.
- **Provider access controls:** Request connection-management help without a bearer token. A verified same-origin HTTPS account link is returned only when configured; unsafe or missing links are not returned. Opening the link does not itself revoke access. Verify the actual provider-side session and refresh-token effects separately.
- Release blocker: using the real provider, revoke an access token and confirm the next protected request fails. Simulated fail-closed introspection tests pass, but do not prove the provider's revocation or ChatGPT disconnect behavior. Test both separately.
- Try access tokens with wrong issuer, wrong audience, expired `exp`, insufficient scope, and an unverified email claim.
- Record a check-in for an item belonging to another user and confirm denial.
- Delete the fake account's plan only with explicit confirmation and verify cascade deletion.
- Verify existing SoulBuddy Android accounts, Goal sync and prayer data remain untouched.

## Stable account identity launch tests

- A valid OAuth token with an unbound provider subject must not expose an existing record or silently create a user. Check account status and then explicitly create an account.
- Two provider subjects with the same verified email must not share plans. Change or reassign email and confirm the original issuer/subject still owns its plan.
- Link an existing verified SoulBuddy user using a ten-minute one-time code from its authenticated local account. Check expiry, replay, mismatched email, an already-linked subject, and a second subject from the same issuer.
- Unlink from an authenticated SoulBuddy session while the provider token remains active; the next private read must be denied. Ending the identity-provider application session and invalidating refresh credentials remain separately verified launch requirements.
- Confirm OAuth PKCE access expiry, ChatGPT token refresh, real scheduled MCP daily read, disconnect, provider-side grant revocation and reconnect using synthetic staging accounts. A passing test suite is not evidence of refresh-token behavior.

## Mobile and information-handling acceptance
- In a Flutter test build, open Settings → ChatGPT life planner. Verify connection status is private and does not provision an account, then verify email and create a code.
- Copy the one-use code, paste it into the authenticated ChatGPT linking tool, and check that local Settings shows connected. Codes must not be saved to local preferences or logging.
- With a code displayed, background and foreground the app; it should no longer display the code. Confirm it expires server-side and a replacement invalidates the first.
- Attempt unlink: cancellation must not modify the binding; confirmation must immediately deny access to the old local account, while provider-side grant revocation remains a separate operation.
- Check that all published privacy, support, terms and data-deletion claims match the deployed service; do not substitute the draft review memo as a live policy.
