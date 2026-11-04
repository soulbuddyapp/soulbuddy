# Say it: one voice affordance where someone speaks

Date: 2026-10-06
Status: awaiting review

## Problem

Voice capture exists in four places and is absent from fourteen. `record`
powers `AudioCapturePanel`, used by the Record tab, the Encounter form, the
onboarding first prayer, and the voice tablet sheet. `speech_to_text` is used
by the onboarding first-prayer page and the commitment journey screen, in two
different shapes: a full-page Speak/Write fork in one, an inline field in the
other.

Everywhere else, capturing a reflection, a commitment, or a prayer in one's own
words is typing only. Someone who thinks in speech has to transcribe. The
inconsistency is the defect: the same capability appears in unrelated shapes at
unrelated moments, so it cannot be learned.

## Decisions

Three decisions shape this design. Each was taken deliberately.

### The rule: voice where a sentence is expected

The affordance appears only where the person is expected to say something in
their own words. It does not appear where someone is filling a slot.

This is the whole basis of consistency. A rule stated in one sentence can be
applied uniformly and audited; "all free-text fields" cannot, because it
includes slots a person would rather choose than recite.

### Audio stays with Memory; speech resolves to text

Recording produces audio and needs a store. Audio assets exist today only for
Memory/Encounters (`memory_audio_assets`) and Voice Tablets
(`voice_tablet_audio_assets`), both `Table.localOnly`.
`docs/architecture/local-first.md:37` states that user-recorded memory audio
remains device-local.

Dictation produces text, which the surface's existing persistence and sync
already handle. So dictation extends to every in-scope surface at no storage
cost, and dictated text **syncs** where recorded audio cannot.

Keeping the sound of a voice remains available where an audio store exists:
Memory and Encounters. Extending audio to arbitrary fields would require a new
asset store with its own playback, deletion, and orphan-cleanup lifecycle, and
would rewrite the architecture document's audio clause. Not taken here.

### On-device recognition only, never network fallback

`speech_to_text` is called with `onDevice: true` and must stay so. On Android,
when no on-device recogniser exists, the platform can fall back to network
recognition, which would send spoken words off the phone.

For a prayer app this is a different order of thing from keeping typed text
local. The existing posture is that anything leaving the device requires
explicit disclosure and consent (`local-first.md`, Prayer narration). Letting
dictation fall back silently would cut against that.

Unavailable, denied, and on-device-unsatisfiable therefore collapse to one
outcome: the field stays fully usable and shows the notice already in use,
`Speak is unavailable. You can write instead.`

The app does not attempt to suppress or detect the keyboard's own dictation
button. That belongs to the input method, not to SoulBuddy.

## Architecture

### `SpeechCaptureService`

A single wrapper over `SpeechToText` owning `initialize()`, the availability
result, and the listen options. It is the only place that knows
`onDevice: true`, the listen timings, and the degradation notice.

The two existing call sites duplicate this logic; they are replaced rather than
extended. It is also the one place the microphone-permission flow can be
corrected, which is currently unverified — see Risks.

### `SayableField`

A `TextField` with a mic affordance in the `suffixIcon`. Tapping it starts
dictation; words appear in the field as they are recognised. The field's own
persistence and sync then do their normal work.

States: idle, initialising, listening, unavailable. While listening the field is
tinted and the icon becomes stop, so the state is visible on the field being
dictated into rather than in a banner elsewhere.

Emphasis is a render option, not a different component. `prominent` is used on
the first say-something surface a person meets, during onboarding. Every other
surface renders compact. The mechanism is identical everywhere; only visual
weight changes, and it changes once.

Rationale for a single prominent moment: repeated high-salience prompts
habituate and come to feel like nagging. One emphatic moment followed by uniform
restraint is what keeps the affordance feeling offered rather than imposed.

## Text reconciliation

`SpeechRecognitionResult.recognizedWords` is the whole recognition session, not
a delta. With `partialResults: true` it grows across callbacks.

Neither existing call site handles this correctly, in opposite ways.

`first_prayer_speech_page.dart` assigns the whole string to the controller
(`_words.text = result.recognizedWords`). That is safe only because its field
is always empty. Applied to a field someone has already typed into, it
**destroys their text**.

`commitment_journey_screen.dart` captures a `before` prefix and joins it with
the recognised words. That is closer, but it still discards any text after the
caret, joins with an unconditional space so mid-sentence dictation gains a stray
space, and truncates to a character limit by rune, which can cut a dictated
word in half.

`SayableField` therefore captures, when dictation starts:

- `prefix` — the text before the caret
- `suffix` — the text after the caret

and on every callback, including partials, sets the field to
`prefix + recognizedWords + suffix`, with no inserted separator, because the
recogniser's own words carry their spacing.

This makes dictation correct in a pre-filled field, correct mid-sentence, and
correct across partial updates, with no duplication, no loss, and no invented
spaces. One dictation session may start again from the caret as many times as
the person wants.

Where a surface enforces a field length, `SayableField` accepts a maximum and
truncates on a rune boundary. A limit must never be reached by discarding a
partial result silently: when the recognised text cannot fit, the field keeps
what fits and the notice explains that the limit was reached, so a person is
never left believing a sentence was saved in full when it was not.

## Copy

Action labels reuse the strings already in the app: **Speak** and **Stop
dictation**, with the `Icons.mic_none` / `Icons.stop` pair from
`commitment_journey_screen.dart`. Introducing new wording for the same action
would be a small, needless inconsistency.

