# Sacred Hour Meditation Flow

## Purpose

Make the Sacred Hour progress from prayer into reflection without redundant
actions, retain a chosen background sound, and connect the daily prayer to its
full chapter.

## Sacred Hour session

- `I prayed` records the selected prayer and person prayer, marks the current
  occurrence complete, then advances the session controller to meditation.
- The separate `Continue to work` action is removed.
- If recording fails, the session remains in the prayer phase and the action
  remains available.
- The meditation phase uses these exact strings:
  - **God speaks to us in meditation**
  - **Listen to know if your prayer needs something from you**
- Selecting a meditation prompt opens the reflection composer directly in write
  mode. Its title contains the prompt and the current local date; its body
  prompt contains the selected prompt. The existing microphone control remains
  available in the composer for spoken reflection.

## Today Sacred Hour card

- `Begin` appears only in the upcoming window.
- An active occurrence uses `Open`; a completed occurrence uses `Complete`.
- The leading audio control restores the persisted meditation sound and volume,
  loops it while active, and changes from play to pause while it is playing.
- The card stops audio when disposed or when the Today route is no longer
  visible.

## Daily scripture prayer

- Daily scripture retains the catalogued canonical book and chapter rather
  than deriving them from its display reference.
- The prayer section includes `Read full chapter`, opening the bundled RSVCE
  chapter with the screen kept awake.

## Verification

- Controller and widget tests cover prayer completion advancing to meditation,
  direct prompt capture, Sacred Hour card labels, play/pause behavior, and the
  full chapter action.
- Targeted Flutter tests, static analysis, and an Android build verify the
  change before installation.
