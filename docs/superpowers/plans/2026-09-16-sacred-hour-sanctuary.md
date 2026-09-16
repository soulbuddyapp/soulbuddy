# Sacred Hour Sanctuary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cluttered Sacred Hour session with one immersive sanctuary, coordinated prayer and sound playback, and reusable spoken prayer openings and closings.

**Architecture:** The Sacred Hour route becomes the sole owner of its foreground presentation and suppresses global overlays while active. Focused presentation widgets render the golden sanctuary while a device-local ritual-profile repository and a sequential playback coordinator reuse the existing private-audio store, Voice Tablet recording, meditation sound preferences, and session controller.

**Tech Stack:** Flutter 3 / Dart 3.9, Riverpod 3, go_router, Material 3, flutter_secure_storage, audioplayers, existing private `AudioAssetStore`, Flutter widget/unit tests, Android ADB and Google Play internal draft release.

---

## File map

**Create**

- `apps/soulbuddy/assets/images/sanctuary/sacred_hour_portal.webp` — production focal artwork copied from the approved user asset pack.
- `apps/soulbuddy/assets/images/sanctuary/prayer_ritual.webp` — small opening/closing setup artwork.
- `apps/soulbuddy/lib/app/app_overlay_visibility.dart` — pure route rule for suppressing global overlays.
- `apps/soulbuddy/lib/features/prayers/domain/prayer_ritual_profile.dart` — opening, closing, and private clip value objects.
- `apps/soulbuddy/lib/features/prayers/data/prayer_ritual_preferences_repository.dart` — serialized device-local ritual preferences.
- `apps/soulbuddy/lib/features/prayers/providers/prayer_ritual_providers.dart` — repository and short-recording providers.
- `apps/soulbuddy/lib/features/prayers/application/prayer_ritual_playback_coordinator.dart` — serialized opening/prayer/closing playback with sound-bed ducking.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_ritual_setup_sheet.dart` — progressively disclosed opening and closing setup.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_sanctuary_scaffold.dart` — full-screen visual shell.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_controls.dart` — compact Prayer, Sound, and completion controls.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_meditation_controls.dart` — quiet post-prayer reflection state.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_picker_sheet.dart` — purpose-aware prayer picker without sound controls.
- matching unit and widget tests listed in the tasks below.

**Modify**

- `apps/soulbuddy/lib/app/app.dart` — hide global players and reminder overlays on Sacred Hour routes.
- `apps/soulbuddy/lib/features/record/audio/providers/private_audio_cleanup_provider.dart` — preserve ritual clip files during startup cleanup.
- `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_sheet.dart` — show ritual summary before prayer recording.
- `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart` — pass prayer grounding into the recording flow.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart` — coordinate repositories, playback, notification state, and the new visual components.
- `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_music_sheet.dart` — remove after its prayer and sound responsibilities have moved to focused sheets.
- existing navigation, Sacred Hour, Voice Tablet, and cleanup tests.

## Task 1: Add approved assets and route-owned overlay policy

**Files:**

- Create: `apps/soulbuddy/assets/images/sanctuary/sacred_hour_portal.webp`
- Create: `apps/soulbuddy/assets/images/sanctuary/prayer_ritual.webp`
- Create: `apps/soulbuddy/lib/app/app_overlay_visibility.dart`
- Create: `apps/soulbuddy/test/app/app_overlay_visibility_test.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Modify: `apps/soulbuddy/test/app/app_navigation_test.dart`

- [ ] **Step 1: Write the failing route-policy test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app_overlay_visibility.dart';

void main() {
  test('only immersive session routes suppress global overlays', () {
    expect(
      AppOverlayVisibility.hideGlobalOverlays(
        Uri.parse('/sacred-hours/hour-1?occurrence=hour-1@now'),
      ),
      isTrue,
    );
    expect(
      AppOverlayVisibility.hideGlobalOverlays(Uri.parse('/today')),
      isFalse,
    );
    expect(
      AppOverlayVisibility.hideGlobalOverlays(
        Uri.parse('/prayers/saved/prayer-1'),
      ),
      isFalse,
    );
  });
}
```

Extend `app_navigation_test.dart` so the Sacred Hour route asserts all three
global hosts are absent by stable keys:

