# Private Audio Memories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a person speak, review, save, replay, remember, and explicitly delete one private local-first audio recording with any SoulBuddy memory without being forced to type.

**Architecture:** The `record` plugin sits behind a serialized recorder gateway; durable bytes sit behind platform-specific asset stores—app-private files on IO and IndexedDB on web. A local-only PowerSync metadata table relates one asset to an owned memory and immutable source revision, while the existing encounter repository coordinates durable asset import with the database transaction and orphan recovery.

**Tech Stack:** Flutter 3 / Dart 3, Riverpod, PowerSync SQLite local-only tables, `record` 7.1.1, existing `audioplayers` 6.7.1, `idb_shim` 2.9.6+2, `path_provider`, `package:web`, Android/iOS microphone APIs, Chrome integration tests.

---

## File map

**Create**

- `apps/soulbuddy/lib/features/record/audio/domain/memory_audio.dart` — metadata and capture value types.
- `apps/soulbuddy/lib/features/record/audio/application/audio_recorder.dart` — recorder interface and state.
- `apps/soulbuddy/lib/features/record/audio/application/record_plugin_audio_recorder.dart` — serialized plugin adapter.
- `apps/soulbuddy/lib/features/record/audio/application/audio_capture_controller.dart` — permission, timer, amplitude, interruption, and review state machine.
- `apps/soulbuddy/lib/features/record/audio/data/audio_asset_store.dart` — temporary/durable storage contract.
- `apps/soulbuddy/lib/features/record/audio/data/audio_asset_store_factory.dart` — conditional export.
- `apps/soulbuddy/lib/features/record/audio/data/audio_asset_store_io.dart` — private filesystem implementation.
- `apps/soulbuddy/lib/features/record/audio/data/audio_asset_store_web.dart` — IndexedDB implementation.
- `apps/soulbuddy/lib/features/record/audio/data/memory_audio_repository.dart` — metadata contract.
- `apps/soulbuddy/lib/features/record/audio/data/powersync_memory_audio_repository.dart` — owned local metadata and cleanup.
- `apps/soulbuddy/lib/features/record/audio/application/memory_audio_player.dart` — one-active-player abstraction.
- `apps/soulbuddy/lib/features/record/audio/application/audioplayers_memory_audio_player.dart` — player adapter.
- `apps/soulbuddy/lib/features/record/audio/providers/memory_audio_providers.dart` — production wiring.
- `apps/soulbuddy/lib/features/record/audio/presentation/audio_capture_panel.dart` — recording/review UI.
- `apps/soulbuddy/lib/features/record/audio/presentation/audio_playback_control.dart` — reusable playback UI.
- Focused unit, repository, widget, and integration tests matching each layer.

**Modify**

- `apps/soulbuddy/pubspec.yaml` and platform permission files.
- `apps/soulbuddy/lib/core/database/app_schema.dart` — local-only `memory_audio_assets`.
- `apps/soulbuddy/lib/features/record/data/encounter_repository.dart` and `powersync_encounter_repository.dart` — optional audio commit with memory.
- `apps/soulbuddy/lib/features/record/domain/encounter_draft.dart` — optional audio draft.
- `apps/soulbuddy/lib/features/record/presentation/record_screen.dart` and `encounter_form.dart` — real Speak flow.
- `apps/soulbuddy/lib/features/remember/presentation/encounter_list_tile.dart`, `memory_detail_screen.dart`, `daily_remembrance_card.dart`, and `daily_remembrance_screen.dart` — playback and deletion.
- `apps/soulbuddy/integration_test/offline_encounter_flow_test.dart` and `scripts/run_web_integration.ps1` — persistence boundary.

### Task 1: Define the audio domain and local metadata contract

**Files:** audio domain, schema, repository interface, and real database tests.

- [ ] **Step 1: Write the failing real-database test**

Add `test/features/record/memory_audio_repository_test.dart`:

```dart
final saved = await repository.attach(
  const MemoryAudioDraft(
    temporaryKey: 'take-1',
    mimeType: 'audio/mp4',
    duration: Duration(seconds: 12),
    waveform: [0.1, 0.4, 0.8, 0.3],
  ),
  encounterId: encounter.id,
  revisionId: encounter.currentRevisionId,
  durableKey: 'owner/asset.m4a',
  byteSize: 2048,
);
expect(await repository.watchForEncounter(encounter.id).first, saved);
expect(await database.getCrudBatch(), isNull);
```

