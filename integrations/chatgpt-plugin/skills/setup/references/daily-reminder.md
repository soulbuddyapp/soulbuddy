# Daily reminder task

Use ChatGPT's scheduled-task capability only after the person agrees to a daily reminder and confirms a local time, IANA time zone, and whether commitment details may appear in notifications. If the capability is unavailable, explain that the reminder was not created.

When creating the task, identify the connected SoulBuddy Life Planner app and `get_daily_life_plan` explicitly. Use the person's confirmed time, time zone and privacy preference. Give the task a neutral title, such as `SoulBuddy reminder`, and include these instructions in the scheduled task:

> Each day, call SoulBuddy Life Planner's `get_daily_life_plan`. Do not write, create or modify a plan, check-in or review. If the tool reports `no_plan`, invite me to set up a seven-day plan. If it reports `upcoming`, tell me the plan's start date. If it reports `today`, remind me about my commitments for the returned date and time zone. If it reports `finished`, invite me to review the week or make a new plan. Do not infer completion or failure from a missing outcome. If authentication fails, tell me to reconnect SoulBuddy; if the service fails, say it is unavailable. Do not report either failure as an empty plan.

Add exactly one of the following privacy instructions based on the person's choice:

- **Generic:** `Keep the reminder generic. Do not include commitment titles, domains, outcomes, notes or reflections.`
- **Details approved:** `You may include the returned commitment titles and durations for today. Do not include check-in notes or reflections.`

Do not fill in a schedule or privacy choice the person has not made. A proposed task is not an active reminder: wait for ChatGPT to confirm creation and report the confirmed time and time zone. Do not promise push or email delivery unless the selected channel is available and delivery has been verified. If the plan and task time zones differ, explain that commitments are selected using the plan's local date.