```dart
expect(find.byKey(const Key('spiritual-session-mini-player')), findsNothing);
expect(find.byKey(const Key('prayer-reminder-overlay-host')), findsNothing);
expect(find.byKey(const Key('altar-reminder-overlay-host')), findsNothing);
```

- [ ] **Step 2: Run the tests and verify the new expectations fail**

Run:

```powershell
cd apps/soulbuddy
flutter test test/app/app_overlay_visibility_test.dart test/app/app_navigation_test.dart
```

Expected: compilation fails because `AppOverlayVisibility` does not exist, and
the current app still renders global overlay hosts above the Sacred Hour route.

- [ ] **Step 3: Add the pure route rule**

```dart
abstract final class AppOverlayVisibility {
  static bool hideGlobalOverlays(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'sacred-hours';
}
```

In `SoulBuddyApp.builder`, wrap the positioned overlay column in a
`ListenableBuilder` attached to `appRouter.routerDelegate`. Return
`SizedBox.shrink()` whenever the pure rule returns true. Add stable keys to the
prayer and altar hosts without changing their ordinary behavior.

```dart
ListenableBuilder(
  listenable: appRouter.routerDelegate,
  builder: (context, _) {
    final uri = appRouter.routerDelegate.currentConfiguration.uri;
    if (AppOverlayVisibility.hideGlobalOverlays(uri)) {
      return const SizedBox.shrink();
    }
    return const _GlobalOverlayColumn();
  },
)
```

- [ ] **Step 4: Copy the two approved WebP assets at native resolution**

```powershell
Copy-Item -LiteralPath 'C:\Users\Son\Downloads\divine_beauty_mobile_assets\artwork\hero-portal-clean.webp' -Destination 'apps\soulbuddy\assets\images\sanctuary\sacred_hour_portal.webp'
Copy-Item -LiteralPath 'C:\Users\Son\Downloads\divine_beauty_mobile_assets\artwork\prayer-scene-fade.webp' -Destination 'apps\soulbuddy\assets\images\sanctuary\prayer_ritual.webp'
```

Do not resize or recompress them. The existing `assets/images/sanctuary/`
pubspec entry already includes both files.

- [ ] **Step 5: Run the focused tests**

Run the Step 2 command again.

Expected: PASS; the ordinary saved-prayer test still sees the mini-player, and
the Sacred Hour test sees no global overlays.

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/assets/images/sanctuary apps/soulbuddy/lib/app apps/soulbuddy/test/app
git commit -m "feat: give sacred hour exclusive overlay ownership"
```

## Task 2: Persist prayer ritual defaults and protect their audio

**Files:**

- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_ritual_profile.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_ritual_preferences_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/providers/prayer_ritual_providers.dart`
- Create: `apps/soulbuddy/test/features/prayers/prayer_ritual_preferences_test.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/providers/private_audio_cleanup_provider.dart`
- Modify: `apps/soulbuddy/test/features/record/memory_audio_cleanup_test.dart`

- [ ] **Step 1: Write failing domain and persistence tests**

Cover four exact behaviors:

```dart
test('Catholic prayer recommends the Trinitarian opening and Amen', () {
  final profile = PrayerRitualProfile.recommended(
    PrayerGrounding.catholic,
  );
  expect(profile.opening, PrayerOpening.trinitarian);
  expect(profile.closing, PrayerClosing.amen);
  expect(profile.explicitChoice, isFalse);
});

test('an explicit saved choice wins over later grounding', () async {
  final storage = <String, String>{};
  final repository = PrayerRitualPreferencesRepository(
    read: (key) async => storage[key],
    write: (key, value) async => storage[key] = value,
  );
  await repository.save(
    const PrayerRitualProfile(
      opening: PrayerOpening.none,
      closing: PrayerClosing.amen,
      explicitChoice: true,
    ),
  );
  expect(
    (await repository.load(PrayerGrounding.catholic)).opening,
    PrayerOpening.none,
  );
});

test('ritual clip storage keys are reported to orphan cleanup', () async {
  final profile = PrayerRitualProfile(
    opening: PrayerOpening.custom,
    closing: PrayerClosing.amen,
    explicitChoice: true,
    openingAudio: _clip('ritual/opening.m4a'),
    closingAudio: _clip('ritual/amen.m4a'),
  );
  await repository.save(profile);
  expect(
    await repository.ownedStorageKeys(),
    {'ritual/opening.m4a', 'ritual/amen.m4a'},
  );
});
```

