# Compact Spiritual Actions and Session Player

## Purpose

Make prayer and spiritual actions faster to scan and easier to continue. Goal prayer rows should use less space, completed Today items should remain visible as compact confirmations, reading sound selection should sit beside reflection, and every active audio-based spiritual session should use the same persistent playback controls.

## Goals screen

Prayer and reminder resources inside a Goal use a compact row between 56 and 64 logical pixels tall. Each row contains:

- a leading icon that identifies prayer, scripture, reminder, or action;
- a one-line title with ellipsis;
- an optional one-line due-time label;
- one direct primary action: **Pray**, **Open**, or **Done**;
- a trailing **More** menu for secondary actions available in that context.

Secondary actions include details, edit, reschedule, move, pause, archive, or remove when the underlying feature supports them. The entire text area remains tappable to open the resource. Buttons maintain a minimum 48 logical pixel touch target even when the visible row is shorter than the previous card.

Goal sections retain their title and Return action. Internal padding and dividers become compact so one prayer does not visually dominate the Goal.

## Today completion behavior

When a user completes a prayer, remembrance, or action item from Today, the expanded item animates into a 48 logical pixel completion row instead of disappearing immediately. The row contains a checkmark, a concise title, and the completion time. It supports horizontal swipe dismissal and an explicit close affordance for accessibility.

Completion rows remain until the user dismisses them, the local calendar day changes, or the Today screen is recreated after application termination. Completion remains saved in the repository before the compact confirmation appears. A failed save leaves the original item expanded and shows the existing error feedback.

The compact confirmation is presentation state. It does not add a second completion record or change the repository schema.

## Reading meditation sound picker

Sound selection moves from the beginning of the reading to the Reflection section after the reading content. The default state is a single compact picker row showing the selected sound and a preview icon. Opening it presents a bottom sheet grouped into:

- **Quiet ambience:** Stillness, Flowing Water, Gentle Rain, Ocean Waves, Forest Morning, Soft Wind, Warm Fireplace, and Night Crickets.
- **Motivational music:** Hopeful Piano, Cinematic Rise, Steady Resolve, Warm Strings, and Victorious Calm.

Each option supports an immediate preview, one selected state, and a clear **No background sound** option. Selecting an option closes the picker and applies it to the current meditation. The user can change the sound without losing reading or reflection progress.

Motivational tracks are instrumental and mixed beneath narration so speech remains clear. Track metadata declares its category, title, asset path, and preferred volume. Existing quiet ambience remains available.

## Persistent spiritual session player

A shared session controller owns the active playback session for:

- recorded memories;
- Altar memory playback;
- saved and scheduled prayer narration;
- person prayer sessions when narration or a soundscape is playing;
- Sacred Hour audio and its optional background track.

The root application shell displays one persistent mini-player above bottom navigation while a session is active. It remains visible across route changes until playback completes or the user explicitly completes or closes the session.

The mini-player is approximately 64 logical pixels high and includes:

- context icon and one-line title;
- elapsed/remaining progress;
- pause or resume;
- open session;
- complete or close, depending on the session type.

Tapping the player opens the full source screen. Completing a reminder records its existing completion action before closing the player. Closing ordinary memory playback stops audio without changing the memory.

Only one session plays at a time. Starting another session stops the current audio, replaces the player contents, and preserves any repository state already saved. Audio interruptions and route changes update the player state rather than creating another controller.

## Android reminder behavior

Scheduled alarms keep their current sound, vibration, lighting, exact timing, and full-screen behavior where supported. Opening an alarm starts the matching in-app session. When continuous narration or background audio is playing, the ongoing Android notification exposes Pause/Resume, Open, and Complete actions backed by the same session controller.

The short alarm alert remains an alert sound. Playback controls operate the continuous session that begins after the reminder is opened. Sessions without playable narration or background audio show Open and Complete controls without a disabled pause button.

## Accessibility and motion

All compact controls keep 48 logical pixel touch targets and descriptive semantics. Text respects system scaling and truncates only after preserving the primary action. Completion collapse uses a short fade-and-size animation and becomes immediate when reduced motion is requested. Player status changes are announced without repeatedly interrupting screen readers.

## State and failure handling

The shared controller exposes idle, loading, playing, paused, completed, and error states. UI surfaces observe that state and never create independent playback engines. Player errors retain the session title, show Retry, and allow Close. Missing audio falls back to an openable session without a playback control.

Today completion animations begin only after repository success. Sound preview failures leave the previous selection active. Notification actions that arrive before application initialization are queued and applied once the session controller is ready.

## Verification

Widget tests verify compact Goal row height and overflow actions, Today completion collapse and dismissal, the Reflection placement and picker behavior, and mini-player persistence across navigation. Controller tests verify single-session replacement, pause/resume, completion, error recovery, and queued notification actions.

Android release verification confirms the optimized APK retains every referenced sound resource and that exact Sacred Hour and person alarms remain registered. The final release is installed on the connected Android device for manual navigation and playback checks.
