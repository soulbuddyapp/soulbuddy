# SoulBuddy daily reminders

## Outcome

People may choose a daily ChatGPT reminder for their SoulBuddy life plan. Before a plan exists, the reminder prompts setup. During a seven-day plan, it refers to the plan's local date and includes only that day's commitments when the person has explicitly approved detailed reminders. Before a future start or after the seven days, it states the relevant condition rather than presenting old or future commitments as today's work.

## Delivery and consent

ChatGPT's scheduled-task service owns scheduling and notification delivery. The SoulBuddy plugin provides a read-only daily-plan tool and onboarding guidance. It does not create a schedule on connection, register a background job on the SoulBuddy server, send email, or claim a task was created until ChatGPT confirms it. Users choose whether to enable reminders, their local time and IANA time zone, and notification preferences. Reminders default to generic text because notifications can be visible to other people; commitment details are included only with explicit approval. Users can change, pause or remove the task using ChatGPT's task controls.

After an explicit reminder request, the assistant confirms the intended time, time zone and daily frequency, then asks ChatGPT to schedule a task using the connected SoulBuddy tool. A task must explicitly identify the plugin and the daily-plan tool, handle authentication failure without pretending the plan is empty, and make no writes or unsupported claims about delivery. If scheduling is unavailable, explain the limitation and do not represent a proposed schedule as active. A staging account and a disposable one-time task are used to verify an actual scheduled run and, separately, notification delivery before claiming availability.

## Data boundary

The authenticated `get_daily_life_plan` tool uses the same verified identity, `life.read` scope and per-call token introspection as other protected tools. It returns one of four states: `no_plan`, `upcoming`, `today`, or `finished`. For `today`, it returns the local date and only that day's commitment titles, domains, durations and recorded outcomes. It excludes reflections, check-in notes, other days and other users' data. For an upcoming plan it returns the start date; for a finished plan it returns the end date. User-facing strings remain short and contain no internal assistant instructions.

Plan date calculations use the stored plan time zone, with an inclusive seven-day interval starting at `starts_on`. A reminder's scheduling time zone may differ from the plan time zone; display the plan-local date and tell the user if they need to align the two. A scheduled task must not infer completion from missing check-ins.

## Verification and release

Tests cover user isolation, missing, upcoming, current and finished plans, local-date boundaries, minimal data disclosure and scope enforcement. A real one-time ChatGPT task must run against the staging account and show the expected result; a separate observation must establish whether push or email notifications reached the user's selected destination. Reconnection, provider-side revocation, production identity, registration, legal pages and production deployment remain release gates. This design does not claim that a ChatGPT task can bypass platform eligibility, session expiry or user notification settings.