Also extend cleanup coverage so those keys survive while an unrelated orphan is
deleted.

- [ ] **Step 2: Run the tests and verify failure**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_ritual_preferences_test.dart test/features/record/memory_audio_cleanup_test.dart
```

Expected: compilation fails because ritual types and repository are absent.

- [ ] **Step 3: Add immutable ritual value objects**

Use explicit preset identifiers and keep customer copy at the presentation
boundary:

```dart
enum PrayerOpening { inJesusName, trinitarian, custom, none }
enum PrayerClosing { amen, custom, none }

@immutable
class PrayerRitualAudioClip {
  const PrayerRitualAudioClip({
    required this.id,
    required this.storageKey,
    required this.mimeType,
    required this.duration,
    required this.byteSize,
    required this.waveform,
  });

  final String id;
  final String storageKey;
  final String mimeType;
  final Duration duration;
  final int byteSize;
  final List<double> waveform;

  PrivateAudioTrack get track => PrivateAudioTrack(
    id: id,
    storageKey: storageKey,
    duration: duration,
  );
}

@immutable
class PrayerRitualProfile {
  const PrayerRitualProfile({
    required this.opening,
    required this.closing,
    required this.explicitChoice,
    this.openingAudio,
    this.closingAudio,
  });

  factory PrayerRitualProfile.recommended(PrayerGrounding grounding) =>
      PrayerRitualProfile(
        opening: grounding == PrayerGrounding.catholic
            ? PrayerOpening.trinitarian
            : PrayerOpening.inJesusName,
        closing: PrayerClosing.amen,
        explicitChoice: false,
      );

  final PrayerOpening opening;
  final PrayerClosing closing;
  final bool explicitChoice;
  final PrayerRitualAudioClip? openingAudio;
  final PrayerRitualAudioClip? closingAudio;

  String toJson() => jsonEncode({
    'opening': opening.name,
    'closing': closing.name,
    'explicitChoice': explicitChoice,
    'openingAudio': openingAudio?.toMap(),
    'closingAudio': closingAudio?.toMap(),
  });
}
```

`PrayerRitualAudioClip.toMap()` writes `id`, `storageKey`, `mimeType`,
`durationMs`, `byteSize`, and `waveform`. `decodePrayerRitualProfile` validates
each enum with `values.where((value) => value.name == saved).firstOrNull`,
requires every audio field before constructing a clip, and falls back to
`PrayerRitualProfile.recommended(fallbackGrounding)` on malformed data.

- [ ] **Step 4: Add ordered secure-storage persistence**

Follow the existing meditation sound preference pattern. Use storage key
`prayer.ritual_profile.v1`, JSON enum names, milliseconds, and numeric waveform
values. Invalid JSON or missing clip fields must return the grounding-based
recommendation instead of throwing. Serialize writes through a `_pending`
future so rapid updates cannot reorder.

```dart
class PrayerRitualPreferencesRepository {
  PrayerRitualPreferencesRepository({required this.read, required this.write});

  static const storageKey = 'prayer.ritual_profile.v1';
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  Future<void> _pending = Future.value();

  Future<PrayerRitualProfile> load(PrayerGrounding grounding) async {
    await _pending;
    final raw = await read(storageKey);
    if (raw == null) return PrayerRitualProfile.recommended(grounding);
    return decodePrayerRitualProfile(raw, fallbackGrounding: grounding);
  }

  Future<void> save(PrayerRitualProfile profile) {
    final saving = _pending.then((_) => write(storageKey, profile.toJson()));
    _pending = saving.catchError((Object _) {});
    return saving;
  }

  Future<Set<String>> ownedStorageKeys() async {
    final profile = await load(PrayerGrounding.generalChristian);
    return {
      if (profile.openingAudio case final clip?) clip.storageKey,
      if (profile.closingAudio case final clip?) clip.storageKey,
    };
  }
}
```

- [ ] **Step 5: Add Riverpod providers and cleanup ownership**

Build the repository from `secureStorageProvider`. Add
`prayerRitualPreferencesProvider` and include its `ownedStorageKeys` callback in
`privateAudioStartupCleanupProvider.ownedStorageKeyLoaders`.

- [ ] **Step 6: Run tests and commit**

Run the Step 2 command, then:

```powershell
git add apps/soulbuddy/lib/features/prayers apps/soulbuddy/lib/features/record/audio/providers apps/soulbuddy/test/features/prayers apps/soulbuddy/test/features/record
git commit -m "feat: save prayer opening and closing defaults"
```

## Task 3: Add focused opening and closing recording

**Files:**

- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_ritual_setup_sheet.dart`
- Create: `apps/soulbuddy/test/features/prayers/prayer_ritual_setup_sheet_test.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/providers/prayer_ritual_providers.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_sheet.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart`
- Modify: `apps/soulbuddy/test/features/prayers/voice_tablet_flow_test.dart`

