# Guide and Teaching Reflection Implementation Plan

> **For agentic workers:** Use the executing-plans skill to implement this plan in the current session. Keep the implementation limited to teaching, Guide identity, and its name setting.

**Goal:** Give people a named, illustrated companion and inviting, private reflection after a daily teaching.

**Architecture:** Store a device-local Guide preference separately from the existing daily formation progress. Use reviewed, day-keyed reflection copy with a fallback to the existing catalogue, and extract a keyboard-aware completion flow that saves before closing. Keep the existing completion JSON and network activity contract intact.

**Tech stack:** Flutter, Dart, Riverpod, flutter_secure_storage, existing SayableField and Flutter widget tests.

**Design:** `docs/superpowers/specs/2026-11-13-guide-teaching-reflection-design.md`.

## File map

- Create `apps/soulbuddy/lib/features/guide/domain/guide_profile.dart`: name rules and suggested-name selection.
- Create `apps/soulbuddy/lib/features/guide/data/guide_repository.dart`: device-local name persistence.
- Create `apps/soulbuddy/lib/features/guide/providers/guide_providers.dart`: repository and asynchronous profile provider.
- Create `apps/soulbuddy/lib/features/guide/presentation/guide_illustration.dart`: accessible decorative art and fallback.
- Create `apps/soulbuddy/lib/features/guide/presentation/guide_intro_sheet.dart`: introduction and name selection.
- Create `apps/soulbuddy/lib/features/guide/presentation/guide_name_setting.dart`: rename interaction.
- Create `apps/soulbuddy/lib/features/daily_formation/domain/teaching_reflection_prompts.dart`: reviewed prompts keyed by day, with original catalogue fallback.
- Create `apps/soulbuddy/lib/features/daily_formation/presentation/teaching_reflection_sheet.dart`: response inputs, private label, save/retry and completion result.
- Modify `apps/soulbuddy/lib/features/daily_formation/presentation/daily_formation_card.dart`: introduce Guide once, open reflection, and record completion only after persistence succeeds.
- Modify `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`: add name setting using existing settings patterns.
- Add production artwork under `apps/soulbuddy/assets/images/guide/` and register it in `apps/soulbuddy/pubspec.yaml`.
- Create tests under `apps/soulbuddy/test/features/guide/` and `apps/soulbuddy/test/features/daily_formation/`.

## Task 1: Guide identity and storage

- [ ] Add tests in `test/features/guide/guide_repository_test.dart` using an in-memory map and injected reader/writer. Cover absent profile, confirmed name surviving a new repository instance, trimmed custom name, and write failure propagated to the caller. Verify no name is written merely by selecting a suggestion.
- [ ] Run `flutter test test/features/guide/guide_repository_test.dart` from `apps/soulbuddy`; confirm the new tests fail because the Guide classes do not exist.
- [ ] Implement `GuideProfile` with one `name` value and validation of 1–40 Unicode characters after trimming. Use `characters` for user-perceived character count. Expose `GuideProfile.validateName(String)` and deterministic `suggestName(int index)` over `['Arel', 'Elio', 'Neri', 'Oria']`; inject random selection at the presentation boundary for reproducible tests.
- [ ] Implement `GuideRepository({required read, required write})` using the secure-storage key `soulbuddy.guide.name.v1`. `load()` returns null for an absent value and propagates storage failures; `save(name)` validates and persists the trimmed name, propagating failures. Add a Riverpod provider using the same `secureStorageProvider` as `dailyFormationRepositoryProvider`.
- [ ] Run the repository test and `flutter analyze lib/features/guide`; expect success. Inspect serialized storage to ensure it includes only the name.

## Task 2: Visual assets and name interaction

