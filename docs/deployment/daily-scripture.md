# Daily scripture

The public read endpoint is `GET /api/scriptures/daily?date=YYYY-MM-DD`. Dates are local calendar dates supplied by the app; optional `timezone` controls the default when no date is supplied. No account is required. There is no public write endpoint.

SoulBuddy owns its selections independently of Elbiblio. The implementation adapts Elbiblio's date selection and planned replacement pattern without copying its AI planner, social features, or account dependencies.

## Manual replacement

1. Download the `data` object for the intended date to a UTF-8 JSON file. Preserve the scripture reference, text, translation and passage bounds together when changing the passage. Edit the theme, reflection, prayer and practice as required. `precept` must be `guard-the-gate` or `strength-for-today`.
2. On the API host, run `php artisan scriptures:replace 2026-09-11 /absolute/path/scripture.json` in the active application container. The file must be accessible to the container. This validates all fields before updating the dated replacement.
3. Fetch the endpoint for that date and verify the published result. Adjacent dates are unaffected. Replace the same date again to revise it. Online clients refresh after reopening the app; disconnected clients keep their last cached dated selection until connected.

The command accepts a maximum 64 KB file, requires an exact calendar date, and stores only validated fields. Content review must verify that verse text matches its stated translation and reference; validation does not verify biblical wording.

## Rotation and offline content

The 28-day rotation is anchored to UTC calendar day numbers so the same requested date always selects the same passage on API and device. The app caches up to seven dated selections and prefers its bundled rotation to a cached scripture from a different day. No daily cron or AI request is required.

`tools/build_daily_scripture_catalog.py` builds both catalogs from the existing bundled RSVCE database. The selected passages and editorial practice prompts are defined in that script. It does not alter the source Bible database. Regenerate both catalogs together and run the API and Flutter daily scripture tests after an editorial change.

The reference source was inspected during development: the bundled Proverbs 4:23 row contains an incomplete verse, so the rotation uses the complete 1 Corinthians 10:13 passage instead.

## Practices

Guard the gate and Strength for today create ordinary goal actions. Today is the default; daily recurrence is optional. Saving the same body, schedule and goal on the same day is idempotent, including completed actions. Sacred Hours offers prayer-time practice and evening review; existing Sacred Hour reminder settings continue to govern alerts. No additional alert is silently enabled.
