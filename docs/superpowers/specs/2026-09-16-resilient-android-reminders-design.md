# Resilient Android Reminders

## Goal

Deliver daily and weekly prayer reminders after the app process is no longer running, after a device reboot, and after an app update.

## Root cause

The prayer reminder coordinator sends `PrayerScheduledNotification` without a recurrence value. Its default is `once`, so Android receives a one-time alarm. The coordinator's in-app timer creates the next alarm only while the app process is alive.

## Decision

Use Android's repeating scheduled-notification facility for daily and weekly prayer reminders. The existing Flutter Local Notifications boot receiver restores scheduled alarms following reboot and package replacement. Do not introduce a permanent foreground service: it would consume battery, require a persistent notification, and still cannot bypass Android force-stop.

## Behaviour

- One-time reminders stay one-time.
- Daily reminders use Android `DateTimeComponents.time` recurrence.
- Weekday reminders use Android `DateTimeComponents.dayOfWeekAndTime` recurrence.
- Each recurring notification carries a stable reminder identifier. On an action, the app resolves the active occurrence for that reminder rather than requiring the original scheduled timestamp.
- When the app launches or resumes, coordinators reconcile saved reminders, time zone, notification permission, and exact-alarm availability.
- Sacred Hours retain their existing exact-alarm preference and boot recovery. Prayer, person, circle, and Altar reminders continue to use their own existing recurrence choices.

## Limits

Android allows a user to force-stop an app; after that, no app can receive alarms or boot broadcasts until the user opens it again. Battery-restricted OEM modes and disabled notification permissions can also prevent timely delivery. The app will expose and verify those requirements rather than claim an impossible guarantee.

## Validation

Unit tests prove that the coordinator passes daily and weekly recurrence to the scheduler and that notification response resolution accepts the current occurrence for a repeating alarm. Android tests and device checks validate that a notification remains scheduled after the Flutter process is swiped away and after reboot/package replacement.