- [ ] **Step 1: Write failing setup and integration widget tests**

The setup test must verify concise copy, progressive disclosure, and saved
audio attachment:

```dart
expect(find.text('Opening'), findsOneWidget);
expect(find.text("In Jesus' Name I pray."), findsOneWidget);
expect(find.text('Closing'), findsOneWidget);
expect(find.text('Amen.'), findsOneWidget);
expect(find.text('Record the opening'), findsNothing);

await tester.tap(find.text("In Jesus' Name I pray."));
await tester.pumpAndSettle();
expect(find.text('Record the opening'), findsOneWidget);
expect(find.text("In Jesus' Name I pray."), findsWidgets);
```

The Voice Tablet test must verify the ritual summary appears before the full
prayer recorder and that `Record prayer` enters the existing capture panel.

- [ ] **Step 2: Run tests and verify failure**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_ritual_setup_sheet_test.dart test/features/prayers/voice_tablet_flow_test.dart
```

Expected: compilation fails because the setup sheet and grounding argument are
missing.

- [ ] **Step 3: Add short-lived capture controllers**

Create `PrayerRitualClipKind { opening, closing }` and a family provider that
uses the existing recorder and audio store with a 20-second maximum:

```dart
final prayerRitualAudioCaptureControllerProvider = FutureProvider.autoDispose
    .family<AudioCaptureController, PrayerRitualClipKind>((ref, kind) async {
  final store = await ref.watch(audioAssetStoreProvider.future);
  final controller = AudioCaptureController(
    recorder: createRecordPluginAudioRecorder(store),
    allocateTemporary: () => store.allocateTemporary(
      takeId: const Uuid().v7(),
      extension: kIsWeb ? 'webm' : 'm4a',
    ),
    maximumDuration: const Duration(seconds: 20),
  );
  ref.onDispose(() => unawaited(controller.close()));
  return controller;
});
```

- [ ] **Step 4: Build the progressively disclosed ritual sheet**

The first view contains exactly two `ListTile`s plus `Done`. Each tile opens a
choice view. Spoken choices open `AudioCapturePanel` with their exact phrase;
`custom` uses `My opening` or `My closing`; `none` returns immediately.

```dart
String openingPrompt(PrayerOpening value) => switch (value) {
  PrayerOpening.inJesusName => "In Jesus' Name I pray.",
  PrayerOpening.trinitarian =>
    'In the name of the Father, and of the Son, and of the Holy Spirit.',
  PrayerOpening.custom => 'My opening',
  PrayerOpening.none => 'No opening',
};

String closingPrompt(PrayerClosing value) => switch (value) {
  PrayerClosing.amen => 'Amen.',
  PrayerClosing.custom => 'My closing',
  PrayerClosing.none => 'No closing',
};
```

On continue, commit the reviewed draft to `AudioAssetStore` under a UUID,
replace only that clip in the profile, save the profile, then delete the old
clip after the new profile write succeeds. If persistence fails, retain the
new committed clip for retry and show `The recording was not saved. Try again.`
near the action.

- [ ] **Step 5: Integrate a compact ritual summary into Voice Tablet**

Add required `PrayerGrounding grounding` to `VoiceTabletSheet` and
`showVoiceTabletSheet`. Add `VoiceTabletSheetStep.ritual` before `fullPrayer`.
Render the two selected values and one primary `Record prayer` action. Each row
opens `PrayerRitualSetupSheet`; returning refreshes the saved profile. Keep the
existing full-prayer and optional refrain stages unchanged.

- [ ] **Step 6: Run tests and commit**

Run the Step 2 command, then:

```powershell
git add apps/soulbuddy/lib/features/prayers apps/soulbuddy/test/features/prayers
git commit -m "feat: guide spoken prayer openings and closings"
```

## Task 4: Coordinate prayer sequence and background sound

**Files:**

- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_ritual_playback_coordinator.dart`
- Create: `apps/soulbuddy/test/features/prayers/prayer_ritual_playback_coordinator_test.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/meditation_sound_bed_player.dart`

