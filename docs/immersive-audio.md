# Immersive audio

## Experience

New long-form contributions are voice recordings. Text inputs are limited to
names, short titles, search, email, and invitation codes. Opening the recorder
does not start the microphone: the person explicitly starts, pauses, reviews,
and saves the take. Titles are optional where a context or date can supply one.

| Place | Recording behavior |
| --- | --- |
| Record and Remember | A voice take opens first; short metadata follows. Existing written memories remain readable. |
| Personal prayers | Save a prayer recording directly, without dictation, transcription, or a required body field. |
| Prayer detail | Listen with a background sound; record a private reflection under “After prayer.” |
| Formation videos | “After watching” records a reflection linked to the selected video and day. The user explicitly completes the activity. |
| Goals, meditation, and guards | Record situations, reasons, reflections, and private explanations; keep action names short. |
| Commitment journey | Record needs, calling, declaration, and practice reflections; keep names and practice labels short. |

Prayers and memories share the background sound picker: Quiet, Stillness, and
Flowing water. Background volume is independent of the original voice and is
saved per recording. The original audio file is never mixed down or overwritten.

One foreground voice owns playback. Replacing a session closes the previous
owner before starting the next. Navigating within SoulBuddy preserves the active
session through the mini-player. Pause, completion, and close stop both layers.
Microphone capture reserves the session, pauses voice and ambience, and prevents
queued play/resume commands from restarting them. Ending capture does not resume
playback automatically. Native recording failures keep that reservation until
microphone cleanup succeeds.

Existing foreground/background lifecycle behavior remains in force. This change
does not add a lock-screen media service or promise uninterrupted screen-locked
playback. External video launch cannot establish that a person watched a video;
completion remains an explicit action.

## Persistence and recovery

Private audio bytes and local playback metadata remain on the recording device.
The feature adds no transcription, AI prayer generation, or audio upload queue.
Other devices show an unavailable-recording state when only synced metadata is
present.

`voice_note_links` is an owner-scoped, local-only table joining existing audio
memories to a context type, context ID, and field. Attaching verifies ownership,
active memory status, and local audio metadata, and deduplicates retries. Goal
and commitment finalization moves draft links to the finalized identity in the
same local transaction. A failed context attachment retains the already-saved
memory for a link retry. Captured media is not duplicated just to add a link.

Recorded prayers use `personal_prayer_revisions.content_format = 'audio'` and an
empty body, with a voice tablet referring to that exact revision. The durable
audio copy and local metadata save as one visible action. If metadata fails, the
copy is cleaned up while the original take remains available for retry. Failure
to delete a temporary take after a successful save does not turn that save into
an apparent failure or invite a duplicate.

Audio memory reflections use `memory_reflections.audio_encounter_id`. Sync
validation requires an owned target and rejects invalid mixed batches atomically.
Immutable references may point to an archived owned encounter, so offline
recording followed by archival still syncs. New client attachments require an
active recording. Narration requests cannot synthesize an audio-only prayer from
its title or empty body. Existing text revisions default to `text` and remain
readable; no historical content is overwritten to manufacture an audio format.

## Release order

1. Apply `2026_11_03_000000_add_audio_authoring_metadata.php` and deploy the sync
   and narration handlers before releasing clients that submit the new metadata.
2. Update the existing private PowerSync projections to include
   `personal_prayer_revisions.content_format` and
   `memory_reflections.audio_encounter_id`. Preserve their existing owner filters.
   The repository contains only a commitment rules fragment, so the deployed
   private bucket configuration must be updated and verified in its actual
   configuration source. Do not create a new public bucket for these columns.
3. Verify a new recorded prayer and a linked reflection upload and download
   their metadata to the same account, without exposing it to another account.
   Verify older text rows continue to load. Audio bytes remain local.
4. Release the client after the automated checks and device checks below pass.

The migration refuses a destructive rollback while audio-authored data exists.
Rolling back the client does not require deleting the additive columns.

## Verification

The Immersive audio workflow uses Flutter 3.35.7 on Windows for the repository's
PowerSync test library, plus PHP 8.4 for sync and narration. It covers recorder
lifecycle, layered playback races, navigation, save retry, local persistence,
context ownership, audio prayer creation, linked reflections, sync rollback, and
the narration boundary. Existing Onboarding and Goals tests cover the adapted
journeys and finalizers. Workflow results, rather than this document, are the
source of truth for the exact checked commit and pass/fail status.

Before production release, check real iOS and Android devices with speakers and
headphones: mix a prayer with each sound; change volume; navigate and pause;
record after playback; deny microphone permission and retry; interrupt with a
call or background transition; stop/review/save; reopen an offline recording;
and cancel or retry a failed save. Confirm no speaker audio leaks into a newly
started take and no stale ambience restarts after capture begins. Review the
flows at large text sizes with screen-reader labels enabled.
