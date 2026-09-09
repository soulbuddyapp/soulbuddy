# Compact Spiritual Actions and Session Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compact Goal and Today actions, place a richer sound picker beside reflection, and provide one persistent pause/resume player for active spiritual audio sessions.

**Architecture:** Keep repository completion semantics unchanged and add presentation state for collapsed Today confirmations. Extend the existing meditation sound model and sound-bed player. Add a root-scoped `SpiritualSessionController` that stores session metadata and delegates playback commands to the existing memory, prayer, meditation, and Sacred Hour players.

**Tech Stack:** Flutter, Dart, Riverpod 3, GoRouter, audioplayers, flutter_local_notifications, flutter_test.

---

### Task 1: Compact Goal resource rows

**Files:**
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goal_today_sections.dart`
- Modify: `apps/soulbuddy/test/features/goals/goal_today_sections_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Add tests that locate `goal-today-row-<stableKey>`, assert its visible height is at most 72 logical pixels at normal text scale, assert the primary `Pray` action remains visible, and open `goal-today-more-<stableKey>` to verify Details is available.

```dart
testWidgets('uses compact prayer row with primary Pray and More actions', (
  tester,
) async {
  final item = _legacyPrayerItem();
  await tester.pumpWidget(_host(item.snapshot));

  final row = find.byKey(const ValueKey('goal-today-row-legacy-prayer'));
  expect(tester.getSize(row).height, lessThanOrEqualTo(72));
  expect(find.text('Pray'), findsOneWidget);
  await tester.tap(
    find.byKey(const ValueKey('goal-today-more-legacy-prayer')),
  );
  await tester.pumpAndSettle();
  expect(find.text('Details'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test --no-pub test/features/goals/goal_today_sections_test.dart`

Expected: FAIL because the compact row keys and More menu do not exist.

- [ ] **Step 3: Replace stacked row actions with compact trailing controls**

Implement `_ResourceRow` as a `ConstrainedBox` with `minHeight: 56`, a tappable `Expanded` title area, a direct primary `TextButton`, and `PopupMenuButton<_ResourceMenuAction>`. Map prayer resources to `Pray`, scripture to `Open`, and ordinary actions to `Done`.

```dart
enum _ResourceMenuAction { details, complete }

String _primaryLabel(GoalTodayResourceItem item) =>
    item.resource.kind == GoalTodayResourceKind.prayer ? 'Pray' : 'Open';

ConstrainedBox(
  key: ValueKey('goal-today-row-${resource.stableKey}'),
  constraints: const BoxConstraints(minHeight: 56),
  child: Row(
    children: [
      Icon(_resourceIcon(resource.kind), size: 20),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: InkWell(
          onTap: busy ? null : onOpen,
          child: Text(resource.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      TextButton(
        onPressed: busy ? null : (onComplete ?? onOpen),
        child: Text(_primaryLabel(item)),
      ),
      PopupMenuButton<_ResourceMenuAction>(
        key: ValueKey('goal-today-more-${resource.stableKey}'),
        tooltip: 'More actions',
        onSelected: (_) => onOpen(),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _ResourceMenuAction.details,
            child: Text('Details'),
          ),
        ],
      ),
    ],
  ),
)
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test --no-pub test/features/goals/goal_today_sections_test.dart`

Expected: all Goal Today section tests pass, including 200 percent text scaling.

### Task 2: Collapse completed Today items

**Files:**
- Create: `apps/soulbuddy/lib/features/today/presentation/completed_today_item.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goal_today_sections.dart`
- Modify: `apps/soulbuddy/test/features/goals/goal_today_sections_test.dart`
- Create: `apps/soulbuddy/test/features/today/completed_today_item_test.dart`

- [ ] **Step 1: Write failing completion-row tests**

Test that a successful action callback replaces the expanded row with a keyed 48px confirmation and that dismiss removes it. Test that a callback exception preserves the expanded row.

```dart
testWidgets('successful completion collapses into a dismissible row', (
  tester,
) async {
  await tester.pumpWidget(_host(onComplete: () async {}));
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();

  final confirmation = find.byKey(const Key('completed-today-action-1'));
  expect(confirmation, findsOneWidget);
  expect(tester.getSize(confirmation).height, 48);
  await tester.drag(confirmation, const Offset(500, 0));
  await tester.pumpAndSettle();
  expect(confirmation, findsNothing);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test --no-pub test/features/today/completed_today_item_test.dart test/features/goals/goal_today_sections_test.dart`

Expected: FAIL because `CompletedTodayItem` and collapsed state are missing.

- [ ] **Step 3: Implement presentation-only completion state**