- [ ] **Step 1: Write failing playback tests with fake drivers**

Cover ordered playback, missing clips, ducking, restoration, pause/resume,
replacement, and route-exit cancellation:

```dart
test('plays opening prayer and closing while ducking the sound bed', () async {
  final player = FakePrayerTrackPlayer()..completeEachTrack = true;
  final sound = FakeSoundBedPlayer();
  final coordinator = PrayerRitualPlaybackCoordinator(
    player: player,
    soundBed: sound,
  );

  await coordinator.play(
    PrayerRitualPlaybackRequest(
      tracks: [_track('opening'), _track('prayer'), _track('closing')],
      soundBedPlaying: true,
      soundBedVolume: .16,
    ),
  );

  expect(player.playedIds, ['opening', 'prayer', 'closing']);
  expect(sound.volumes, [.04, .16]);
});

test('a second selection cancels the first sequence', () async {
  final first = coordinator.play(_request(['old-opening', 'old-prayer']));
  await coordinator.play(_request(['new-prayer']));
  await first;
  expect(player.playedIds.last, 'new-prayer');
  expect(player.playedIds, isNot(contains('old-prayer')));
});
```

The test fake implements the same small port used by production:

```dart
abstract interface class PrayerTrackPlayer implements Listenable {
  MemoryAudioPlaybackState get state;
  Future<void> play(PrivateAudioTrack track);
  Future<void> pause();
  Future<void> stop();
}

class PrayerRitualPlaybackRequest {
  const PrayerRitualPlaybackRequest({
    required this.tracks,
    required this.soundBedPlaying,
    required this.soundBedVolume,
  });

  final List<PrivateAudioTrack> tracks;
  final bool soundBedPlaying;
  final double soundBedVolume;
}
```

The production adapter delegates `state`, listeners, `playTrack`, `pause`, and
`stop` to `MemoryAudioPlaybackCoordinator`. The fake records track IDs and
emits `MemoryAudioPlaybackStatus.completed` deterministically.

- [ ] **Step 2: Run and verify failure**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_ritual_playback_coordinator_test.dart
```

- [ ] **Step 3: Implement a generation-cancelled audio queue**

Expose immutable state with `idle`, `loading`, `playing`, `paused`, and `error`.
The request receives already-resolved `PrivateAudioTrack`s, a sound-bed-playing
flag, and the normal sound volume. For each track, call `playTrack`, listen until
`completed` or `error`, then advance. Increment `_generation` on every `play`
and `stop`; stale loops return before starting another track.

```dart
Future<void> play(PrayerRitualPlaybackRequest request) async {
  final generation = ++_generation;
  await player.stop();
  if (request.soundBedPlaying) await soundBed.setVolume(.04);
  for (final track in request.tracks) {
    if (generation != _generation) return;
    final completed = await _playToEnd(track, generation);
    if (!completed) break;
  }
  if (generation == _generation && request.soundBedPlaying) {
    await soundBed.setVolume(request.soundBedVolume);
  }
}
```

`stop(stopSoundBed: true)` stops both players; ordinary sequence replacement
stops only prayer audio and preserves the selected sound bed. `togglePrayer`
pauses a playing track and resumes the same track through `playTrack`.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/features/prayers/prayer_ritual_playback_coordinator_test.dart
git add apps/soulbuddy/lib/features/prayers/application apps/soulbuddy/test/features/prayers
git commit -m "feat: coordinate sacred prayer playback"
```

## Task 5: Split prayer and sound selection into focused sheets

**Files:**

- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_picker_sheet.dart`
- Create: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_prayer_picker_test.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Delete after migration: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_music_sheet.dart`

- [ ] **Step 1: Write the failing picker test**

```dart
expect(find.text('Prayer'), findsOneWidget);
expect(find.text('Morning offering'), findsOneWidget);
expect(find.text('Background music'), findsNothing);
await tester.tap(find.text('Morning offering'));
expect(chosen?.reference, const PrayerReference.personal('personal-1'));
```

Also verify the linked prayer is first and not duplicated among suggestions.

