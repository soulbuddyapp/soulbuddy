# Guided First Prayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry a new SoulBuddy user from the welcome scenes through a personally prepared prayer, its practice, and an optional spoken or written remembrance, then land on Today with the work already visible.

**Architecture:** Add a small local-first guided-flow domain and Riverpod controller beside onboarding, while reusing the existing prayer-generation, prayer-library, personal-prayer, practice, audio-capture, and encounter repositories. Extend prayer generation with an explicit language preference and rank prepared prayers with explicit content-style metadata, so the four onboarding answers influence both generation and fallback ordering without hiding content. Keep the guide outside the main shell and make every persistence or network failure escapable.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, PowerSync SQLite, Laravel, MariaDB, PHPUnit, Flutter widget/unit tests.

---

### Task 1: Guided-choice domain and mappings

**Files:**
- Create: `apps/soulbuddy/lib/features/onboarding/domain/first_prayer_choices.dart`
- Test: `apps/soulbuddy/test/features/onboarding/first_prayer_choices_test.dart`

- [ ] **Step 1: Write the failing mapping tests**

```dart
test('Jesus ranks direct Gospel content before Christian and Catholic', () {
  expect(
    PrayerLanguagePreference.jesus.rankOrder,
    [PrayerLanguageStyle.jesus, PrayerLanguageStyle.christian, PrayerLanguageStyle.catholic],
  );
});

test('guided choices map to the existing generation contract', () {
  final answers = FirstPrayerAnswers(
    purpose: FirstPrayerPurpose.guidance,
    frequency: FirstPrayerFrequency.once,
    audience: FirstPrayerAudience.family,
    language: PrayerLanguagePreference.catholic,
  );
  expect(answers.style, PrayerStyle.situational);
  expect(answers.reach, PrayerReach.encompassing);
  expect(answers.grounding, PrayerGrounding.catholic);
  expect(answers.prayerPurpose, PrayerPurpose.guidance);
  expect(answers.beneficiaryChoice, 'family');
});
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/features/onboarding/first_prayer_choices_test.dart`

Expected: compilation failure because the guided-choice types do not exist.

- [ ] **Step 3: Implement the minimal immutable choice model**

```dart
enum FirstPrayerPurpose { stayClose, guidance, family, healing, forgiveness, difficultTime }
enum FirstPrayerFrequency { daily, once }
enum FirstPrayerAudience { me, someone, family, others }
enum PrayerLanguageStyle { christian, catholic, jesus }
enum PrayerLanguagePreference { christian, catholic, jesus, all }

class FirstPrayerAnswers {
  const FirstPrayerAnswers({this.purpose, this.frequency, this.audience, this.language, this.detail});
  final FirstPrayerPurpose? purpose;
  final FirstPrayerFrequency? frequency;
  final FirstPrayerAudience? audience;
  final PrayerLanguagePreference? language;
  final String? detail;
  PrayerStyle get style => frequency == FirstPrayerFrequency.once ? PrayerStyle.situational : PrayerStyle.daily;
  PrayerGrounding get grounding => language == PrayerLanguagePreference.catholic ? PrayerGrounding.catholic : PrayerGrounding.generalChristian;
}
```

Implement exhaustive labels, purpose mappings, beneficiary defaults, request text, and ranking lists. `all` returns equal rank for all styles.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `flutter test test/features/onboarding/first_prayer_choices_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/onboarding/domain/first_prayer_choices.dart apps/soulbuddy/test/features/onboarding/first_prayer_choices_test.dart
git commit -m "feat: model guided first prayer choices"
```

### Task 2: Persist resumable first-use progress