Create `CompletedTodayItem` with `Dismissible`, a 48px `SizedBox`, check icon, one-line label, completion time, and close button. In `GoalTodaySections`, retain successful completions in `_completedItems`, render them before remaining active items, and clear them when `snapshot.localDate` changes.

```dart
class CompletedTodayItem extends StatelessWidget {
  const CompletedTodayItem({
    required this.id,
    required this.label,
    required this.completedAt,
    required this.onDismiss,
    super.key,
  });

  final String id;
  final String label;
  final DateTime completedAt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('completed-today-$id'),
    onDismissed: (_) => onDismiss(),
    child: SizedBox(
      height: 48,
      child: Row(children: [
        const Icon(Icons.check_circle, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(completedAt),
        )),
        IconButton(
          tooltip: 'Dismiss completed item',
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 18),
        ),
      ]),
    ),
  );
}
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test --no-pub test/features/today/completed_today_item_test.dart test/features/goals/goal_today_sections_test.dart`

Expected: all tests pass and completion failures leave original rows visible.

### Task 3: Reflection sound picker and motivational tracks

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/domain/meditation_session.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/meditation_sound_picker.dart`
- Modify: `apps/soulbuddy/lib/features/formation/presentation/formation_reading_screen.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/meditation_screen.dart`
- Modify: `apps/soulbuddy/scripts/generate_meditation_soundscapes.py`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Create: `apps/soulbuddy/assets/audio/meditation/hopeful_piano.mp3`
- Create: `apps/soulbuddy/assets/audio/meditation/cinematic_rise.mp3`
- Create: `apps/soulbuddy/assets/audio/meditation/steady_resolve.mp3`
- Create: `apps/soulbuddy/assets/audio/meditation/warm_strings.mp3`
- Create: `apps/soulbuddy/assets/audio/meditation/victorious_calm.mp3`
- Modify: `apps/soulbuddy/test/features/prayers/meditation_session_test.dart`
- Create: `apps/soulbuddy/test/features/prayers/meditation_sound_picker_test.dart`
- Modify: `apps/soulbuddy/test/features/formation/formation_reading_screen_test.dart`

- [ ] **Step 1: Write failing model and placement tests**

Verify five motivational beds expose category metadata and preferred volume. Verify the reading screen places `meditation-sound-picker` after `formation-reading-body` and before `formation-reflection-field`.

```dart
expect(
  MeditationSoundBed.values
      .where((sound) => sound.category == MeditationSoundCategory.motivational),
  hasLength(5),
);
expect(MeditationSoundBed.cinematicRise.preferredVolume, lessThanOrEqualTo(.22));
expect(
  tester.getTopLeft(find.byKey(const Key('meditation-sound-picker'))).dy,
  greaterThan(tester.getBottomLeft(find.byKey(const Key('formation-reading-body'))).dy),
);
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test --no-pub test/features/prayers/meditation_session_test.dart test/features/prayers/meditation_sound_picker_test.dart test/features/formation/formation_reading_screen_test.dart`

Expected: FAIL because categories, tracks, picker, and placement are absent.

- [ ] **Step 3: Extend the sound model**

Add `MeditationSoundCategory { quiet, motivational }`, `preferredVolume`, and five motivational enum cases. Keep existing asset paths stable.

```dart
hopefulPiano(
  label: 'Hopeful piano',
  assetPath: 'audio/meditation/hopeful_piano.mp3',
  category: MeditationSoundCategory.motivational,
  preferredVolume: .18,
),
cinematicRise(
  label: 'Cinematic rise',
  assetPath: 'audio/meditation/cinematic_rise.mp3',
  category: MeditationSoundCategory.motivational,
  preferredVolume: .20,
),
steadyResolve(
  label: 'Steady resolve',
  assetPath: 'audio/meditation/steady_resolve.mp3',
  category: MeditationSoundCategory.motivational,
  preferredVolume: .18,
),
warmStrings(
  label: 'Warm strings',
  assetPath: 'audio/meditation/warm_strings.mp3',
  category: MeditationSoundCategory.motivational,
  preferredVolume: .16,
),
victoriousCalm(
  label: 'Victorious calm',
  assetPath: 'audio/meditation/victorious_calm.mp3',
  category: MeditationSoundCategory.motivational,
  preferredVolume: .18,
),
```

- [ ] **Step 4: Implement the compact picker**

Create `MeditationSoundPicker` with one `ListTile` and a modal sheet. Group options by category, preview through `MeditationSoundBedPlayer`, persist the selected value in the reading state, and stop preview on sheet disposal.

- [ ] **Step 5: Generate and register the tracks**

Extend `generate_meditation_soundscapes.py` with deterministic instrumental synthesis for the five new filenames, run `python scripts/generate_meditation_soundscapes.py`, and ensure `assets/audio/meditation/` remains declared in `pubspec.yaml`.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run: `flutter test --no-pub test/features/prayers/meditation_session_test.dart test/features/prayers/meditation_sound_picker_test.dart test/features/formation/formation_reading_screen_test.dart`

Expected: all sound model, picker preview, and placement tests pass.

### Task 4: Root-scoped spiritual session controller and mini-player

**Files:**
- Create: `apps/soulbuddy/lib/core/playback/spiritual_session.dart`
- Create: `apps/soulbuddy/lib/core/playback/spiritual_session_controller.dart`
- Create: `apps/soulbuddy/lib/core/playback/spiritual_session_providers.dart`
- Create: `apps/soulbuddy/lib/core/playback/spiritual_session_mini_player.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Create: `apps/soulbuddy/test/core/playback/spiritual_session_controller_test.dart`
- Create: `apps/soulbuddy/test/core/playback/spiritual_session_mini_player_test.dart`

