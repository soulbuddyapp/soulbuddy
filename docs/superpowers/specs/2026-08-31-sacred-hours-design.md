# SoulBuddy Sacred Hours Design

**Status:** Approved direction; written specification awaiting final user review

**Date:** 2026-08-31

**Platforms:** Flutter Android, iOS, and web; PowerSync local-first storage; Laravel authoritative sync API

**Extends:** `2026-08-26-prayer-refrains-voice-tablets-design.md`, `2026-08-26-first-use-ritual-design.md`, and `2026-08-30-remember-persons-design.md`

## Purpose

A **Sacred Hour** is a daily period deliberately set apart with God. It begins with prayer, then carries the person's ordinary work, responsibilities, and attention into God's presence. SoulBuddy helps the person ask why God may have placed them in their present work or position, notice what He may be teaching them, and consider how to serve Him more faithfully there.

The app is a reminder and guide. It does not declare that an impression is God's voice, make the hour holy on the person's behalf, or treat completing an hour as spiritual achievement.

## Considered approaches

### Dedicated Sacred Hours built on the existing reminder engine — selected

Sacred Hours receive their own domain, repository, settings surface, onboarding step, and focused session. They reuse the existing timezone, notification response, reboot rescheduling, prayer, person, audio, and local-first infrastructure. This preserves their wider meaning without building a second notification stack.

### Store Sacred Hours as prayer reminders — rejected

A Sacred Hour may include prayer, a person, ordinary work, reflection, and remembrance. Making it a prayer reminder would force unrelated concerns into `prayer_reminders`, make settings confusing, and lose the distinction between a five-minute prayer and the hour that carries prayer into work.

### Full alarm-clock subsystem — rejected

SoulBuddy will not impersonate a phone alarm application, automatically cover other apps, bypass silent or Focus modes, or promise to launch itself without a user action. Android exact-alarm access may improve timing after explicit opt-in, but full-screen intents are restricted to qualifying alarm/calling use cases. iOS local notifications remain under system control.

## Onboarding

After the three short welcome scenes and before Goal onboarding, show one non-scrolling Sacred Hours setup page.

### Teaching copy

**Set apart an hour**

> Pray first. Then bring the work already before you into God's presence. Consider why He has placed you there and how you can serve Him in it.

Keep the explanation visible but compact. Do not add a carousel, theological lesson, long questionnaire, or permission prompt before the person sees the value.

### Default hours

Create two idempotent defaults:

- **Morning** — 6:00–7:00am — pray for 15 minutes;
- **Evening** — 10:00–11:00pm — pray for 15 minutes.

Both cards are enabled by default. Each exposes a direct **Change** action for the start time and a compact 5, 15, or 30 minute prayer-duration choice. The Sacred Hour remains 60 minutes in this slice; the prayer duration determines only its opening period.

Primary action: **Keep these hours**

Secondary action: **Change times**

The user may continue without granting notifications. The hours are still saved and appear in SoulBuddy; their cards state that device reminders are off. Request notification permission only after **Keep these hours**, with a short in-context explanation. Onboarding completion must not depend on permission approval.

Linking a prayer or person is introduced later in Settings or the Sacred Hour detail screen, not during onboarding.

## Sacred Hours settings

Place a **Sacred Hours** section before **Sound & touch** on the existing Settings screen. It shows the next enabled hour and a compact list of all hours.

Each hour supports:

- name;
- local start time and derived end time one hour later;
- prayer duration: 5, 15, or 30 minutes;
- enabled/paused state;
- one optional saved prayer;
- one optional saved Person;
- reminder sound;
- ordinary reminder or optional Android precise-alarm mode for this device;
- edit and archive.

Users may add more Sacred Hours. New hours do not receive spiritual labels automatically; the default name is based on the selected time and remains editable. Overlapping hours are allowed but the editor warns before saving and offers to change the time. Saving an overlap requires an explicit second confirmation.

## Reminder sound palette

Ship a small offline palette of original SoulBuddy sounds. Every choice has a Play/Stop preview, a plain description, and the same moderate preview loudness. No sound is described as sacred, healing, frequency-based, spiritually powerful, or capable of improving prayer.

1. **Gentle Chime** — warm three-note chime; default for both initial hours.
2. **Dawn Chime** — light, slowly rising three-note cue suitable for morning.
3. **Still Bell** — one restrained resonant bell for minimal interruption.
4. **Evening Chime** — two lower, softer notes with a longer decay.
5. **Device sound** — use the platform's ordinary notification sound.
6. **Silent** — visual notification and optional vibration only.