The unavailable notice is the existing string verbatim:
`Speak is unavailable. You can write instead.`

No affordance explains the interface, narrates what has been saved, or invites
the person back to a screen. The mic is present and labelled; it does not
announce itself.

## Surfaces

In scope, being where a sentence is expected:

| Surface | Field(s) |
|---|---|
| `daily_formation_card` | Reflection; trigger/escape action |
| `prayer_create_screen` | own-words prayer; title |
| `first_prayer_detail_page` | name/need |
| `first_goal_screen` | goal; door to close; own-words prayer |
| `goal_detail_screen` | What is happening now; Why this matters |
| `goal_meditation_screen` | Notebook |
| `daily_practice_sheet` | My commitment |
| `daily_remembrance_screen` | What do you understand now |
| `memory_detail_screen` | Add what you understand now |
| `first_remembrance_page` | What you want to remember |
| `encounter_form` | title; body — gains dictation beside existing recording |
| `commitment_journey_screen` | reflection — normalised onto `SayableField` |
| `guard_configuration_sheet` | private note |
| `today_prayer_goal_migration_card` | what are you seeking help with |
| `create_circle_sheet` | Purpose |

Out of scope, being slots rather than sentences:

- Search: `circles_screen`, `remember_screen`
- Email: `account_email_link_section`
- Scripture references: `scripture_picker_sheet`
- Numeric and configuration: day, minutes, voice speed, category, visibility
- Short labels: person name, person relationship, Sacred Hour name, circle name
- Goal title where it labels a list row: `create_meditation_goal`,
  `goal_detail_screen`, `daily_practice_sheet`

Two calls worth recording, because both cut against a naive label match:

- **Circle Purpose is in, circle name is out.** Purpose prompts a sentence;
  name does not. The pair stays coherent under one rule.
- **Goal title is in on `first_goal_screen` and out elsewhere.** The field is
  named the same in both places but means different things: on onboarding the
  hint is "A few words are enough" and it is the person's own articulation; in
  the Goals list it labels a row. The rule tracks intent at that moment, not
  the string.

## The onboarding fork

`first_prayer_speech_page.dart` is a full-page Speak/Write fork. It becomes a
`SayableField` rendered `prominent`, which is the first say-something surface a
person meets.

Keeping the fork was considered and rejected. Two ways to speak is two mental
models, and the cost lands later, on the person relearning that the mechanism
moved. A single elaborate prompt does not carry forward; a field-level
affordance, present everywhere, does.

Discoverability is preserved by emphasis rather than by a separate screen. The
emphasis is spent once, here, and never repeated.

## Error handling

- **Unavailable, denied, or no on-device recogniser** — the field remains fully
  editable; the notice reads `Speak is unavailable. You can write instead.`
  The mic affordance is not shown when availability is known to be false.
- **Permission not yet requested** — requested on first use, not eagerly at
  startup, so the prompt arrives when the purpose is visible.
- **Recognition error mid-session** — the field keeps whatever was recognised.
  Partial text is not discarded.
- **Dictation never blocks typing.** Every in-scope field is a normal editable
  field with an addition, never a mode.

## Testing

- `SpeechCaptureService`: unavailable, denied, and listening transitions; asserts
  `onDevice: true` is requested and that no network recogniser is ever selected.
- `SayableField`: recognised words land in the controller; stop while listening;
  stays editable when unavailable; `prefix + words + suffix` reconciliation,
  including a pre-filled field and a caret in the middle; partial results do not
  duplicate.
- `encounter_form`: dictation and recording coexist without either disabling the
  other.
- A guard test that no in-scope surface declares a bare `TextField` for a
  say-something field. This is the test that stops consistency eroding as
  screens are edited later.

## Risks

- **Microphone permission at runtime is unverified.** `RECORD_AUDIO` is declared
  in the manifest, but declaration is not grant. The app has no
  `permission_handler` dependency; `speech_to_text` does not prompt for itself.
  Whether `first_prayer_speech_page` works today because something requests the
  permission, or only on devices whose IME requests it, is unknown. This must be
  checked on a device before the affordance is trusted, and it may require adding
  a permission flow.
- **On-device recogniser availability varies** by device and locale. On-device
  only is the intent, so some devices will show the unavailable notice. That is
  the accepted cost.
- Fourteen surfaces is a wide diff. Each substitution is mechanical once
  `SayableField` exists, but the guard test should land with the first
  conversion so the sweep cannot half-finish.

## Sequence

Deliberate order, so a failure at any step leaves a working app:

1. `SpeechCaptureService` with its tests, and the device permission check. If
   permission turns out to need a new flow, that is resolved before any screen
   depends on it.
2. `SayableField` with its tests, including the reconciliation cases.
3. `commitment_journey_screen` and `first_prayer_speech_page` converted, plus
   the guard test. The two existing surfaces are converted first on purpose:
   they prove the component against real callers, and they are the ones already
   carrying divergent behaviour.
4. The remaining surfaces. Each is one substitution plus its own widget test.
5. `encounter_form` last, because it is the only surface that also records, and
   the only one where two capture mechanisms share a sheet.

## Out of scope

- Any change to how Memory/Encounters record, store, or play audio.
- Any server-side handling of dictated text beyond the sync each surface
  already performs.
- The version that would let a formation reflection keep its audio.
- Suppressing or intercepting the keyboard's own dictation button.