- [ ] **Step 1: Write failing controller tests**

Test begin, replacement, pause, resume, complete, close, and error. Use real callback closures so each public command is observable.

```dart
final events = <String>[];
final controller = SpiritualSessionController();
await controller.begin(_session(
  id: 'memory-1',
  onPause: () async => events.add('pause'),
  onResume: () async => events.add('resume'),
  onComplete: () async => events.add('complete'),
  onClose: () async => events.add('close'),
));
await controller.pause();
await controller.resume();
await controller.complete();
expect(events, ['pause', 'resume', 'complete']);
expect(controller.state.status, SpiritualSessionStatus.idle);
```

- [ ] **Step 2: Run controller tests and verify RED**

Run: `flutter test --no-pub test/core/playback/spiritual_session_controller_test.dart`

Expected: FAIL because the playback package does not exist.

- [ ] **Step 3: Implement the session boundary**

Define `SpiritualSessionKind`, `SpiritualSessionStatus`, immutable `SpiritualSession`, and `SpiritualSessionState`. Implement serialized controller commands. `begin` closes the current session before replacing it. Errors retain metadata and expose `retry` through the prior resume callback.

```dart
class SpiritualSession {
  const SpiritualSession({
    required this.id,
    required this.kind,
    required this.title,
    required this.route,
    required this.canPause,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onClose,
  });

  final String id;
  final SpiritualSessionKind kind;
  final String title;
  final String route;
  final bool canPause;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onComplete;
  final Future<void> Function() onClose;
}
```

- [ ] **Step 4: Write failing mini-player tests**

Override the controller provider, begin a session, verify the mini-player appears, navigate to another route, and verify it remains. Assert Pause changes to Resume and Complete clears the player.

- [ ] **Step 5: Implement and mount the mini-player**

Build a 64px card with semantic title, progress indicator, pause/resume, open, and complete/close. Mount it in `SoulBuddyApp.builder` above the existing reminder overlays and route opening through `appRouter.go(session.route)`.

- [ ] **Step 6: Run playback tests and verify GREEN**

Run: `flutter test --no-pub test/core/playback/spiritual_session_controller_test.dart test/core/playback/spiritual_session_mini_player_test.dart test/app/app_navigation_test.dart`

Expected: all session and navigation tests pass.

### Task 5: Connect memory, prayer, Altar, person, and Sacred Hour sessions