**Files:**
- Create: `apps/soulbuddy/lib/features/onboarding/data/first_prayer_progress_repository.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/data/powersync_first_prayer_progress_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Test: `apps/soulbuddy/test/features/onboarding/first_prayer_progress_repository_test.dart`

- [ ] **Step 1: Write a failing round-trip test**

```dart
test('saves and restores guided answers and the current stage', () async {
  await repository.save(const FirstPrayerProgress(
    stage: FirstPrayerStage.language,
    answers: FirstPrayerAnswers(
      purpose: FirstPrayerPurpose.healing,
      frequency: FirstPrayerFrequency.daily,
      audience: FirstPrayerAudience.me,
    ),
  ));
  expect((await repository.load())?.stage, FirstPrayerStage.language);
  expect((await repository.load())?.answers.purpose, FirstPrayerPurpose.healing);
});
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/features/onboarding/first_prayer_progress_repository_test.dart`

Expected: compilation failure because the repository and local table do not exist.

- [ ] **Step 3: Add one local-only progress row and repository**

```dart
Table.localOnly('first_prayer_progress', [
  Column.text('stage'),
  Column.text('purpose'),
  Column.text('frequency'),
  Column.text('audience'),
  Column.text('language_preference'),
  Column.text('detail'),
  Column.text('request_id'),
  Column.text('selected_prayer_type'),
  Column.text('selected_prayer_id'),
  Column.text('updated_at'),
]),
```

Use a fixed row id (`current`) and upsert after every choice. `clear()` deletes only that row. Decode unknown enum values defensively and return `null` for a corrupt row so onboarding can restart.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `flutter test test/features/onboarding/first_prayer_progress_repository_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/onboarding/data apps/soulbuddy/test/features/onboarding/first_prayer_progress_repository_test.dart
git commit -m "feat: persist first prayer progress"
```

### Task 3: Carry language preference through prayer generation

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/domain/prayer_generation_request.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/prayer_generation_repository.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_generation_repository.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/laravel_prayer_draft_api.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/providers/personal_prayer_providers.dart`
- Modify: `services/api/app/Http/Requests/GeneratePrayerDraftRequest.php`
- Modify: `services/api/app/Domain/PrayerDrafts/PrayerDraftInput.php`
- Modify: `services/api/resources/prompts/prayer_draft_v1.md`
- Test: `apps/soulbuddy/test/features/prayers/prayer_generation_repository_test.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_generation_dispatcher_test.dart`
- Test: `services/api/tests/Feature/PrayerDraftGenerationTest.php`

- [ ] **Step 1: Write failing client and API contract tests**

```dart
expect(decodedBody['language_preference'], 'jesus');
expect(restored.languagePreference, PrayerLanguagePreference.jesus);
```

```php
$response = $this->postJson('/api/v1/prayer-drafts', [
    // existing valid fields
    'language_preference' => 'jesus',
]);
$response->assertOk();
$this->assertStringContainsString('direct, personal, Gospel-centered', $capturedPrompt);
```

- [ ] **Step 2: Run both focused suites and verify RED**

Run: `flutter test test/features/prayers/prayer_generation_repository_test.dart test/features/prayers/prayer_generation_dispatcher_test.dart`

Run: `php artisan test --filter=PrayerDraftGenerationTest`

Expected: missing field/assertion failures.

- [ ] **Step 3: Add the optional backward-compatible field**

Add `language_preference` to the local generation row, model, repository create method, and JSON payload. Advanced prayer creation passes a value derived from grounding. Laravel validates `christian,catholic,jesus,all`, defaults missing legacy requests from grounding, and gives the prompt an explicit content-language instruction without changing doctrine or output JSON shape.

```php
'language_preference' => ['sometimes', Rule::in(['christian', 'catholic', 'jesus', 'all'])],
```

- [ ] **Step 4: Run focused client and API tests and verify GREEN**

Run the two commands from Step 2.

Expected: all focused tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib services/api/app services/api/resources/prompts services/api/tests
git commit -m "feat: guide prayer language preference"
```

### Task 4: Rank prepared prayers explicitly and provide an offline fallback

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/domain/library_prayer.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/bundled_prayer_importer.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_repository.dart`
- Modify: `apps/soulbuddy/assets/content/prayers.json`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `services/api/database/migrations/2026_08_26_010000_add_language_style_to_library_prayers.php`
- Modify: `services/api/database/seeders/PrayerLibrarySeeder.php`
- Test: `apps/soulbuddy/test/features/prayers/bundled_prayer_importer_test.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_repository_test.dart`

- [ ] **Step 1: Write failing style-import and ordering tests**