Add ownership rejection, nonexistent/mismatched revision rejection, one-audio-per-memory uniqueness, archive preservation, explicit metadata deletion, malformed MIME/duration/waveform rejection, and no PowerSync CRUD upload.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/record/memory_audio_repository_test.dart
```

Expected: missing domain/repository/schema types.

- [ ] **Step 3: Add the local-only table and domain types**

Add to `app_schema.dart`:

```dart
Table.localOnly(
  'memory_audio_assets',
  [
    Column.text('owner_id'),
    Column.text('encounter_id'),
    Column.text('encounter_revision_id'),
    Column.text('storage_key'),
    Column.text('mime_type'),
    Column.integer('duration_ms'),
    Column.integer('byte_size'),
    Column.text('waveform_json'),
    Column.text('created_at'),
  ],
  indexes: [
    Index('memory_audio_owner_encounter', [
      IndexedColumn('owner_id'),
      IndexedColumn('encounter_id'),
    ]),
  ],
),
```

Define:

```dart
class MemoryAudioDraft {
  const MemoryAudioDraft({
    required this.temporaryKey,
    required this.mimeType,
    required this.duration,
    required this.waveform,
  });
  final String temporaryKey;
  final String mimeType;
  final Duration duration;
  final List<double> waveform;
}

class MemoryAudio {
  const MemoryAudio({required this.id, required this.encounterId,
    required this.revisionId, required this.storageKey,
    required this.mimeType, required this.duration,
    required this.byteSize, required this.waveform, required this.createdAt});
  final String id;
  final String encounterId;
  final String revisionId;
  final String storageKey;
  final String mimeType;
  final Duration duration;
  final int byteSize;
  final List<double> waveform;
  final DateTime createdAt;
}
```

Validation: duration `1 ms..15 minutes`, byte size `1..64 MiB`, MIME starts `audio/`, waveform has `1..96` finite values clamped to `0..1`, and every query includes `owner_id`.

- [ ] **Step 4: Implement the PowerSync repository**

`attach` first verifies an active owned encounter and its `current_revision_id`, then inserts a UUIDv7 row. Refuse replacement when a row already exists; the capture UI re-records only before save. `deleteMetadata` returns the storage key after deleting the exact owned row so the caller can remove durable bytes.

- [ ] **Step 5: Run focused GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/record/audio lib/core/database/app_schema.dart test/features/record/memory_audio_repository_test.dart
flutter test test/features/record/memory_audio_repository_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/record/audio apps/soulbuddy/test/features/record/memory_audio_repository_test.dart
git commit -m "feat: model private memory audio"
```

### Task 2: Implement durable private asset stores

**Files:** storage abstractions and unit tests.

- [ ] **Step 1: Write storage contract tests**

Use a shared contract over fake filesystem/IndexedDB factories:

```dart
final committed = await store.commitTemporary(
  const TemporaryAudio(key: 'tmp/take', locator: 'tmp/take.m4a'),
  assetId: 'asset-1',
  mimeType: 'audio/mp4',
);
expect(committed.storageKey, 'audio/asset-1.m4a');
expect(await store.open(committed.storageKey), isNotNull);
await store.delete(committed.storageKey);
expect(await store.open(committed.storageKey), isNull);
```

Test failed import leaves the temporary take; successful import removes it; duplicate IDs do not overwrite different bytes; invalid keys cannot escape the app directory; cleanup removes unreferenced durable/temporary assets older than 24 hours and keeps referenced assets.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/record/audio_asset_store_test.dart
```

- [ ] **Step 3: Implement IO storage**

Use `getApplicationSupportDirectory()/soulbuddy/audio` for durable files and `getTemporaryDirectory()/soulbuddy/audio` for takes. Resolve canonical absolute paths and reject any result outside those exact roots. Copy to `$assetId.partial`, flush, rename to `$assetId.m4a` (or the actual codec extension), then remove the temporary source. Return a path-backed playback source.

- [ ] **Step 4: Implement web storage**

Use `idb_shim` 2.9.6+2 database `soulbuddy-audio`, version 1, object store `assets`. Persist a map containing `mimeType`, `bytes` (`Uint8List`), and `createdAt`. When the `record` plugin returns a blob URL, use `package:web` `window.fetch`, validate `Response.ok`, read `arrayBuffer`, store bytes in one read-write transaction, await `transaction.completed`, then revoke the object URL. Return a bytes-backed playback source. Never store the blob URL as the durable key.

- [ ] **Step 5: Run storage GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/record/audio/data test/features/record/audio_asset_store_test.dart
flutter test test/features/record/audio_asset_store_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/pubspec.yaml apps/soulbuddy/lib/features/record/audio/data apps/soulbuddy/test/features/record/audio_asset_store_test.dart
git commit -m "feat: persist private audio across platforms"
```

