# Daily scripture and practice

## Outcome
One dated scripture on Today, with a full reading and reflection. Daily practice translates the user's precepts into prayer, a protective boundary, and one manageable act of love. Existing formation order, My Collection, Sacred Hours, reminders, and sound preferences remain the foundation.

## Decisions
- Adapt Elbiblio's dated selection and editorial override pattern within SoulBuddy's API. Do not require an Elbiblio account or depend on its live API.
- Serve a reviewed 28-day scripture rotation from a shared catalog, using the app's existing RSVCE text. An explicit dated replacement takes precedence. A protected operator command validates and replaces a date; no public write endpoint.
- The app requests its local calendar date, validates the payload, caches a small bounded set of dated selections, and uses the same bundled rotation offline. Previously cached days retain their date; never present yesterday's verse as today's. Refresh on foreground and date rollover.
- Today gets one compact Daily scripture card. Scripture opens a focused reader with reflection, prayer, and Daily practice. Existing orientation remains the primary formation journey.
- Guard the gate: a short precept, prayer, and suggested concrete boundary. Strength for today: grace, discipline, consistency, and a manageable act of service or duty. No escalating burdens or spiritual scores.
- Daily practice offers editable actions linked to an existing goal or a new named goal. Default is today, with an optional daily recurrence. Existing goal occurrences record completion. Sacred Hours offers the same practice sheet, with morning intention and evening review framing.
- Background sound stays in reflection, uses the existing remembered preference, and stops on navigation/background. Screen stays awake while reading.

## Verification
API: deterministic dates, distinct consecutive selections, invalid dates, manual replacements, replacement validation, no public mutation. App: network/cache/offline precedence, malformed and wrong-date responses, rotation consistency, goal action creation and recurrence, reader layout and sound lifecycle. Run affected suites and static analysis. Deployment/install status must be reported separately from local validation.
