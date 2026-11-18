# Inline recording implementation plan

**Goal:** Start recording in place on the first tap across the app, with a real microphone-level display and safe review and save.

**Architecture:** Reuse the capture controller and playback reservation, presenting its state in a compact inline panel. Connect each entry point to its existing persistence path, keeping a failed save retryable and preventing context changes from retargeting a take.

**Verification:** Exercise permission, amplitude, playback handoff, save without preview, interruptions, discard, recovery and each integration with focused Flutter tests; build and install an isolated offline Android QA candidate for physical listening checks.

- [ ] Add and test an inline capture surface and first-tap start.
- [ ] Integrate contextual notes and reflections with direct memory persistence and ownership-safe linking.
- [ ] Integrate personal prayer creation and remaining recording entry points without capture sheets.
- [ ] Run targeted tests and analysis; inspect accessibility and failure paths.
- [ ] Build, verify, install and launch the separate Android QA app.