The four SoulBuddy tones are generated from deterministic synthesis recipes committed with the project and dedicated under CC0-1.0, following the existing feedback-tone asset process. Do not reuse Elbiblio sound files whose provenance manifest still contains unresolved source placeholders.

The generator may render additional premium candidates during implementation. Ship an additional tone only when phone-speaker and headphone review finds that it is clearly beautiful, calm, audible, and functionally distinct from the core four. Keep the visible palette to at most eight choices, including Device sound and Silent, so sound selection remains simple.

Sound selection is separate from alert precision. A louder or repeating wake behavior is never implied by selecting a tone. Android notification channels are versioned by stable sound key because channel sound becomes system-controlled after creation. iOS custom sounds are bundled in a supported local notification format. Web uses the selected sound only while SoulBuddy is open and otherwise provides an ordinary browser notification.

## Reminder behavior

### Ordinary reminder

The default is a daily actionable local notification at the Sacred Hour start time. It uses the selected sound, privacy-safe copy, and these actions where the platform permits:

- **Begin** — open the Sacred Hour session;
- **In 10 minutes** — schedule one local snooze;
- **Not now** — dismiss this occurrence without judgement or penalty.

Default notification copy:

**Your Sacred Hour**

`Begin with prayer. Bring this hour before God.`

When a Person is attached, private names remain hidden on the lock screen unless the user separately enables detailed notification text. Prayer bodies and memory content never appear in the notification.

### Android precise alarm opt-in

Settings may offer **More precise timing** for a particular Sacred Hour on Android. Selecting it first explains that Android will open the system's **Alarms & reminders** access page and that SoulBuddy still cannot override device volume, Do Not Disturb, or manufacturer restrictions.

If exact-alarm access is granted, schedule with the plugin's exact-while-idle mode and reschedule after permission changes, reboot, app replacement, timezone changes, or hour edits. If permission is absent or later revoked, fall back to the ordinary inexact reminder and show the current status in Settings. Do not declare `USE_EXACT_ALARM`; use the revocable `SCHEDULE_EXACT_ALARM` path because SoulBuddy is not a dedicated alarm-clock app.

Do not request or use full-screen intent permission. A notification tap opens SoulBuddy. The existing boot receiver may start the app process only to restore schedules; SoulBuddy does not show UI at boot and does not add a general auto-start service.

### iOS and web

iOS schedules a repeating local notification with the selected bundled sound. The operating system decides delivery under notification, Focus, silent-mode, and device settings. The person taps the notification to open the session.

Web keeps Sacred Hours and in-app due state fully functional. Browser notifications are best-effort and do not promise background custom audio, reboot persistence, or automatic launch.

## Sacred Hour session

Opening a due or upcoming hour presents one calm, focused screen rather than a dashboard.

### Phase 1: Begin with prayer

Show the selected prayer-duration timer and, when attached, the saved prayer and Person. Available actions are:

- **Pray now**;
- **Choose a prayer**;
- **Pray for someone**;
- **Quiet prayer**.

The user may finish prayer before or after the suggested duration. A timer reaching zero does not mark prayer complete. Only an explicit **I prayed** action records the existing factual prayer or person occurrence.

### Phase 2: Carry the hour with God

After prayer, show one selectable prompt at a time:

- **Why might God have placed me in this work?**
- **Who can I serve through it today?**
- **What needs patience, courage, honesty, or care?**
- **What may God be teaching me here?**

The screen states: `Continue with the work already before you.` SoulBuddy does not require the person to keep the app open for the remaining hour. A quiet persistent in-app state may show the end time when they return.

The person may tap **Remember what I understood** to open the existing Remember flow with Sacred Hour context. Speak and Write are both available. SoulBuddy labels the record as the person's understanding, not as a verified message from God.

## Today integration

Today shows at most one Sacred Hour card: the currently active hour or the next upcoming enabled hour. It never shows both defaults plus every custom hour at once.

Before the hour: show its start time and **Prepare**.

During the hour: show **Begin** or **Continue**.

After the hour: hide it unless the person explicitly kept a memory or left an unfinished prayer session. Do not show missed-hour language, streaks, completion percentages, or guilt-oriented recovery copy.

## Data model

Add synchronized owner-scoped metadata:

