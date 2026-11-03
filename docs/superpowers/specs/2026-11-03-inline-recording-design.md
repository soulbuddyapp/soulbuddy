# Inline recording design

## Goal

Make recording feel immediate and native throughout SoulBuddy. A Record action starts capture on the first tap and becomes an animated control in its original context, without opening a recording bottom sheet.

## Interaction

- The first tap requests microphone permission when needed, reserves audio playback, stops the voice and background sound, and starts recording only after the handoff succeeds.
- The originating control expands inline to show elapsed time and a live animation driven by actual microphone amplitude. Silence is visually distinct from speech; the animation must not imply microphone input when no samples arrive.
- Recording offers pause, resume, stop and discard. Stopping presents an inline review with optional playback and Save. Saving must work without preview. Discarding an unsaved take requires confirmation.
- After speech, twelve seconds of continuous low microphone input automatically pauses the take; resuming requires an explicit tap. Initial silence and gaps in microphone samples do not trigger the pause. Announce the pause to screen readers and provide haptic feedback when enabled in the person's settings. The silence threshold requires physical-device testing in quiet and noisy surroundings.
- Permission denial, recording failure, interrupted capture and failed save expose a concise recovery action in the same context. An unsuccessful microphone shutdown retains the playback reservation until cleanup succeeds.
- Navigation, application backgrounding and calls must not silently discard a take or restart playback during capture. Preserve existing interruption and cleanup guarantees.
- Controls remain usable with screen readers, large text and reduced motion. Announce state and elapsed time without announcing every amplitude sample; animation is decorative.

## Coverage and implementation boundaries

Apply the same interaction to every recording entry point, including personal prayers, After prayer and other voice-note fields, memories and reflections, formation, goals, guards, commitments, onboarding and existing recording surfaces. Adapt placement to each context rather than presenting a recording sheet. Existing non-recording sheets may remain when they are the surrounding task.

Reuse the existing capture controller, amplitude stream, playback ownership, audio storage and repositories. Extract a reusable inline capture component with explicit start, review, save, retry and disposal behavior. Connect each context to its existing save and ownership path; preserve its title, date, person, prayer purpose and contextual link. Avoid retargeting an in-flight save when a parent context changes. Existing text records remain readable and audio remains device-local.

## Verification and release

Exercise first-tap start, real amplitude updates, silence, pause/resume, stop, unpreviewed save, playback, discard confirmation, permission denial, retry, failed handoff, cleanup, navigation and context changes with focused automated tests. Verify each entry point is wired to inline capture and retains its existing persistence behavior. Check large text, screen-reader semantics and reduced motion.

On physical Android and iOS devices, test speakers and headphones, prayer plus Flowing water followed by an After prayer recording, interruption and background transitions, offline reopen and save without preview. Confirm the recorded take contains no leaked app playback. Complete the existing private PowerSync two-account staging checks and migration release order before publishing. A successful offline Android QA test alone does not establish sync or iOS behavior.