- [ ] **Step 2: Run and verify failure**

```powershell
cd apps/soulbuddy
flutter test test/features/sacred_hours/sacred_hour_prayer_picker_test.dart
```

- [ ] **Step 3: Implement separate sheets**

Build `SacredHourPrayerPickerSheet` with a concise `Prayer` heading, current
selection, ranked suggestions, and `New prayer`. Use one selectable row per
prayer; remove the repetitive `Choose` buttons.

Open the existing `MeditationSoundPicker` directly from a separate `Sound`
bottom sheet. Preserve the shared preference and preview behavior already in
`SacredHourSessionScreen`.

- [ ] **Step 4: Connect explicit prayer selection to one-time autoplay**

After saving `SacredHourDraft.fromHour`, resolve its Voice Tablet:

```dart
VoiceTabletSource voiceSource(PrayerDisplay prayer) => switch (prayer) {
  PersonalPrayer(:final id, :final currentRevisionId) =>
    VoiceTabletSource.personal(prayerId: id, revisionId: currentRevisionId),
  _ => VoiceTabletSource.library(prayerId: prayer.id),
};
```

Read `voiceTabletRepositoryProvider`, take the first matching tablet, and pass
`fullAudio` plus saved ritual clips to the playback coordinator. Trigger this
only from the explicit picker callback. Widget rebuilds and preference restores
must never invoke it.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/features/sacred_hours/sacred_hour_prayer_picker_test.dart
git add apps/soulbuddy/lib/features/sacred_hours apps/soulbuddy/test/features/sacred_hours
git commit -m "refactor: focus sacred hour prayer and sound choices"
```

## Task 6: Build the full-screen sanctuary shell

**Files:**

- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_sanctuary_scaffold.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_controls.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_meditation_controls.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Rewrite: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`

- [ ] **Step 1: Replace old widget expectations with sanctuary expectations**

The prayer-phase test must assert one image, one primary action, and no old
stacked actions:

```dart
expect(find.byKey(const Key('sacred-hour-portal')), findsOneWidget);
expect(find.text('We belong to God.'), findsOneWidget);
expect(find.byKey(const Key('sacred-hour-prayer-choice')), findsOneWidget);
expect(find.byKey(const Key('sacred-hour-sound-choice')), findsOneWidget);
expect(find.text("I've prayed"), findsOneWidget);
expect(find.text('Begin with prayer'), findsNothing);
expect(find.text('Quiet prayer'), findsNothing);
expect(find.text('Daily practice'), findsNothing);
expect(find.text('Open prayer'), findsNothing);
```

Add a test that tapping the Prayer and Sound controls calls separate callbacks,
and a test that the trailing prayer glyph changes from play to pause while a
recording is active.

- [ ] **Step 2: Add narrow, landscape, large-text, and reduced-motion tests**

Pump at `360x800`, `800x360`, and `MediaQuery.textScalerOf` equivalent 2.0.
Verify `tester.takeException()` is null and the primary action remains hittable.
With `disableAnimations: true`, pump once and expect the portal opacity to be
fully visible without waiting 280ms.

- [ ] **Step 3: Run and verify the old screen fails the new tests**

```powershell
cd apps/soulbuddy
flutter test test/features/sacred_hours/sacred_hour_session_test.dart
```

- [ ] **Step 4: Implement the sanctuary visual shell**

Use `CovenantGraceColors`, existing type roles, and native Material controls.
Do not introduce the generic lavender palette from the design search. The
portal is meaningful, receives the semantic label `Golden light and a figure
ascending`, preserves its 440:989 ratio, and is capped near 220 logical pixels
wide. The lower dock uses an opaque ivory surface with a subtle gold outline,
not translucent text over clouds.

```dart
class SacredHourSanctuaryScaffold extends StatefulWidget {
  const SacredHourSanctuaryScaffold({
    required this.child,
    required this.onExit,
    super.key,
  });

  final Widget child;
  final VoidCallback onExit;
}
```

The stack order is background gradient, centred portal, lower legibility scrim,
live title block, 48dp exit control, and safe-area bottom dock. Use only opacity
for the 280ms entry. `MediaQuery.disableAnimationsOf(context)` selects zero
duration. The animation never blocks taps.

- [ ] **Step 5: Implement compact prayer controls**

