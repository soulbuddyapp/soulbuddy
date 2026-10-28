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
- Release blocker: using the real provider, revoke an access token and confirm the next protected request fails. Simulated fail-closed introspection tests pass, but do not prove the provider's revocation or ChatGPT disconnect behavior. Test both separately.
- Try access tokens with wrong issuer, wrong audience, expired `exp`, insufficient scope, and an unverified email claim.
- Record a check-in for an item belonging to another user and confirm denial.
- Delete the fake account's plan only with explicit confirmation and verify cascade deletion.
- Verify existing SoulBuddy Android accounts, Goal sync and prayer data remain untouched.