- [ ] Use the approved Guide concept as a reference to create consistent, separately cropped transparent PNGs: `welcome.png`, `listening.png`, `encouraging.png`, `frustrated.png`, `inspired.png`, and `protective.png`. Keep the rounded head free of antennae, give the Guide a consistent luminous golden halo signifying connection to God, and preserve the same character across expressions. Use radiant light, grounded poses and nuanced expressions to convey heavenly strength; avoid muscular anatomy. Use frustration to acknowledge difficulty, never to judge the person; use the shield of light and flame as symbolic accents without violence or promises of protection. Review at 48–120 logical pixels for recognizable expression; verify transparent edges and keep all text outside the artwork. Register `assets/images/guide/` in `pubspec.yaml`.
- [ ] Add `test/features/guide/guide_intro_sheet_test.dart` covering suggested-name display, accepting it, editing it, empty/overlong validation, save error with retry, and continuing unnamed after a storage failure. Verify reopening an accepted profile skips introduction and that dismissing does not persist a name.
- [ ] Implement `GuideIllustration` with fixed aspect ratio, `ExcludeSemantics` for decorative art and an `errorBuilder` that leaves a modest empty space without breaking the flow. Implement `GuideIntroSheet` using the existing theme, “Meet your Guide”, a prefilled editable suggestion and an explicit confirm button. For load/save failures offer “Try again” and “Continue without a name”; retain input on retry.
- [ ] Add `guide_name_setting.dart` and integrate it in Settings. Test an existing name appears, rename persists after provider reload, cancel leaves the previous name, and write failure retains the entered value.
- [ ] Run `flutter test test/features/guide` and `flutter analyze lib/features/guide lib/features/settings/presentation/settings_screen.dart`; expect success.

## Task 3: Reviewed questions and fallback

- [ ] Add `test/features/daily_formation/teaching_reflection_prompts_test.dart`. Verify approved prompts for days 1–3, fallback to the existing `FormationDay.reflection` and `.action` for day 4 and an unknown future day, and no dependency on a video transcript or chosen video.
- [ ] Create an immutable `TeachingReflectionPrompts` holding `reflectionQuestion` and `actionQuestion`, with a `forDay(FormationDay day)` selector. Use these reviewed candidates, subject to editorial approval:

```dart
const reviewedTeachingPrompts = <int, (String, String)>{
  1: ('When did you last feel truly seen?', 'Who could you help feel seen today?'),
  2: ('What do you reach for when life feels heavy?', 'What could give you a moment of life today?'),
  3: ('What small choice has been troubling your conscience?', 'What is one safer choice you can make next time?'),
};
```

- [ ] Check the questions against each day's focus and all three offered video options. Revise wording after editorial review if it makes an unsupported assumption; preserve existing catalogue copy for all days without approved replacement. Run the new prompt test and `flutter test test/features/daily_formation/formation_catalog_test.dart`; expect success.

## Task 4: Teaching reflection and safe persistence

- [ ] Create `test/features/daily_formation/teaching_reflection_sheet_test.dart`. Exercise typed responses, empty responses, speech field availability, keyboard scrolling, dismissal without completion, and retry after a simulated storage failure. Verify answers remain present after a failed save and no completion callback is fired until save succeeds.
- [ ] Extract the completion UI from `daily_formation_card.dart` into `TeachingReflectionSheet`. Show listening artwork, “Private reflection”, one reflection question and an optional practical question. Retain `SayableField` for both answers, make the layout scrollable and respect keyboard insets. Preserve current unrestricted text length and existing speech-unavailable handling.
- [ ] Inject a `Future<void> Function(FormationCompletion)` save callback. On confirm, disable duplicate submissions, await the save, then return success; on failure show “Could not save. Try again.” and retain both controllers. Back/dismiss returns no completion. Map reflection and action into the existing `FormationCompletion` fields, preserving compatibility with existing secure storage.
- [ ] Change `_complete` in `daily_formation_card.dart` to load the Guide preference, offer introduction when absent, handle storage failure with retry or unnamed continuation, and open the reflection. Call `recordDailyFormationCompleted` only after a successful `completeDailyFormation`. Do not alter the explicit Finished requirement.
- [ ] Add a widget/integration test proving failed writes do not advance the day or send a completed event, successful retry sends exactly one event, and the network body contains only `formation_video_id` and `activity_type`. Run `flutter test test/features/daily_formation` and the Guide tests; expect success.

## Task 5: Review on device

- [ ] Run `flutter analyze` and the focused tests above. Run existing `daily_formation_repository_test.dart` to verify old completion JSON loads unchanged.
- [ ] Run the app on an Android device with a small viewport and again with large system text. Confirm introduction, custom naming, response entry by keyboard and speech, private label, save/retry, Settings rename, close/reopen persistence and day advancement. Check TalkBack focus order and text-only image fallback.
- [ ] Inspect network test output for response and name leakage; do not log actual private input. Verify the Guide never implies it is the user's real guardian angel and artwork is not the sole carrier of meaning.
- [ ] Have product/editorial review the mascot, invented names, and day 1–3 prompts before releasing. Record review status in the asset provenance file and document that the remaining days retain existing content pending review.