```dart
test('Jesus preference ranks Jesus, Christian, then Catholic', () async {
  final prayers = await repository.watchLibrary(
    purpose: PrayerPurpose.guidance,
    languagePreference: PrayerLanguagePreference.jesus,
  ).first;
  expect(prayers.map((p) => p.languageStyle), [
    PrayerLanguageStyle.jesus,
    PrayerLanguageStyle.christian,
    PrayerLanguageStyle.catholic,
  ]);
});
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `flutter test test/features/prayers/bundled_prayer_importer_test.dart test/features/prayers/prayer_repository_test.dart`

Expected: missing property/argument failures.

- [ ] **Step 3: Add explicit style metadata and stable ordering**

Add `language_style` (`christian`, `catholic`, or `jesus`) to bundled and canonical prayers. Order first by the preference rank, then existing helpful count and title. For `all`, retain existing helpful-count/title ordering. Never filter a style out. Increment bundled content version and seed at least one suitable prepared prayer for each language style used by guided purposes.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy services/api/database
git commit -m "feat: rank prepared prayers by language"
```

### Task 5: Build the one-choice-at-a-time guide and generation fallback

**Files:**
- Create: `apps/soulbuddy/lib/features/onboarding/providers/first_prayer_providers.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_screen.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_choice_page.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_detail_page.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_result_page.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/onboarding/first_prayer_screen_test.dart`
- Modify: `apps/soulbuddy/test/features/onboarding/onboarding_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for exact copy and navigation**

```dart
expect(find.text('Prepare my first prayer'), findsOneWidget);
await tester.tap(find.text('Guidance'));
expect(find.text('How often?'), findsOneWidget);
await tester.tap(find.text('Daily'));
expect(find.text('Who is this for?'), findsOneWidget);
await tester.tap(find.text('Me'));
expect(find.text('Which feels more natural to you?'), findsOneWidget);
expect(find.text('Christian'), findsOneWidget);
expect(find.text('Catholic'), findsOneWidget);
expect(find.text('Jesus'), findsOneWidget);
expect(find.text('All of the above'), findsOneWidget);
```

Add tests for `Add anything?` with Speak, Write, and Not now; `Preparing your prayer…`; `Choose a prepared prayer`; and fallback after a generation exception.

- [ ] **Step 2: Run the widget tests and verify RED**

Run: `flutter test test/features/onboarding/onboarding_screen_test.dart test/features/onboarding/first_prayer_screen_test.dart`

Expected: missing route/widgets and old CTA text failures.

- [ ] **Step 3: Implement the guide and controller**

Add route `/welcome/prayer`. The controller saves after each answer, builds a generation request with situational defaults where required, dispatches it, watches the request, and uses the first ranked prepared prayer on offline/service failure. The only generation copy is `Preparing your prayer…`; never render provider names. The prayer result presents `Listen` only when narration exists, plus `Pray now` and `Keep this prayer`.

Use a compact single-column choice layout with 56dp minimum targets, semantic question/option labels, large-text-safe scrolling inside content only, and reduced-motion-aware transitions.

- [ ] **Step 4: Run widget tests and verify GREEN**

Run the command from Step 2.

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/onboarding apps/soulbuddy/lib/app/router.dart apps/soulbuddy/test/features/onboarding
git commit -m "feat: guide a new user's first prayer"
```

### Task 6: Connect Pray now, Keep this prayer, and Practice

**Files:**
- Modify: `apps/soulbuddy/lib/features/onboarding/providers/first_prayer_providers.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_result_page.dart`
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_practice_page.dart`
- Test: `apps/soulbuddy/test/features/onboarding/first_prayer_practice_test.dart`

- [ ] **Step 1: Write failing behavior tests**

```dart
await tester.tap(find.text('Keep this prayer'));
verify(() => personalPrayerRepository.accept(
  requestId: request.id,
  title: request.draftTitle!,
  body: request.draftBody!,
  action: request.draftAction,
)).called(1);
verify(() => prayerRepository.selectForToday(any(), includeAction: true)).called(1);

await tester.tap(find.text('Pray now'));
verify(() => practiceRepository.recordSession(
  prayer: any(named: 'prayer'),
  timezone: any(named: 'timezone'),
)).called(1);
expect(find.text('Practice'), findsOneWidget);
expect(find.text(prayer.action!), findsOneWidget);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/features/onboarding/first_prayer_practice_test.dart`

Expected: missing practice transition and repository calls.

- [ ] **Step 3: Implement idempotent prayer acceptance and practice**

Generated prayers are accepted once, then selected for Today; fallback prayers are selected directly. `Pray now` records one session with a stable idempotency key. Render `Practice` immediately followed by the action; omit the section when no action exists. Persistence failures show a small retry action and an always-working `Go to Today` exit.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/onboarding apps/soulbuddy/test/features/onboarding/first_prayer_practice_test.dart
git commit -m "feat: carry first prayer into practice"
```

