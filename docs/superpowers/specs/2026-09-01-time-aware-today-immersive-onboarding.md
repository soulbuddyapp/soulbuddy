# Time-aware Today and immersive onboarding

## Purpose

SoulBuddy should meet a person in the part of the day they are actually living and introduce the app as a humble daily companion for communion with God. Onboarding should teach the repeatable rhythm instead of presenting a generic product tour.

## Today behavior

- A Sacred Hour is prominent on Today only while it is active or during the 60 minutes before it begins.
- A distant future hour is not presented as a current instruction. It remains available in Sacred Hours and through its scheduled reminder.
- The card distinguishes `Now` from `In N min` and retains timezone-aware, cross-midnight handling.
- The repository may continue to provide the current-or-next hour; the Today presentation owns the prominence policy.

## Onboarding experience

The opening sequence is a four-part guided ritual:

1. **Come as you are** — SoulBuddy helps begin a daily communion with God that is personal and simple.
2. **Remember His deeds** — encounters, promises, Scripture, people, and lessons are kept where the person can return to them.
3. **Build a faithful rhythm** — Bring, Pray, Act, Remember becomes the clear repeatable pattern.
4. **Set apart your hours** — the person configures morning and evening Sacred Hours before continuing into the existing first-goal flow.

The sequence uses SoulBuddy's established natural limestone slabs, incised covenant-gold marks, and light-wash palette. Each scene runs one short entrance sequence: slab reveal, progressive mark illumination, and a restrained waveform-like light response. It does not use branches, ornamental confetti, infinite decorative motion, or rounded wellness graphics.

## Sensory feedback

- Advancing a scene produces a small selection haptic and soft tap.
- Reaching Sacred Hours produces one gentle sacred chime.
- Confirming setup produces the existing restrained completion feedback.
- Feedback is best-effort, never blocks navigation, and honors in-app sound/haptic preferences.
- System or in-app reduced-motion settings replace the entrance sequence with the completed static state.

## Usability and accessibility

- One primary action is visible at a time; the quiet `Go to Today` escape remains.
- Copy stays short and spiritually grounded.
- The experience fits ordinary phone heights without requiring scrolling; scrolling remains available for large text and very small screens.
- Visuals have semantic labels, controls retain 48dp targets, and no meaning depends on motion, sound, haptics, or color alone.

## Verification

- Pure time-window tests cover active, upcoming, distant evening-in-morning, timezone, and cross-midnight cases.
- Widget tests cover copy, sensory cues, scene progression, reduced motion, small screens, and Today card labels.
- Flutter analysis, focused tests, full tests, and an Android build complete before device/emulator review.
