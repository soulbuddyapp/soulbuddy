# Daily scripture and practice — implementation record

1. Inspect Elbiblio's `VerseRepository`, `DailyVerseService`, and planned verse seeding. Adapt dated selection and manual replacement; keep SoulBuddy independent of Elbiblio authentication and AI generation.
2. Add API behavior tests before the endpoint. Implement the daily selection service, override migration, validated operator command and public read route. Build both 28-day catalogs from the same reviewed passage list.
3. Add Flutter repository tests for API precedence, wrong dates, offline fallback, corrupt cache and storage failures. Implement date validation, bounded dated caching and foreground/midnight refresh.
4. Add goal persistence tests before the practice service. Save editable commitments as existing goal actions. Add a separate scheduled-actions reader so evening review includes completed actions while Today continues to show only due actions.
5. Add reader audio lifecycle tests. Integrate the daily scripture card into Today and Meditation; add reading, reflection, personal prayer and practice actions. Keep sound after the reading and use the existing screen-awake and audio visibility controls.
6. Add practice and evening review entry points to Sacred Hours. Reuse the current reminder schedule instead of silently adding notifications.
7. Validate affected Flutter suites and the complete API suite. Update Today tests to explicitly scroll after introducing the new scripture card. Build the Android release only after Flutter tests finish to avoid generated-plugin registration races.
8. Deploy the API as an immutable release with the additive migration and rollback support. Verify the live scripture endpoint and existing public pages. Install the signed APK without clearing application data and inspect the new reader on the connected phone.

## Evidence

- API: 170 tests passed, 1,000 assertions.
- Flutter: 175 affected tests passed in the broad run; all 20 Today tests passed after fixture/scroll updates (195 affected tests total).
- Static analysis: no issues across app code and changed tests.
- Public API deployed to release `20260911-daily-scripture-v1`; previous release `928ca00` retained. Scripture, homepage and privacy endpoints return HTTP 200.
- No new dependencies, no database changes on the device, and no automatic alerts enabled.
- Android release build 1.0.0+3 succeeded. The phone's existing certificate was verified against the local Android development key; a separately re-signed device APK installed with `adb install -r`, preserving data. The store-signed APK remains separate.
- Device package inspection confirms version code 3. SoulBuddy launched with the new Daily scripture card. Further manual reader navigation was stopped when the phone switched to another app; reader/audio verification is automated.
