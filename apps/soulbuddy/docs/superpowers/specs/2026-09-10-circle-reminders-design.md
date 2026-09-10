# Circle reminders

## Goal

Let a person choose a daily local time for each Circle and receive a private system notification that opens that Circle in SoulBuddy.

## Decision

One daily reminder belongs to each Circle on the current device. The setting stores the Circle identifier, display name, local time, IANA timezone, and a deterministic notification identifier in secure device storage. It does not change membership, Circle directory data, or the external conversation.

## Flow

The Circle detail view shows a reminder control. Choosing a time persists the device setting and requests notification permission when needed. The coordinator schedules a daily native notification. Its primary tap and its `Open Circle` action emit a Circle event; the app navigates to `/circles/:circleId`. Removing the setting cancels the native notification.

## Reliability

The coordinator loads saved settings at startup, observes later local changes, and reconciles native schedules serially. It schedules in the selected IANA timezone, so the chosen wall-clock time remains stable through timezone rules and daylight-saving transitions. The notification title uses the saved Circle name so it remains meaningful if the directory is temporarily unavailable.

## Validation

Unit tests cover secure-storage serialization, schedule creation, cancellation, and notification responses. Widget and app-navigation tests cover the time control and Circle route. Existing reminder tests protect shared scheduler behavior.
