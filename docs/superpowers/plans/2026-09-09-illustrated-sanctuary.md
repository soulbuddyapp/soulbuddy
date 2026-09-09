# Illustrated sanctuary and attentive reading

The user's approved reference is the visual target: ivory sculptural surfaces, gold light, an illustrated arch, compact functional tiles, expressive serif hierarchy and a floating navigation tray. The prior release only changed decoration. This pass changes the actual composition using bundled original artwork and functional controls.

## Implementation

- [x] Generate and bundle original sanctuary, prayer, scripture and renewal art. Keep prompts and provenance with assets.
- [x] Replace the forest/white palette with warm limestone, ivory and accessible bronze; use shared luminous backgrounds and raised surfaces.
- [x] Compose Today from a greeting, illustrated arch/formation invitation, prayer/Scripture/reflection tiles and existing daily actions. Keep one formation entry and existing saved progress.
- [x] Give Orientation an illustrated heading and connected Nugget rows with current/completed states and the full teaching option.
- [x] Use a floating navigation tray and consistent collection/reader details. Preserve compact saved-item rows.
- [x] Add a screen-awake scope with reference counting, route visibility, app lifecycle handling and native Android/iOS implementation. Apply to prayer, orientation, Scripture and meditation reading/session views.
- [x] Verify awake acquisition/release and lifecycle transitions with tests; check navigation, reader and Today regressions and narrow/large-text layouts.
- [x] Build release, install preserving phone data, inspect real device screenshots and awake window flags.

## Acceptance

The first Today viewport must visibly contain original sanctuary imagery and a functional orientation invitation. Decorative art is excluded from accessibility and all actions remain live Flutter widgets. Large text switches multi-column content to a vertical layout. Screen-awake ends on leaving a practice, hiding its route or backgrounding the app. Prayer text remains readable without image detail behind it.

## Verification

Full Flutter suite: 645 passing. Subsequent phone-width/navigation refinements: 31 targeted tests passing; final collection copy: 7 targeted tests passing. Final analyzer: no issues. Release APK built and installed with `adb install -r` to Honor BVL-N49, preserving user data; lastUpdateTime 2026-09-09 18:15:24. Existing completed orientation correctly advances Today to Scripture meditation.

Device inspection confirmed the two-column Today composition and single-line navigation. Android dumpsys reported KEEP_SCREEN_ON and mHoldScreenWindow during orientation and meditation readings, then mHoldScreenWindow=null after Back. Automated tests additionally cover multiple wake owners, route visibility, background/foreground, disposal, and 320/390px layouts at normal and 200% text. iOS implementation is included but not built on this Windows host.

Device screenshots: `.artifacts/orientation/sanctuary-today-device.png` and `.artifacts/orientation/sanctuary-orientation-device.png`. Release: `.artifacts/orientation/soulbuddy-latest-android.apk`.

Requested disk cleanup: standard `npm cache clean --force` and `flutter clean` completed. Flutter cleanup removed 1,434,638,152 bytes of disposable build/.dart_tool files; release APK and source retained. Shared old Gradle cache deletion was rejected by automatic approval review (no reason beyond blocked by policy), so those folders remain. C: free space after cleanup: 4.30 GiB.