### Task 3: Wrap the recorder plugin in a deterministic state machine

**Files:** recorder abstraction, adapter, capture controller, tests, platform permission files.

- [ ] **Step 1: Write controller RED tests with a fake recorder**

Cover this transition table:

```text
idle -> explaining -> requestingPermission -> recording
recording -> paused -> recording
recording|paused -> stopping -> review
recording|paused -> cancelling -> idle
recording -> interrupted -> paused|review
recording -> limitReached -> stopping -> review
review -> discard -> idle
review -> recordAgain -> recording
any command in flight -> same control disabled
```

Assert permission denial returns `AudioCaptureFailure.permissionDenied` with `Write instead`; start is explicit; rapid double taps call the plugin once; elapsed time uses a monotonic `Stopwatch`; amplitude samples are finite/clamped; 15 minutes auto-stops once; dispose cancels subscriptions and disposes the plugin after stopping/cancelling safely.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/record/audio_capture_controller_test.dart
```

- [ ] **Step 3: Add dependencies and permissions**

Pin:

```yaml
record: 7.1.1
idb_shim: 2.9.6+2
```

Keep existing `path_provider` and `audioplayers`. Add Android:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Add iOS:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>SoulBuddy uses the microphone only when you choose to record a private memory.</string>
```

- [ ] **Step 4: Implement the serialized adapter**

Use one `AudioRecorder` instance and an internal command future/mutex so `start`, `pause`, `resume`, `stop`, `cancel`, and `dispose` never overlap. Probe encoders before start:

- IO: AAC-LC, mono, 44.1 kHz, 64 kbps, `.m4a`.
- Web: Opus when supported, then AAC-LC, then WAV; `path: ''` because web ignores it. Configure the WAV fallback as mono 24 kHz PCM16 so a full 15-minute take remains under the 64 MiB asset limit.

Capture `setOnConfigChanged` so MIME metadata follows the actual encoder. Subscribe to `onAmplitudeChanged(const Duration(milliseconds: 120))`; convert dBFS to normalized `pow(10, db / 20)` and clamp to `0..1`.

- [ ] **Step 5: Implement the controller**

Keep only the last 180 live samples for display. At stop, downsample the complete sample stream into at most 64 peak buckets for metadata. The controller exposes immutable `AudioCaptureState` values; UI never queries the plugin directly. Use `AppLifecycleListener` to pause on inactive/paused when supported and otherwise stop into review; show `Recording paused when SoulBuddy left the foreground` on return.

- [ ] **Step 6: Run GREEN and manifest tests**

```powershell
cd apps/soulbuddy
dart format lib/features/record/audio/application test/features/record/audio_capture_controller_test.dart
flutter test test/features/record/audio_capture_controller_test.dart test/core/security/android_manifest_test.dart
```

- [ ] **Step 7: Commit**

```powershell
git add apps/soulbuddy/pubspec.yaml apps/soulbuddy/pubspec.lock apps/soulbuddy/android/app/src/main/AndroidManifest.xml apps/soulbuddy/ios/Runner/Info.plist apps/soulbuddy/lib/features/record/audio/application apps/soulbuddy/test/features/record/audio_capture_controller_test.dart apps/soulbuddy/test/core/security/android_manifest_test.dart
git commit -m "feat: capture private voice memories"
```

### Task 4: Commit memory and audio without partial user-visible saves

**Files:** encounter draft/repository/providers and repository tests.

- [ ] **Step 1: Add transactional RED tests**

Extend `encounter_repository_test.dart`:

```dart
final memory = await repository.create(
  EncounterDraft(
    title: 'Voice memory · 13 Aug',
    body: '',
    occurredOn: '2026-08-13',
    isAltar: false,
    audio: const MemoryAudioDraft(
      temporaryKey: 'tmp/take-1.m4a',
      mimeType: 'audio/mp4',
      duration: Duration(seconds: 7),
      waveform: [0.12, 0.48, 0.83, 0.31],
    ),
  ),
);
expect(await audioRepository.watchForEncounter(memory.id).first, isNotNull);
expect(await database.getCrudBatch(), isNotNull); // encounter/revision only
```