**Files:**
- Modify: `apps/soulbuddy/lib/features/record/audio/presentation/audio_playback_control.dart`
- Modify: `apps/soulbuddy/lib/features/remember/presentation/memory_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/features/altar/presentation/altar_today_card.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_sheet.dart`
- Modify: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_active_overlay.dart`
- Modify: `apps/soulbuddy/lib/features/persons/presentation/person_detail_screen.dart`
- Modify: `apps/soulbuddy/test/features/remember/memory_audio_playback_control_test.dart`
- Modify: `apps/soulbuddy/test/features/altar/altar_memory_today_card_test.dart`
- Modify: `apps/soulbuddy/test/features/prayers/voice_tablet_flow_test.dart`
- Modify: `apps/soulbuddy/test/features/sacred_hours/sacred_hours_settings_test.dart`

- [ ] **Step 1: Write failing integration tests**

For each source, start its playback and assert `SpiritualSessionController.state.session.kind` matches memory, altar, prayer, person, or Sacred Hour. Verify pause/resume delegates to the current audio controller. Verify sessions without audio set `canPause: false` while still exposing Open and Complete.

- [ ] **Step 2: Run integration tests and verify RED**

Run: `flutter test --no-pub test/features/remember/memory_audio_playback_control_test.dart test/features/altar/altar_memory_today_card_test.dart test/features/prayers/voice_tablet_flow_test.dart test/features/sacred_hours/sacred_hours_settings_test.dart`

Expected: FAIL because feature players do not register root sessions.

- [ ] **Step 3: Register and synchronize sessions**

When each existing player enters playing state, call `SpiritualSessionController.begin` with stable metadata and callbacks to that existing player. Forward player position and duration changes to `updateProgress`. On natural completion, call `finishPlayback`; on repository completion, call `complete`.

```dart
await sessionController.begin(
  SpiritualSession(
    id: 'memory:${widget.audio.id}',
    kind: isAltar ? SpiritualSessionKind.altar : SpiritualSessionKind.memory,
    title: widget.label,
    route: '/remember/${widget.audio.encounterId}',
    canPause: true,
    onPause: coordinator.pause,
    onResume: () => coordinator.play(widget.audio),
    onComplete: coordinator.stop,
    onClose: coordinator.stop,
  ),
);
```

- [ ] **Step 4: Add context-specific completion callbacks**

Prayer and person sessions invoke their existing `PrayerReminderAction.prayed`; Sacred Hour invokes Begin/Complete through its occurrence handler; memory Close stops playback; Altar Complete records the existing ritual completion before stopping.

- [ ] **Step 5: Run integration tests and verify GREEN**

Run the same command from Step 2 with the corrected voice tablet test path.

Expected: all integrations register one shared session and delegate controls correctly.

### Task 6: Ongoing Android session notification controls

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/core/playback/spiritual_session_controller.dart`
- Modify: `apps/soulbuddy/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/soulbuddy/test/features/prayers/native_prayer_reminder_scheduler_test.dart`
- Modify: `apps/soulbuddy/test/core/playback/spiritual_session_controller_test.dart`

- [ ] **Step 1: Write failing notification action tests**

Verify an active playable session emits an ongoing notification with Pause, Open, and Complete; paused emits Resume; a non-playable session omits Pause/Resume. Decode PAUSE_SESSION, RESUME_SESSION, OPEN_SESSION, and COMPLETE_SESSION responses.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test --no-pub test/features/prayers/native_prayer_reminder_scheduler_test.dart test/core/playback/spiritual_session_controller_test.dart`

Expected: FAIL because active-session notification methods and actions are missing.

- [ ] **Step 3: Add active-session notification API**

Extend the scheduler with `showActiveSession`, `cancelActiveSession`, and session responses. Use a dedicated high-importance `spiritual_session_player_v1` channel, ongoing notification, media category, and action buttons. Route responses through the root controller queue so cold-start actions wait for initialization.

- [ ] **Step 4: Run tests and verify GREEN**

Run the command from Step 2.

Expected: notification action tests and controller queue tests pass.

### Task 7: Verification, release build, device installation, and cleanup

**Files:**
- Modify if needed: `apps/soulbuddy/android/app/src/main/res/raw/keep.xml`
- Output: `.artifacts/orientation/soulbuddy-latest-android.apk`

- [ ] **Step 1: Format and analyze**

Run: `dart format lib test && dart analyze lib test`

Expected: formatting completes and analysis reports `No issues found!`.

- [ ] **Step 2: Run the focused suite**

Run: `flutter test --no-pub test/core/playback test/features/goals/goal_today_sections_test.dart test/features/today/completed_today_item_test.dart test/features/prayers/meditation_session_test.dart test/features/prayers/meditation_sound_picker_test.dart test/features/formation/formation_reading_screen_test.dart test/features/remember/memory_audio_playback_control_test.dart test/features/altar/altar_memory_today_card_test.dart test/features/prayers/voice_tablet_flow_test.dart test/features/prayers/native_prayer_reminder_scheduler_test.dart test/features/sacred_hours`

Expected: all focused tests pass.

- [ ] **Step 3: Run the full suite once**

Run: `flutter test --no-pub`

Expected: all tests pass.

- [ ] **Step 4: Build and inspect release resources**

Run: `flutter build apk --release`, then use Android `aapt2 dump resources` to verify every dynamically named Sacred Hour and session sound exists in the release table.

- [ ] **Step 5: Install and verify the connected Android device**

Install with the SDK platform-tools `adb install -r`, grant notification and exact-alarm access, cold-start the app, and inspect `dumpsys alarm` for all configured Sacred Hour and person reminders. Manually open a memory and verify the persistent player survives navigation and Pause/Resume works.

- [ ] **Step 6: Preserve the APK and reclaim generated disk usage**

Copy the release APK to `.artifacts/orientation/soulbuddy-latest-android.apk`, compute SHA-256, then run `flutter clean`. Report the final free space and installed package state.
