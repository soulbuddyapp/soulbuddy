# Prayer and reminder audio design

## Outcome

Provide voiced built-in prayers, supportive audio for reminder types and optional personal recordings for people. The existing prayer-library and editorial manifests contain nine overlapping bundled prayers; inventory other built-in sources before claiming total coverage. Never synthesize private user content remotely without the existing explicit consent.

## Built-in prayer audio

Generate bundled offline narration from the exact approved prayer body for each stable built-in prayer ID. Store a manifest linking IDs and content hashes to audio; validate missing, duplicate, outdated, corrupt or empty recordings. Playback must offer pause/stop and recover from missing audio. Existing personal recordings remain an option. When a prayer's words change, stale narration must not be played as if it matched.

## Reminder delivery

Reminder kinds include prayer, altar, person, sacred hour, circle, daily formation, goal meditation and commitment. Provide short generic supportive audio, respecting each person's sound choice, silent mode and operating system controls. Notifications must not expose prayer text, names or recordings. Built-in daily reminders use OS notification sounds with a per-prayer audio switch, respecting notification permissions and device sound settings. Android packages all nine full recordings as notification sounds; the eight recordings under 30 seconds are packaged for iOS, while the longer ninth uses the short cue. Opening the reminder can start the full prayer using a silence-respecting audio session. OS delivery and full-duration playback require device verification; inexact timing may apply. In-app playback exposes a stop control; avoid recording a prayer session merely because audio played. Do not silently claim background autoplay on a platform where it is unavailable.

## Personal prayer for a person

Allow an optional voice recording while adding or editing a person. Store the recording and its association locally on the device, retain it across edits and support playback, replacement and deletion. When the person opens a reminder, start an existing recording only when the audio environment permits it. A person reminder remains valid without a recording. Do not put private audio or names in notification payloads, export or upload without an explicit choice. Handle denied microphone permission, interrupted capture, save failure and cancellation without losing an existing recording.

## Testing and rollout

Test asset-to-text coverage, stable IDs, stale hashes, player error and stop; notification routing, audio preferences and privacy across all kinds; recording lifecycle and failure recovery; and real Android/iOS reminder behavior including lock screen, process death, permission denial and interruption. Preserve existing reminders and unrelated work. Ship only verified behavior and report platform-specific limits explicitly.