Add failures: durable import fails—no memory row; database transaction fails—durable asset is deleted; crash-style unreferenced asset is removed by startup cleanup; metadata has exact current revision; audio-only default title is accepted; text-only behavior is unchanged.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/record/encounter_repository_test.dart
```

- [ ] **Step 3: Extend `EncounterDraft` and repository creation**

Add `MemoryAudioDraft? audio`. In `PowerSyncEncounterRepository.create`:

1. Validate the draft and generate encounter/revision/audio UUIDs.
2. Commit the temporary asset to its final private location.
3. In one PowerSync write transaction, insert encounter, immutable revision, and local-only audio metadata.
4. On transaction failure, delete the newly committed durable asset and rethrow a generic domain failure.
5. After successful commit, request persistent browser storage as the current flow already does.

Do not put bytes, filenames, MIME, waveform, or storage keys in `encounters` or `encounter_revisions`; only the local metadata table holds them.

- [ ] **Step 4: Wire startup orphan cleanup**

After AppDatabase and identity initialize, read all owned `storage_key`s, then call `AudioAssetStore.cleanup(referencedKeys, olderThan: now - 24h)`. Failure is nonfatal, privacy-safe, and retried on the next startup; it is never logged with storage keys.

- [ ] **Step 5: Run GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/record test/features/record/encounter_repository_test.dart
flutter test test/features/record/encounter_repository_test.dart test/features/record/memory_audio_repository_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib/features/record apps/soulbuddy/test/features/record
git commit -m "feat: save voice and memory as one action"
```

### Task 5: Deliver Speak and Write as equal Record paths

**Files:** Record UI, providers, widgets, and tests.

- [ ] **Step 1: Write UI RED tests**

Assert the initial Record screen contains:

```dart
expect(find.text('Keep what you do not want to forget.'), findsOneWidget);
expect(find.byKey(const Key('record-speak')), findsOneWidget);
expect(find.byKey(const Key('record-write')), findsOneWidget);
```

Drive fake controller states through explain, permission denial, recording, pause, resume, stop/review, seek/play, record again, discard confirmation, memory-type chips, default title, sensitive default for Left Behind, save busy/error/retry, and saved confirmation. Verify 48 px targets, 200% text, reduced motion, no amplitude semantics, and no title required before speaking.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/record/audio_capture_panel_test.dart test/features/record/record_remember_flow_test.dart
```

- [ ] **Step 3: Build the capture panel**

Use these state-specific controls:

- Explain: `Start recording`, `Write instead`.
- Recording: elapsed time, real level line, `Pause`, `Stop`, `Discard`.
- Paused: elapsed time, `Resume`, `Stop`, `Discard`.
- Review: `Play/Pause`, seek, duration, `Record again`, `Discard`, `Continue`.

Screen-reader labels: `Start audio recording`, `Pause recording`, `Resume recording`, `Stop and review recording`, `Discard this recording`. Announce elapsed time only at minute boundaries and on pause/stop, never every second.

- [ ] **Step 4: Build the post-record form**

Reuse the existing encounter fields after review. Pre-fill `Voice memory · d MMM` when title is empty; keep it editable. Permit empty body when audio exists. Save is disabled while the asset is being committed. On failure keep the take in review and show `The recording is still here. Try saving again or discard it.`

Assert there is no disabled, future-facing, or preparation-only Speak control in the combined implementation.

- [ ] **Step 5: Run UI GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/record/audio/presentation lib/features/record/presentation test/features/record
flutter test test/features/record/audio_capture_panel_test.dart test/features/record/record_remember_flow_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib/features/record apps/soulbuddy/test/features/record
git commit -m "feat: make speaking a first-class Record path"
```

### Task 6: Add private playback, daily listening, and explicit deletion

**Files:** player, Remember UI, providers, and tests.

- [ ] **Step 1: Write player and Remember RED tests**

Test one-active-player behavior:

```dart
await coordinator.play(audioA);
await coordinator.play(audioB);
verify(() => playerA.stop()).called(1);
expect(coordinator.state.assetId, audioB.id);
```