Use two equally weighted outlined controls with 8dp separation. Each has a
20–24dp outline icon, one primary label, and at most one truncated selected
value. Their full touch regions remain at least 56dp high. Place the sole filled
button below them.

```dart
SacredHourPrayerControls(
  prayerLabel: prayerTitle ?? 'Choose prayer',
  soundLabel: selectedSound?.label ?? 'Silence',
  prayerPlaying: ritualPlayback.isPlaying,
  soundPlaying: soundPlaying,
  completing: completingPrayer,
  onPrayer: onPrayer,
  onPrayerPlayback: recordedPrayer == null ? null : onPrayerPlayback,
  onSound: onSound,
  onSoundPlayback: selectedSound == null ? null : onSoundPlayback,
  onPrayed: onPrayed,
)
```

During `onPrayed`, disable the primary button and replace its label with a small
progress indicator plus `Saving`. If completion fails, restore `I've prayed`
and announce `Prayer was not saved. Try again.` near the dock.

- [ ] **Step 6: Implement the quiet meditation state**

Crossfade the prayer dock to `SacredHourMeditationControls` in 220ms, or
immediately under reduced motion. Show the approved heading and subtitle, one
prompt, and a small `Another reflection` control that rotates through prompts.
Tapping the prompt invokes the existing direct reflection callback with no
intermediate recorder screen.

- [ ] **Step 7: Remove the old AppBar and stacked content**

`SacredHourSessionView` should no longer build `AppBar`, `ListTile`,
`ChoiceChip`, `Daily practice`, or combined prayer/music buttons. Keep the
session controller, timer, `I've prayed` transition, and direct reflection
behavior. The remaining time is one tabular, low-emphasis text value within the
title block and never a separate card.

- [ ] **Step 8: Run tests and commit**

```powershell
flutter test test/features/sacred_hours/sacred_hour_session_test.dart test/app/app_navigation_test.dart
git add apps/soulbuddy/lib/features/sacred_hours apps/soulbuddy/test/features/sacred_hours apps/soulbuddy/test/app
git commit -m "feat: create the sacred hour sanctuary"
```

## Task 7: Wire lifecycle, audio focus, notification, and screen-awake behavior

**Files:**

- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_system_notification.dart`
- Modify: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`
- Modify: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_system_notification_test.dart`

- [ ] **Step 1: Add failing lifecycle tests**

Use fakes to prove:

1. selecting a recorded prayer invokes ritual playback once;
2. rebuilding the widget does not invoke it again;
3. pushing a full prayer or reflection stops both private and background audio;
4. disposing the route stops both players;
5. pause/resume state is reflected in the in-app glyph and system notification;
6. completing prayer leaves the system Sacred Hour notification active until
   the hour itself completes or exits.

- [ ] **Step 2: Run and verify failure**

```powershell
cd apps/soulbuddy
flutter test test/features/sacred_hours/sacred_hour_session_test.dart test/features/sacred_hours/sacred_hour_system_notification_test.dart
```

- [ ] **Step 3: Centralize screen-owned cleanup**

Add one idempotent method and call it before navigation and from `dispose`:

```dart
Future<void> _stopSanctuaryAudio() async {
  await _ritualPlayback.stop(stopSoundBed: true);
  await _backgroundPlayer.stop();
}
```

Guard async callbacks with `mounted`. Use a selection generation so a delayed
Voice Tablet lookup cannot start after the route has closed or a newer prayer
has been selected.

- [ ] **Step 4: Keep the system notification in sync**

The Prayer control pauses or resumes private audio and calls
`SacredHourSystemNotification.setPaused`. The Sound control updates only sound
playback and the visible state. Route exit calls the existing notification stop
path. Do not render the notification widget inside the app.

- [ ] **Step 5: Verify the existing route wrapper remains awake**

Keep `ScreenAwake` around `SacredHourSessionScreen` in `router.dart`. Add an
assertion in the route configuration test so later refactoring cannot remove
it.

- [ ] **Step 6: Run tests and commit**

Run the Step 2 command, then:

```powershell
git add apps/soulbuddy/lib/features/sacred_hours apps/soulbuddy/test/features/sacred_hours
git commit -m "fix: coordinate sacred hour audio lifecycle"
```

## Task 8: Accessibility, visual regression, and copy audit

**Files:**

- Create: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_sanctuary_golden_test.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_sanctuary_scaffold.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_prayer_controls.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_meditation_controls.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_ritual_setup_sheet.dart`