### Task 7: Add the simplified spoken or written remembrance

**Files:**
- Create: `apps/soulbuddy/lib/features/onboarding/presentation/first_remembrance_page.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/providers/first_prayer_providers.dart`
- Test: `apps/soulbuddy/test/features/onboarding/first_remembrance_test.dart`

- [ ] **Step 1: Write failing copy, writing, and audio tests**

```dart
expect(find.text('Before you leave, record something you would like to remember.'), findsOneWidget);
expect(find.text('Encounter'), findsOneWidget);
expect(find.text('Promise'), findsOneWidget);
expect(find.text('Scripture or lesson'), findsOneWidget);
expect(find.text('Nothing today'), findsOneWidget);

await tester.tap(find.text('Promise'));
expect(find.text('Speak or write?'), findsOneWidget);
await tester.tap(find.text('Write'));
await tester.enterText(find.byKey(const Key('first-remembrance-text')), 'God met me here.');
await tester.tap(find.text('Keep this memory'));
expect(createdDraft.title, startsWith('Promise · '));
expect(createdDraft.body, 'God met me here.');
expect(createdDraft.memoryType, MemoryType.promise);
```

Add an audio-path test that passes the `MemoryAudioDraft` returned by `AudioCapturePanel` to `EncounterRepository.create` with the same generated private title.

- [ ] **Step 2: Run the test and verify RED**

Run: `flutter test test/features/onboarding/first_remembrance_test.dart`

Expected: missing remembrance page and persistence behavior.

- [ ] **Step 3: Implement the restrained recorder**

Show only the exact remembrance question and four choices. After a type, show `Speak or write?`; Write has one text field and Speak reuses `AudioCapturePanel`. Generate titles as `<Type> · <localized date>`, set private defaults (`sensitive: false`, `isAltar: false`, recall enabled), and map `Scripture or lesson` to `MemoryType.lesson` while leaving advanced editing available later. `Nothing today` completes immediately.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/onboarding apps/soulbuddy/test/features/onboarding/first_remembrance_test.dart
git commit -m "feat: remember after the first prayer"
```

### Task 8: Completion, accessibility, and end-to-end verification

**Files:**
- Modify: `apps/soulbuddy/lib/features/onboarding/providers/first_prayer_providers.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/first_prayer_screen.dart`
- Modify: `apps/soulbuddy/test/features/onboarding/first_prayer_screen_test.dart`
- Create: `apps/soulbuddy/integration_test/guided_first_prayer_test.dart`

- [ ] **Step 1: Write a failing completion test**

```dart
testWidgets('completion clears progress and opens Today', (tester) async {
  await runGuidedPrayerToCompletion(tester);
  expect(router.location, '/today');
  expect(await progressRepository.load(), isNull);
  expect(find.text(savedPrayer.title), findsOneWidget);
});
```

Also test Go to Today from every major stage, 200% text scale, and reduced motion.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/features/onboarding/first_prayer_screen_test.dart`

Expected: progress remains or route does not complete.

- [ ] **Step 3: Implement completion and safe exits**

Clear progress only after the Today selection and optional memory have been attempted. Mark welcome complete before routing. If a write fails, preserve the guide data for retry but allow Today; never trap the user. Ensure the Today providers are invalidated so the chosen prayer, action state, and memory render immediately.

- [ ] **Step 4: Run formatting and all automated verification**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

From `services/api` run:

```powershell
php artisan test
```

Expected: every command exits 0 with no test failures or analyzer errors.

- [ ] **Step 5: Exercise first use on an Android emulator**

Install the debug APK on the emulator, clear only the emulator test app data, and walk the sequence: welcome → Guidance → Daily → Me → Jesus → Not now → prepared/generated prayer → Pray now → Practice → Promise → Write → Today. Capture screenshots at welcome, prayer result, and Today, and verify there is no provider name, clipped copy, accidental scroll requirement, or dead end.

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib apps/soulbuddy/test apps/soulbuddy/integration_test
git commit -m "test: verify guided first prayer journey"
```