Widget coverage must show Play and duration on non-sensitive list items, hide titles/excerpts but retain a generic `Audio memory` control treatment for sensitive items, provide playback/seek on detail, show `Listen` in daily remembrance, stop on route disposal, and require explicit confirmation containing `This audio cannot be recovered from SoulBuddy` before deletion.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/remember/memory_audio_playback_test.dart test/features/remember/daily_remembrance_card_test.dart
```

- [ ] **Step 3: Implement the player adapter**

Use one `AudioPlayer` per coordinator and `DeviceFileSource` for IO or `BytesSource` for web. Expose position, duration, playing, paused, completed, and recoverable error. Stop/release on provider disposal. Prayer narration remains a separate provider and never receives a user recording.

- [ ] **Step 4: Implement playback and deletion UI**

List playback is compact and does not auto-play. Detail playback includes 48 px play/pause/stop, accessible position/duration, seek slider, and `Audio saved on this device`. Daily remembrance adds `Listen` before `Remembered` when audio exists.

Delete order: remove owned metadata transactionally, then delete the returned durable key. If byte deletion fails, enqueue it for orphan cleanup and still never expose the key. Do not archive or rewrite the memory.

- [ ] **Step 5: Run GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/record/audio/application lib/features/record/audio/presentation lib/features/remember test/features/remember
flutter test test/features/remember/memory_audio_playback_test.dart test/features/remember/daily_remembrance_card_test.dart test/features/record/memory_audio_repository_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib/features/record/audio apps/soulbuddy/lib/features/remember apps/soulbuddy/test/features/remember
git commit -m "feat: replay private memories in Remember"
```

### Task 7: Verify browser, emulator, and connected-device persistence

**Files:** integration test, runner, docs, and generated-output hygiene.

- [ ] **Step 1: Extend the Chrome runner for fake microphone input**

Add `integration_test/offline_audio_memory_flow_test.dart` to the target list and pass:

```powershell
--web-browser-flag=--use-fake-device-for-media-stream
--web-browser-flag=--use-fake-ui-for-media-stream
```

The test must record at least one second, stop, save an audio-only Encounter, assert local metadata and IndexedDB bytes, play, dispose the first ProviderContainer/AppDatabase, await close, create a fresh container/database on the same paths, assert the same memory/audio ID, and play again.

- [ ] **Step 2: Run focused Chrome RED then GREEN**

```powershell
cd apps/soulbuddy
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/offline_audio_memory_flow_test.dart --headless --browser-dimension=390x844 --web-browser-flag=--use-fake-device-for-media-stream --web-browser-flag=--use-fake-ui-for-media-stream
```

Expected after implementation: `All tests passed`, with no retry loop.

- [ ] **Step 3: Run full automated verification**

```powershell
scripts/verify.ps1
scripts/run_web_integration.ps1
cd apps/soulbuddy
flutter build apk --debug
```

Expected: all Flutter/Laravel suites, analysis, audit, web build, every Chrome target, and APK build pass.

- [ ] **Step 4: Test Android emulator and physical device**

On both targets:

1. Deny microphone permission and confirm Write remains usable.
2. Grant permission, record audible speech, observe real level movement, pause/resume, stop, seek, and replay.
3. Save an audio-only promise; reopen SoulBuddy without clearing data; play it in Remember and daily remembrance.
4. Background during capture; confirm paused/review state is truthful.
5. Start another take and cancel; confirm no saved memory or orphan asset.
6. Delete saved audio through confirmation; confirm the written memory remains and playback is gone.
7. Verify TalkBack focus order, 200% text, dark theme, reduced motion, and one-active-playback behavior.

- [ ] **Step 5: Update local-first architecture documentation**

Document that synchronized memory text can cross devices while user-recorded audio in this slice is device-local and never uploaded. Describe IndexedDB/app-private file storage, explicit deletion, orphan cleanup, and the absence of AI/TTS processing.

- [ ] **Step 6: Commit final integration**

```powershell
git add apps/soulbuddy/integration_test apps/soulbuddy/lib apps/soulbuddy/test apps/soulbuddy/pubspec.yaml apps/soulbuddy/pubspec.lock apps/soulbuddy/android apps/soulbuddy/ios scripts docs/architecture/local-first.md
git diff --cached --check
git commit -m "feat: deliver offline audio memories"
```

## Plan completion gate

The slice is incomplete unless real audio is recorded and replayed on an Android emulator and the connected physical device, Chrome proves durable reopen, permission denial leaves Write usable, no user audio reaches Laravel/AI/logging, and no disabled or future-facing Speak control exists.