- [ ] **Step 1: Add semantic and contrast assertions**

Use `SemanticsTester` to verify labels for exit, prayer selection, prayer
playback state, sound selection, sound playback state, remaining time, and
`I've prayed`. Ensure no semantics label narrates layout or says `this screen`,
`here`, `use this`, or `in one place`.

- [ ] **Step 2: Add four golden cases**

Capture light and dark portrait, 2.0 text scale, and landscape. Use the approved
portal asset and deterministic controller time. The goldens must show one
portal, one bottom dock, and no clipped or overlapping controls.

- [ ] **Step 3: Run visual and accessibility checks**

```powershell
cd apps/soulbuddy
flutter test test/features/sacred_hours/sacred_hour_sanctuary_golden_test.dart --update-goldens
flutter test test/features/sacred_hours/sacred_hour_sanctuary_golden_test.dart
rg -n -i "what you've created|keep what you create|return to|in one place|this screen|this page|use this to|you can find" lib/features/sacred_hours lib/features/prayers/presentation/prayer_ritual_setup_sheet.dart
```

Expected: both golden runs pass and the copy scan returns no matches.

- [ ] **Step 4: Commit**

```powershell
git add apps/soulbuddy/test/features/sacred_hours apps/soulbuddy/lib/features/sacred_hours apps/soulbuddy/lib/features/prayers/presentation/prayer_ritual_setup_sheet.dart
git commit -m "test: verify sacred hour sanctuary experience"
```

## Task 9: Full verification, device installation, and Play draft

**Files:**

- Verify: `apps/soulbuddy/lib/`
- Verify: `apps/soulbuddy/test/`
- Build: `apps/soulbuddy/android/`

- [ ] **Step 1: Format and run static analysis**

```powershell
cd apps/soulbuddy
dart format lib test
flutter analyze
```

Expected: no analyzer errors or warnings introduced by this change.

- [ ] **Step 2: Run targeted and full tests**

```powershell
flutter test test/app/app_overlay_visibility_test.dart test/app/app_navigation_test.dart test/features/prayers/prayer_ritual_preferences_test.dart test/features/prayers/prayer_ritual_setup_sheet_test.dart test/features/prayers/prayer_ritual_playback_coordinator_test.dart test/features/prayers/voice_tablet_flow_test.dart test/features/sacred_hours/sacred_hour_prayer_picker_test.dart test/features/sacred_hours/sacred_hour_session_test.dart test/features/sacred_hours/sacred_hour_system_notification_test.dart
flutter test
```

Expected: all targeted tests and the full suite pass.

- [ ] **Step 3: Build and install the debug APK on the connected device**

```powershell
adb devices
flutter build apk --debug
adb install -r -d 'build\app\outputs\flutter-apk\app-debug.apk'
adb shell monkey -p app.soulbuddy.soulbuddy -c android.intent.category.LAUNCHER 1
```

On-device review must exercise: notification entry, picker selection, automatic
recorded-prayer playback, background sound ducking, `I've prayed`, direct
reflection capture, back/exit cleanup, screen-awake behavior, dark theme,
landscape, and large system text.

- [ ] **Step 4: Fix only observed defects and rerun affected checks**

Every fix gets a failing regression test first. Re-run the affected focused
test, `flutter analyze`, and the debug build after the final fix.

- [ ] **Step 5: Build the next signed app bundle**

Query the current Play build number and use the next integer:

```powershell
google-play.exe get-latest-build-number --credentials '@file:C:\Users\Son\cowork\pbc\mobile_customer\android\credentials\google-play-service.json' --package-name app.soulbuddy.soulbuddy --json --no-color
flutter build appbundle --release --build-name 1.0.0 --build-number 8
```

Expected: `build/app/outputs/bundle/release/app-release.aab` exists and is signed.

- [ ] **Step 6: Upload to the internal track as draft and verify**

Use the existing Google Play service account and the repository's proven
resumable-upload helper. Set internal track status to `draft`; do not promote to
production. Re-read the internal track after commit and verify the new version
code appears with draft status.

- [ ] **Step 7: Commit fixes, push, and confirm a clean tree**

```powershell
git status --short
git push origin codex/daily-video-formation
git status --short --branch
```

Expected: clean worktree and local branch aligned with origin after the final
verification commit.
