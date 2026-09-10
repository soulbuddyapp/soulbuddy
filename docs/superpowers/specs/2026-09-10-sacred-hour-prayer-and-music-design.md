# Sacred Hour prayer and music

## Goal

Give an active Sacred Hour one compact prayer-and-music control that connects a time of prayer to relevant personal or library prayers and calm background music.

## Interaction

The prayer phase gains a `Prayer and music` action. It opens one modal with three parts:

1. The prayer already linked to the hour, when present.
2. Purpose-aware suggestions: morning prioritizes daily, gratitude, and guidance; evening prioritizes gratitude, forgiveness, and difficult-time prayers; custom hours prioritize daily, guidance, and work. Personal prayers lead each group, then library prayers. A user may attach any listed prayer to the Sacred Hour, and may begin a new personal prayer.
3. The shared background-sound picker, including silence and motivational music. A selected sound plays for the active Sacred Hour, uses the saved sound and volume preference, and stops when the session leaves or is covered by an opened prayer or reflection.

## Data and boundaries

`SacredHourPrayerSuggestions` is a pure selector over `PrayerDisplay` values. It isolates ranking from the modal and provides deterministic, testable ordering.

`SacredHourDraft.fromHour` preserves all existing Sacred Hour fields while attaching a selected prayer through the existing repository save path. No database change is needed.

The session owns one `MeditationSoundBedPlayer`, restores the existing sound preference for its control but does not start music until the user selects it. It saves subsequent choices through the existing preference repository and disposes the player on exit.

## Copy

Customer-visible labels state the immediate spiritual object or task: `Prayer and music`, `Suggested prayers`, `Background music`, `Add a prayer`, and `Choose`. They do not explain the interface or storage.

## Acceptance

- An active Sacred Hour offers the modal from its prayer phase.
- Suggested prayers are relevant to the Sacred Hour purpose and exclude an already linked prayer.
- Choosing a prayer persists the link without altering the hour’s time, duration, reminder, person, or reminder sound.
- Starting a new personal prayer carries the relevant initial purpose.
- The modal offers the existing background music choices; changing the choice plays it for the current Sacred Hour and saves the preference.
- Music stops when opening another practice or leaving the Sacred Hour.
- Automated tests cover ranking, persisted attachment, session music lifecycle, and narrow mobile layout.