- `sacred_hours`: ID, owner, name, local start time, timezone, fixed 60-minute duration, prayer duration, enabled state, sound key, optional prayer reference type/ID, optional Person ID, created/updated/archive timestamps.
- `sacred_hour_occurrences`: deterministic occurrence key, Sacred Hour ID, owner, due instant, local date, begun/completed/dismissed state, linked prayer/person occurrence when explicitly confirmed, created/updated timestamps.
- `sacred_hour_devices`: Sacred Hour ID, installation ID, platform notification ID, ordinary/precise mode, next scheduled instant, scheduled timezone, permission/capability status, snooze state, updated timestamp.

Seed the two defaults once per owner with stable purpose keys (`morning`, `evening`) so retry, reinstall sync, and concurrent devices cannot create duplicates. User-renamed defaults keep their purpose keys.

Sound files are bundled assets, not database blobs. The sound key syncs; precise-alarm preference and platform permission state remain device-specific.

Laravel validates ownership of attached prayers and Persons, time and duration ranges, supported sound keys, deterministic occurrence identity, and device-scoped mutations. Sync rules expose only the authenticated owner's Sacred Hour records.

## Architecture

- `SacredHour` and `SacredHourOccurrence` own domain validation and plain-language time presentation.
- `SacredHourRepository` owns local-first CRUD, default seeding, links, and occurrences.
- `SacredHourReminderCoordinator` projects enabled hours into the existing `PrayerReminderScheduler`, adding a `sacredHour` notification kind rather than a parallel plugin wrapper.
- `SacredHourPermissionService` isolates Android exact-alarm capability checks and settings navigation; unsupported platforms return a truthful unavailable state.
- `SacredHourSessionController` owns the two phases without keeping a background timer service alive.
- onboarding, Settings, Today, Prayer, Persons, and Remember consume providers over these interfaces rather than issuing SQL directly.

## Error handling

- Notification denial saves the hours and states `Device reminders are off`.
- Exact-alarm denial or revocation falls back to an ordinary reminder without dropping the Sacred Hour.
- Missing/corrupt custom sound falls back to the device sound.
- Timezone changes preserve the selected local wall time and reschedule future occurrences.
- Daylight-saving gaps use the next valid local instant; repeated wall times create one deterministic occurrence.
- An unavailable linked prayer or archived Person leaves the Sacred Hour intact and offers **Choose another**.
- A save failure retains edits and presents Retry.
- A reminder response is idempotent and cannot create duplicate prayer, person, or Sacred Hour occurrences.

## Accessibility and restraint

- Setup remains usable without scrolling on the supported compact onboarding viewport at standard text size.
- At 200% text, content may scroll and retains logical focus order.
- Time, sound, reminder mode, prayer duration, and attached items have explicit screen-reader labels.
- Sound previews expose Stop and never autoplay.
- Color and motion are supplemental; reduced-motion settings are respected.
- Alarm, permission, and reminder language states capability without pressure.

## Verification and acceptance

1. A fresh owner receives exactly two enabled Sacred Hours at 6:00am and 10:00pm, even across retries and sync replay.
2. Onboarding teaches the practice, permits time and 5/15/30-minute prayer choices, and remains usable when notification permission is denied.
3. Settings can add, edit, pause, archive, preview sounds, and attach one prayer and/or Person while offline.
4. The four original chimes and Device sound/Silent fallbacks work on supported platforms without unresolved third-party licensing.
5. An ordinary reminder survives reboot and opens the correct Sacred Hour.
6. Android precise mode requests special access in context, uses exact scheduling only when granted, and degrades safely when revoked.
7. SoulBuddy never uses full-screen intents, launches UI at boot, or claims it can bypass system sound/Focus controls.
8. The session supports prayer, a linked Person, work-oriented prompts, and voice or written remembrance without requiring the app to stay open for an hour.
9. Today shows only the active or next Sacred Hour and uses no missed-day, streak, score, or shame language.
10. Flutter domain, repository, coordinator, widget, accessibility, and Android device tests pass; Laravel migration, policy, validation, sync, and API tests pass.

## Platform references

- Android exact alarms: <https://developer.android.com/develop/background-work/services/alarms>
- Android 14 exact-alarm changes: <https://developer.android.com/about/versions/14/changes/schedule-exact-alarms>
- Android 14 full-screen intent restrictions: <https://developer.android.com/about/versions/14/behavior-changes-14>
- Flutter local notifications setup: <https://pub.dev/packages/flutter_local_notifications>
- Apple local notifications: <https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app>
- Apple custom notification sounds: <https://developer.apple.com/documentation/usernotifications/unnotificationsound>
