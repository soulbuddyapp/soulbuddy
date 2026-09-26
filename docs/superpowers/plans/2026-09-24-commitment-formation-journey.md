# Commitment Formation Journey and Guided Meditation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved one-time Commitment formation journey, flexible healthy-practice plan, editable declaration, scheduled voice invitation, guided meditation, ten-day review, and user-led Listening and Discernment flow.

**Architecture:** Add a focused `features/commitments/` Flutter domain with local-first PowerSync tables and a matching authenticated Laravel sync group. The journey finalizer creates the separate Commitment, linked actionable Goal, variable categorized practices, declaration, plan, and preparation cycle in one local transaction. Existing Goals, Record, prayer narration, notification, audio, and lifecycle services are extended through narrow interfaces rather than parallel subsystems.

**Tech Stack:** Flutter/Dart 3.9, Riverpod, GoRouter, PowerSync/SQLite, `audioplayers`, `flutter_local_notifications`, `speech_to_text`, Laravel/PHP, SQLite/MySQL/PostgreSQL-compatible migrations, `flutter_test`, integration tests, Windows PowerShell TTS generation, FFmpeg/FFprobe.

---

## Execution Rules

- Work in the isolated implementation worktree created before execution.
- Use TDD for every task: write a focused failing test, run it and observe the expected failure, implement the smallest coherent behavior, run the focused test, then commit.
- Never log or include private Commitment text in errors, analytics, notification payloads, sync issues, or TTS requests.
- Preserve the five primary shell destinations: Today, Goals, Persons, Remember, Circles.
- Keep `/welcome/goal` for legacy resumable progress; fresh users use `/welcome/commitment`.
- Use the exact wire values and limits in the approved specification.
- Each task ends with a focused test command and a commit. Do not combine unrelated cleanup into a task.

## File Map

### New Flutter feature files

- `apps/soulbuddy/lib/features/commitments/domain/commitment.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_guide.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_practice.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_declaration.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_meditation_plan.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_preparation_cycle.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_meditation_session.dart`
- `apps/soulbuddy/lib/features/commitments/domain/commitment_journey_progress.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_schema.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_journey_progress_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_journey_progress_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_journey_practice_draft_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_journey_practice_draft_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_reminder_device_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_reminder_device_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_finalization_recovery_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_finalization_recovery_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_audio_catalog_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_personal_prayer_narration_cache_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_personal_prayer_narration_cache_repository.dart`
- `apps/soulbuddy/lib/features/commitments/data/commitment_finalizer.dart`
- `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_finalizer.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_journey_flow.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_journey_controller.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_occurrence_calculator.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_reminder_coordinator.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_recovery_coordinator.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_audio.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_invitation_controller.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_meditation_session_controller.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_listening_session_controller.dart`
- `apps/soulbuddy/lib/features/commitments/application/commitment_memory_handoff.dart`
- `apps/soulbuddy/lib/features/commitments/providers/commitment_providers.dart`
- `apps/soulbuddy/lib/features/commitments/providers/commitment_journey_providers.dart`
- `apps/soulbuddy/lib/features/commitments/providers/commitment_audio_providers.dart`
- `apps/soulbuddy/lib/features/commitments/providers/commitment_reminder_providers.dart`
- `apps/soulbuddy/lib/features/commitments/providers/commitment_session_providers.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_goals_entry_card.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_journey_screen.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_invitation_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_readiness_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_quiet_place_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_needs_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_calling_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_practice_picker.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_declaration_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_guide_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_schedule_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_name_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_summary_screen.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_meditation_screen.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_listening_screen.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_session_end_view.dart`
- `apps/soulbuddy/lib/features/commitments/presentation/commitment_preparation_review_card.dart`
- `apps/soulbuddy/lib/features/settings/presentation/audio_credits_screen.dart`
- `apps/soulbuddy/lib/core/audio/reviewed_audio_transcript.dart`
- `apps/soulbuddy/lib/core/audio/speech_dictation_controller.dart`
- `apps/soulbuddy/assets/content/commitment_practices.json`
- `apps/soulbuddy/assets/audio/commitments/`
- `tools/audio/generate_commitment_assets.ps1`
- `scripts/commitments/verify_assets.py`

### Existing Flutter files to modify

- `apps/soulbuddy/lib/core/database/app_database.dart`
- `apps/soulbuddy/lib/app/app.dart`
- `apps/soulbuddy/lib/app/router.dart`
- `apps/soulbuddy/lib/app/app_overlay_visibility.dart`
- `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_gate.dart`
- `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_screen.dart`
- `apps/soulbuddy/lib/features/goals/domain/goal_action.dart`
- `apps/soulbuddy/lib/features/goals/data/goal_repository.dart`
- `apps/soulbuddy/lib/features/goals/data/powersync_goal_repository.dart`
- `apps/soulbuddy/lib/features/goals/application/goal_today_composer.dart`
- `apps/soulbuddy/lib/features/goals/presentation/goal_today_sections.dart`
- `apps/soulbuddy/lib/features/goals/presentation/goal_detail_screen.dart`
- `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart`
- `apps/soulbuddy/lib/features/goals/providers/goal_providers.dart`
- `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`
- `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`
- `apps/soulbuddy/pubspec.yaml`
- `apps/soulbuddy/ios/Runner.xcodeproj/project.pbxproj`
- `apps/soulbuddy/android/app/src/main/res/raw/commitment_spoken_invitation_v1.wav`
- `apps/soulbuddy/ios/Runner/Sounds/commitment_spoken_invitation_v1.wav`

### New Laravel files

- `services/api/database/migrations/2026_09_24_000000_create_commitment_tables.php`
- `services/api/database/migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php`
- `services/api/app/Models/Commitment.php`
- `services/api/app/Models/CommitmentPractice.php`
- `services/api/app/Models/CommitmentDeclaration.php`
- `services/api/app/Models/CommitmentMeditationPlan.php`
- `services/api/app/Models/CommitmentPreparationCycle.php`
- `services/api/app/Models/CommitmentMeditationSession.php`
- `services/api/app/Domain/Sync/CommitmentSyncMutationValidator.php`
- `services/api/app/Domain/Sync/CommitmentSyncMutationWriter.php`

### Existing Laravel files to modify

- `services/api/app/Domain/Sync/ApplyGoalSyncMutation.php`
- `services/api/app/Domain/Sync/GoalSyncMutationValidator.php`
- `services/api/app/Domain/Sync/GoalSyncMutationWriter.php`
- `services/api/app/Models/Goal.php`
- `services/api/app/Models/User.php`
- `services/api/tests/Feature/Goals/GoalSchemaTest.php`
- `services/api/tests/Feature/Sync/GoalMutationTest.php`
- `services/api/tests/Unit/MariaDbMigrationCompatibilityTest.php`
- `.github/workflows/onboarding-goals.yml`
- `docs/architecture/local-first.md`
- `docs/architecture/seek-goals-tranche-0-invariants.md`
- `README.md`

---

### Task 1: Define the Commitment domain and reviewed practice catalog

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_guide.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_practice.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_declaration.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_meditation_plan.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_preparation_cycle.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_meditation_session.dart`
- Create: `apps/soulbuddy/lib/features/commitments/domain/commitment_journey_progress.dart`
- Create: `apps/soulbuddy/assets/content/commitment_practices.json`
- Create: `apps/soulbuddy/test/features/commitments/commitment_domain_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_practice_catalog_test.dart`

- [ ] **Step 1: Write failing domain tests**

Cover exact wire values, Unicode limits, practice categories, declaration template, plan shape, cycle date, and session outcomes:

```dart
test('uses the approved wire values and code-point limits', () {
  expect(CommitmentJourneySlot.primary.wireValue, 'primary');
  expect(CommitmentGuideId.surrender.wireValue, 'surrender');
  expect(CommitmentPracticeCategory.joyPleasure.wireValue, 'joy_pleasure');
  expect(CommitmentMeditationFrequency.selectedDays.wireValue, 'selected_days');
  expect(CommitmentSessionKind.listening.wireValue, 'listening');
  expect(CommitmentMeditationSessionOutcome.endedEarly.wireValue, 'ended_early');
  expect(CommitmentTextLimits.name, 120);
  expect(CommitmentTextLimits.need, 500);
  expect(CommitmentTextLimits.calling, 1500);
  expect(CommitmentTextLimits.practice, 1000);
  expect(CommitmentTextLimits.declaration, 4000);
  expect(validateCommitmentText('name', '🙂' * 120), hasLength(120));
  expect(() => validateCommitmentText('name', '🙂' * 121), throwsArgumentError);
});

test('requires one to twelve categorized practices', () {
  expect(validatePracticeCount(0), throwsArgumentError);
  expect(validatePracticeCount(12), returnsNormally);
  expect(validatePracticeCount(13), throwsArgumentError);
  expect(CommitmentPracticeCategory.values, hasLength(3));
});
```

- [ ] **Step 2: Run the tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_domain_test.dart test/features/commitments/commitment_practice_catalog_test.dart
```

Expected: compilation fails because the Commitment domain and catalog do not exist.

- [ ] **Step 3: Add the domain enums and validators**

Use these exact values:

```dart
enum CommitmentJourneyStage {
  invitation,
  quietPlace,
  needs,
  calling,
  practices,
  declaration,
  guide,
  schedule,
  name,
  summary,
  finalizing,
}
enum CommitmentJourneySlot { primary('primary') }
enum CommitmentGuideId { surrender('surrender'), direction('direction'), peace('peace') }
enum CommitmentPracticeCategory {
  joyPleasure('joy_pleasure'),
  explorationAdventure('exploration_adventure'),
  attentionSelfEsteem('attention_self_esteem'),
}
enum CommitmentPracticeSource {
  reviewedSuggestion('reviewed_suggestion'),
  userAuthored('user_authored'),
}
enum CommitmentMeditationFrequency { daily('daily'), selectedDays('selected_days') }
enum CommitmentSessionKind { meditation('meditation'), listening('listening') }
enum CommitmentMeditationSessionOutcome { completed('completed'), endedEarly('ended_early') }
enum CommitmentReminderMode { voice('voice'), silent('silent'), off('off') }
enum CommitmentPreparationCycleState {
  active('active'),
  reviewAvailable('review_available'),
  listeningOpened('listening_opened'),
  deferred('deferred'),
}
```

Each enum exposes `wireValue`, `tryFromWire`, and a strict `fromWire` that throws `FormatException` without including private content. `validateCommitmentText` trims and validates `runes.length`. Practice count accepts 1–12. Plan validation accepts durations `{5, 10, 15, 20, 30}`, `HH:mm`, an IANA timezone, daily with a null mask, and selected days with a mask from 1 through 127. Session validation requires `endedAt >= startedAt`, completed actual seconds equal planned seconds, and ended-early actual seconds below planned seconds.

Add the concrete value objects used by later tasks:

```dart
class Commitment {
  const Commitment({
    required this.id,
    required this.ownerId,
    required this.journeySlot,
    required this.goalId,
    required this.name,
    required this.keyNeedOne,
    required this.keyNeedTwo,
    required this.keyNeedThree,
    required this.calling,
    required this.guideId,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String ownerId;
  final CommitmentJourneySlot journeySlot;
  final String goalId;
  final String name;
  final String keyNeedOne;
  final String keyNeedTwo;
  final String keyNeedThree;
  final String calling;
  final CommitmentGuideId guideId;
  final DateTime createdAt;
  final DateTime updatedAt;
  factory Commitment.fromRow(Map<String, dynamic> row);
}

class CommitmentPractice {
  const CommitmentPractice({
    required this.id,
    required this.ownerId,
    required this.commitmentId,
    required this.goalActionId,
    required this.category,
    required this.body,
    required this.position,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.suggestionId,
  });
  final String id;
  final String ownerId;
  final String commitmentId;
  final String goalActionId;
  final CommitmentPracticeCategory category;
  final String body;
  final int position;
  final CommitmentPracticeSource source;
  final String? suggestionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  factory CommitmentPractice.fromRow(Map<String, dynamic> row);
}

class CommitmentJourneyProgress {
  const CommitmentJourneyProgress({
    this.stage = CommitmentJourneyStage.invitation,
    this.readinessTeachingSeen = false,
    this.invitationCompleted = false,
    this.keyNeedOne,
    this.keyNeedTwo,
    this.keyNeedThree,
    this.calling,
    this.guideId,
    this.personalPrayerId,
    this.personalPrayerRevisionId,
    this.declarationDraft,
    this.declarationReviewed = false,
    this.frequency,
    this.weekdaysMask,
    this.localTime,
    this.timezone,
    this.durationMinutes,
    this.reminderMode,
    this.name,
    this.deferred = false,
  });
  final CommitmentJourneyStage stage;
  final bool readinessTeachingSeen;
  final bool invitationCompleted;
  final String? keyNeedOne;
  final String? keyNeedTwo;
  final String? keyNeedThree;
  final String? calling;
  final CommitmentGuideId? guideId;
  final String? personalPrayerId;
  final String? personalPrayerRevisionId;
  final String? declarationDraft;
  final bool declarationReviewed;
  final CommitmentMeditationFrequency? frequency;
  final int? weekdaysMask;
  final String? localTime;
  final String? timezone;
  final int? durationMinutes;
  final CommitmentReminderMode? reminderMode;
  final String? name;
  final bool deferred;
}

class CommitmentDetails {
  const CommitmentDetails({
    required this.commitment,
    required this.practices,
    required this.declaration,
    required this.plan,
    required this.preparationCycle,
  });
  final Commitment commitment;
  final List<CommitmentPractice> practices;
  final CommitmentDeclaration? declaration;
  final CommitmentMeditationPlan? plan;
  final CommitmentPreparationCycle? preparationCycle;
}

class CommitmentDeclarationDraft {
  const CommitmentDeclarationDraft({required this.commitmentId, required this.body});
  final String commitmentId;
  final String body;
}

class CommitmentMeditationPlanDraft {
  const CommitmentMeditationPlanDraft({
    required this.commitmentId,
    required this.frequency,
    required this.localTime,
    required this.timezone,
    required this.durationMinutes,
    required this.enabled,
    this.weekdaysMask,
  });
  final String commitmentId;
  final CommitmentMeditationFrequency frequency;
  final String localTime;
  final String timezone;
  final int durationMinutes;
  final bool enabled;
  final int? weekdaysMask;
}

class CommitmentPreparationCycleDraft {
  const CommitmentPreparationCycleDraft({
    required this.commitmentId,
    required this.startedAtUtc,
    required this.startedLocalDate,
    required this.startTimezone,
    required this.reviewLocalDate,
    required this.state,
  });
  final String commitmentId;
  final DateTime startedAtUtc;
  final String startedLocalDate;
  final String startTimezone;
  final String reviewLocalDate;
  final CommitmentPreparationCycleState state;
}

class CommitmentMeditationSessionDraft {
  const CommitmentMeditationSessionDraft({
    required this.commitmentId,
    required this.sessionKind,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.outcome,
    required this.deviceId,
  });
  final String commitmentId;
  final CommitmentSessionKind sessionKind;
  final DateTime startedAt;
  final DateTime endedAt;
  final String localDate;
  final int plannedDurationSeconds;
  final int actualDurationSeconds;
  final CommitmentMeditationSessionOutcome outcome;
  final String deviceId;
}
```

- [ ] **Step 4: Add the reviewed practice catalog**

Create `assets/content/commitment_practices.json` with `version: 1`, stable IDs, categories, display text, and review metadata. It must contain these exact six suggestions in each category:

```json
{
  "version": 1,
  "practices": [
    {"id":"joy.help_concrete_need","category":"joy_pleasure","text":"Help someone with a concrete need.","reviewState":"approved"},
    {"id":"joy.enjoy_task","category":"joy_pleasure","text":"Spend time on a task you genuinely enjoy.","reviewState":"approved"},
    {"id":"joy.read_for_pleasure","category":"joy_pleasure","text":"Read or learn something for pleasure and growth.","reviewState":"approved"},
    {"id":"joy.share_meal","category":"joy_pleasure","text":"Share a meal, laugh, or celebrate with someone.","reviewState":"approved"},
    {"id":"joy.make_something","category":"joy_pleasure","text":"Make something or complete a small creative project.","reviewState":"approved"},
    {"id":"joy.phone_free_nature","category":"joy_pleasure","text":"Take a pleasant, phone-free break in nature.","reviewState":"approved"},
    {"id":"exploration.walk_without_scrolling","category":"exploration_adventure","text":"Walk outside without doomscrolling.","reviewState":"approved"},
    {"id":"exploration.exercise","category":"exploration_adventure","text":"Exercise, jog, stretch, or go to the gym.","reviewState":"approved"},
    {"id":"exploration.new_route","category":"exploration_adventure","text":"Try a new route, neighborhood, trail, or park.","reviewState":"approved"},
    {"id":"exploration.new_skill","category":"exploration_adventure","text":"Learn a small new skill or hobby.","reviewState":"approved"},
    {"id":"exploration.curious_visit","category":"exploration_adventure","text":"Visit a museum, event, or place out of curiosity.","reviewState":"approved"},
    {"id":"exploration.active_outing","category":"exploration_adventure","text":"Bike, hike, or plan a simple active outing.","reviewState":"approved"},
    {"id":"attention.trusted_company","category":"attention_self_esteem","text":"Spend undistracted time with a trusted friend or family member.","reviewState":"approved"},
    {"id":"attention.belonging","category":"attention_self_esteem","text":"Join a class, team, or community where you can belong.","reviewState":"approved"},
    {"id":"attention.honest_feedback","category":"attention_self_esteem","text":"Ask for honest feedback and receive it without performing.","reviewState":"approved"},
    {"id":"attention.known_contribution","category":"attention_self_esteem","text":"Serve in a responsibility where your contribution is known.","reviewState":"approved"},
    {"id":"attention.one_true_sentence","category":"attention_self_esteem","text":"Pray, read Scripture, or sit quietly and speak one true sentence to God.","reviewState":"approved"},
    {"id":"attention.name_what_was_done_well","category":"attention_self_esteem","text":"Finish one small task and name what was done well.","reviewState":"approved"}
  ]
}
```

The catalog repository must reject duplicate IDs, unknown categories, unapproved entries, and missing text without logging content.

- [ ] **Step 5: Add deterministic declaration construction**

Implement `buildCommitmentDeclarationDraft` with the approved local template. It must replace only explicit template fields, join selected practice summaries with `; `, and never call a model or network service. The declaration remains editable and may be empty of any particular line after review.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_domain_test.dart test/features/commitments/commitment_practice_catalog_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/domain apps/soulbuddy/assets/content/commitment_practices.json apps/soulbuddy/test/features/commitments
git commit -m "feat: define commitment formation domain"
```

---

### Task 2: Add the local-first Commitment schema and progress repositories

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_schema.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_journey_progress_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_journey_progress_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_journey_practice_draft_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_journey_practice_draft_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_database.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_schema_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_progress_repository_test.dart`

- [ ] **Step 1: Write failing schema and local-only tests**

Assert the runtime schema opens the synced tables `commitments`, `commitment_practices`, `commitment_declarations`, `commitment_meditation_plans`, `commitment_preparation_cycles`, and `commitment_meditation_sessions`, plus local-only progress, practice-draft, reminder-device, recovery, and narration-cache tables. Assert local-only writes produce no PowerSync CRUD transaction.

- [ ] **Step 2: Write failing malformed-progress tests**

Insert a row with valid needs, one oversized need, an invalid guide, and an inconsistent schedule. Assert valid fields survive, malformed fields are discarded independently, the row is normalized, and the recovery message contains field names but no submitted text.

- [ ] **Step 3: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_schema_test.dart test/features/commitments/commitment_progress_repository_test.dart
```

Expected: compilation/table failures.

- [ ] **Step 4: Add the PowerSync tables**

Use `commitmentTables` with the exact fields and indexes from the specification. `commitment_practices` includes `goal_action_id`, `category`, `body`, `position`, `source`, and nullable `suggestion_id`. `commitment_declarations` includes `body`, `reviewed_at`, and timestamps. `commitment_preparation_cycles` includes `started_at_utc`, `started_local_date`, `start_timezone`, `review_local_date`, and `state`. `commitment_meditation_sessions` includes `session_kind`.

Use `Table.localOnly` for `commitment_journey_progress`, `commitment_journey_practice_drafts`, `commitment_reminder_devices`, `commitment_finalization_recovery`, and `commitment_personal_prayer_narration_cache`. Register `...commitmentTables` in `appRuntimeSchema`.

- [ ] **Step 5: Implement field-by-field progress loading**

`CommitmentJourneyProgressRepository.load()` returns progress plus a set of discarded field names. It parses every text/enum/bool independently, validates schedule as a group, clears both personal-prayer IDs if either is invalid, preserves other valid values, and never includes private values in exceptions. `save()` uses `INSERT OR REPLACE` for `id = 'current'`, validates code-point limits, and does not call PowerSync queue APIs directly.

- [ ] **Step 6: Implement ordered practice-draft persistence**

The draft repository uses a local-only `current` namespace and stores `draftId`, `position`, `category`, `body`, `source`, and nullable `suggestionId`. It preserves order, removes one draft by ID, clears all drafts after finalization, and never uploads rows.

- [ ] **Step 7: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_schema_test.dart test/features/commitments/commitment_progress_repository_test.dart
```

Expected: PASS, including reopen and zero local CRUD entries.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/core/database/app_database.dart apps/soulbuddy/lib/features/commitments/data apps/soulbuddy/test/features/commitments
git commit -m "feat: add local commitment formation state"
```

---

### Task 3: Implement owner-scoped Commitment repositories and preparation projections

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_reminder_device_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_reminder_device_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/providers/commitment_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_repository_test.dart`

- [ ] **Step 1: Write failing owner-scope and projection tests**

Seed one owner’s Commitment, Goal, practices, declaration, plan, cycle, and session. Assert another owner sees null, practice order is deterministic by `position`, no prayer body is selected, and device reminder state contains no private text.

- [ ] **Step 2: Run the repository test and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_repository_test.dart
```

Expected: compilation failure.

- [ ] **Step 3: Add the repository interface**

```dart
abstract interface class CommitmentRepository {
  Stream<Commitment?> watchPrimary();
  Stream<CommitmentDetails?> watchDetails(String commitmentId);
  Future<void> updateGuide(String commitmentId, CommitmentGuideId guideId);
  Future<CommitmentMeditationPlan> savePlan(CommitmentMeditationPlanDraft draft);
  Stream<List<CommitmentMeditationSession>> watchSessions(String commitmentId);
  Future<CommitmentMeditationSession> recordSession(CommitmentMeditationSessionDraft draft);
  Future<void> updatePractice(String practiceId, {required String body});
  Future<void> archivePractice(String practiceId);
  Future<void> saveDeclaration(CommitmentDeclarationDraft draft);
  Future<void> savePreparationCycle(CommitmentPreparationCycleDraft draft);
}
```

- [ ] **Step 4: Implement owner-scoped PowerSync queries**

Every query and mutation includes `owner_id = ?`. `watchDetails` joins the current Goal revision, all active `commitment_practices`, the declaration, plan, cycle, and linked Goal action IDs. It orders practices by `position, created_at, id`. It never selects private prayer body or unrelated owner rows. Use UUIDv7 for new plan/session/declaration rows and preserve existing IDs on edits.

- [ ] **Step 5: Add device state and providers**

The reminder-device repository stores only mode, next occurrence, scheduled timezone, platform IDs, and timestamps. Expose `primaryCommitmentProvider`, `commitmentDetailsProvider`, `commitmentEntryProvider`, `preparationReviewProvider`, and `commitmentSessionsProvider`. The Goals entry projection must be `viewCommitment` if a Commitment exists, `continueJourney` if only a draft exists, otherwise `begin`.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_repository_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/data apps/soulbuddy/lib/features/commitments/providers apps/soulbuddy/test/features/commitments/commitment_repository_test.dart
git commit -m "feat: add owner-scoped commitment repositories"
```

---

### Task 4: Add Laravel Commitment schema, models, and action-kind migration

**Files:**
- Create: `services/api/database/migrations/2026_09_24_000000_create_commitment_tables.php`
- Create: `services/api/database/migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php`
- Create: `services/api/app/Models/Commitment.php`
- Create: `services/api/app/Models/CommitmentPractice.php`
- Create: `services/api/app/Models/CommitmentDeclaration.php`
- Create: `services/api/app/Models/CommitmentMeditationPlan.php`
- Create: `services/api/app/Models/CommitmentPreparationCycle.php`
- Create: `services/api/app/Models/CommitmentMeditationSession.php`
- Modify: `services/api/app/Models/Goal.php`
- Modify: `services/api/app/Models/User.php`
- Create: `services/api/tests/Feature/Commitments/CommitmentSchemaTest.php`
- Modify: `services/api/tests/Feature/Goals/GoalSchemaTest.php`
- Modify: `services/api/tests/Unit/MariaDbMigrationCompatibilityTest.php`

- [ ] **Step 1: Write failing schema tests**

Assert every table, column, index, composite owner foreign key, unique primary slot, one-plan-per-Commitment constraint, practice category/source constraints, declaration bound, cycle date/state constraints, session kind/outcome constraints, action-kind acceptance, and account cascade. Use direct invalid inserts to assert database checks, not only HTTP validation.

- [ ] **Step 2: Run schema tests and verify red**

```powershell
Set-Location services/api
php artisan test tests/Feature/Commitments/CommitmentSchemaTest.php tests/Feature/Goals/GoalSchemaTest.php
```

Expected: missing tables/models and old action enum failures.

- [ ] **Step 3: Create the migrations**

Create the six synced tables in dependency order. Use UUID primary keys, `user_id` foreign keys with cascade, composite owner foreign keys, and unique constraints for `(user_id, journey_slot)`, `(goal_id, user_id)`, and `(commitment_id, position)`. Add cross-database triggers/checks for plan frequency/mask/duration, declaration nonblank body, cycle state/date order, and session timing/outcome shape. Follow the existing SQLite/PostgreSQL/MySQL branches.

Create a separate action-kind migration that adds `commitment_practice` to MySQL/MariaDB enums and updates PostgreSQL/SQLite checks without rewriting existing rows. Its `down()` must refuse to remove the value while such rows exist rather than silently rewriting user data.

- [ ] **Step 4: Add Eloquent models and relationships**

`Commitment` has `user`, `goal`, `practices`, `declaration`, `meditationPlan`, `preparationCycle`, and `meditationSessions`. `CommitmentPractice` has `commitment`, `goalAction`, and `user`. The declaration, plan, cycle, and session models cast dates, booleans, integers, enums, and durations explicitly. `Goal` has `commitment()`. `User` has all six Commitment relationships. `CommitmentMeditationSession` has `public $timestamps = false`.

- [ ] **Step 5: Run schema and formatting checks**

```powershell
Set-Location services/api
php artisan test tests/Feature/Commitments/CommitmentSchemaTest.php tests/Feature/Goals/GoalSchemaTest.php
vendor\bin\pint --test app/Models database/migrations/2026_09_24_000000_create_commitment_tables.php database/migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php tests/Feature/Commitments
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
Set-Location ../..
git add services/api/database/migrations/2026_09_24_000000_create_commitment_tables.php services/api/database/migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php services/api/app/Models services/api/tests/Feature/Commitments services/api/tests/Feature/Goals/GoalSchemaTest.php services/api/tests/Unit/MariaDbMigrationCompatibilityTest.php
git commit -m "feat: add commitment formation schema"
```

---

### Task 5: Implement Laravel Commitment sync validation and atomic writing

**Files:**
- Create: `services/api/app/Domain/Sync/CommitmentSyncMutationValidator.php`
- Create: `services/api/app/Domain/Sync/CommitmentSyncMutationWriter.php`
- Modify: `services/api/app/Domain/Sync/ApplyGoalSyncMutation.php`
- Modify: `services/api/app/Domain/Sync/GoalSyncMutationValidator.php`
- Modify: `services/api/app/Domain/Sync/GoalSyncMutationWriter.php`
- Create: `services/api/tests/Feature/Sync/CommitmentMutationTest.php`
- Create: `services/api/tests/Feature/Sync/CommitmentMutationValidationTest.php`

- [ ] **Step 1: Write failing validator datasets**

Test exact allowed payload keys, code-point bounds, category/source enums, 1–12 practices, declaration/cycle/session shapes, owner scoping, same-owner references, unique primary slot, immutable sessions, and sanitized error codes. Assert forged `owner_id` is ignored and no private value appears in a response or exception.

- [ ] **Step 2: Write failing mixed-batch API tests**

Post a batch containing a Goal, revision, one or more `commitment_practice` actions, Commitment, practices, declaration, plan, and cycle. Assert atomic acceptance, exact replay counts, operation conflict behavior, second-primary rejection with no partial Goal rows, cross-owner rejection, and account deletion cascades.

- [ ] **Step 3: Run tests and verify red**

```powershell
Set-Location services/api
php artisan test tests/Feature/Sync/CommitmentMutationValidationTest.php tests/Feature/Sync/CommitmentMutationTest.php
```

Expected: `unsupported_table` or missing validator/writer failures.

- [ ] **Step 4: Implement strict validator and writer**

Use only these sanitized codes: `invalid_data`, `inaccessible_record`, `invalid_commitment_goal`, `primary_commitment_exists`, `immutable_session`, and `unsupported_operation`. Validate all records before any writer runs. The writer writes Goals/revisions/actions first, then Commitment, practices, declaration, plan, cycle, and sessions, always using authenticated `$user->id`. Sessions are append-only. Practice bodies and declaration text are stored without semantic rewriting.

- [ ] **Step 5: Integrate with replay-safe Goal sync**

Add all six new tables to `ApplyGoalSyncMutation::TABLES`. Partition guard operations, core Goal operations, and Commitment operations, validate every group before writing, and keep the existing user row lock, operation fingerprints, duplicate counts, constraint replay handling, and outer transaction. Update `GoalSyncMutationValidator` to accept `commitment_practice` for puts/patches. Do not create a second replay implementation.

- [ ] **Step 6: Run server tests and commit**

```powershell
Set-Location services/api
php artisan test tests/Feature/Sync/CommitmentMutationTest.php tests/Feature/Sync/CommitmentMutationValidationTest.php tests/Feature/Sync/GoalMutationTest.php tests/Feature/Commitments/CommitmentSchemaTest.php
vendor\bin\pint --test app/Domain/Sync tests/Feature/Sync tests/Feature/Commitments
```

Expected: PASS.

```powershell
Set-Location ../..
git add services/api/app/Domain/Sync services/api/tests/Feature/Sync
git commit -m "feat: sync commitment formation records"
```

---

### Task 6: Integrate variable Commitment practices with Goals and Today

**Files:**
- Modify: `apps/soulbuddy/lib/features/goals/domain/goal_action.dart`
- Modify: `apps/soulbuddy/lib/features/goals/data/goal_repository.dart`
- Modify: `apps/soulbuddy/lib/features/goals/data/powersync_goal_repository.dart`
- Modify: `apps/soulbuddy/lib/features/goals/application/goal_today_composer.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goal_today_sections.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goal_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart`
- Create: `apps/soulbuddy/lib/features/goals/presentation/goal_practice_controls.dart`
- Create: `apps/soulbuddy/test/features/goals/commitment_practice_goal_test.dart`
- Modify: `apps/soulbuddy/test/features/goals/goal_repository_test.dart`
- Modify: `apps/soulbuddy/test/features/goals/goal_today_composer_test.dart`

- [ ] **Step 1: Write failing Goal integration tests**

Assert `GoalActionKind.fromWire('commitment_practice')`, owner-scoped action body editing, archive/skip/retract, all 1–12 practices appearing before generic resources, neutral practice icon, and a linked Commitment Goal whose title cannot diverge from the Commitment name.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/goals/commitment_practice_goal_test.dart test/features/goals/goal_repository_test.dart test/features/goals/goal_today_composer_test.dart
```

Expected: unknown action-kind and missing controls failures.

- [ ] **Step 3: Add the action kind and repository mutation**

Add:

```dart
commitmentPractice('commitment_practice'),
```

Add `Future<GoalAction> editActionBody(String actionId, {required String body})` to the Goal repository and implement it owner-scoped with a patch. Update both exhaustive action switches.

- [ ] **Step 4: Preserve all Commitment practices in Today**

Update `GoalTodayComposer` so a linked Commitment Goal first selects all active `commitment_practice` actions ordered by `created_at, id`, then selects ordinary actions/resources. The ordinary three-item cap applies only to non-Commitment Goals. Add a neutral checklist icon and a typed Today overflow containing Skip and Undo/retraction.

- [ ] **Step 5: Add Goal practice controls**

Create `GoalPracticeControls` that lists all active practice actions, supports edit, skip, complete, undo/retract, and archive, and exposes no spiritual score. For a Goal linked to a Commitment, hide generic title editing and show **View commitment** instead. Ordinary Goals retain existing edit behavior.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/goals/commitment_practice_goal_test.dart test/features/goals/goal_repository_test.dart test/features/goals/goal_today_composer_test.dart test/architecture/product_invariants_test.dart
```

Expected: PASS and five shell destinations unchanged.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/goals apps/soulbuddy/test/features/goals
git commit -m "feat: show commitment practices in goals and today"
```

---

### Task 7: Implement atomic finalization and process-death recovery

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_finalizer.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_finalizer.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_finalization_recovery_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_finalization_recovery_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_recovery_coordinator.dart`
- Modify: `apps/soulbuddy/lib/features/commitments/providers/commitment_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_finalizer_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_recovery_test.dart`

- [ ] **Step 1: Write failing atomic-finalizer tests**

Assert one transaction creates one Commitment, one Goal/revision, one action per practice, the declaration, plan, cycle, and recovery marker; deletes progress and practice drafts; preserves practice order and exact text; creates no session or Goal event; and rolls everything back on a bad prayer reference or malformed declaration. A second finalization returns the existing IDs without duplicates.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_finalizer_test.dart test/features/commitments/commitment_recovery_test.dart
```

Expected: missing finalizer/recovery failures.

- [ ] **Step 3: Add finalizer contracts**

```dart
class CommitmentFinalizationResult {
  const CommitmentFinalizationResult({
    required this.commitmentId,
    required this.goalId,
    required this.planId,
  });
  final String commitmentId;
  final String goalId;
  final String planId;
}

abstract interface class CommitmentFinalizer {
  Future<CommitmentFinalizationResult> finalize(CommitmentJourneyProgress progress);
}
```

- [ ] **Step 4: Implement the single transaction**

Use `database.writeTransaction`. Query the existing owner/`primary` row first. Allocate UUIDv7 IDs before writes. Insert Goal/revision/actions/link, Commitment/practices/declaration/plan/cycle/recovery, then delete local progress and drafts. The recovery row contains only `id`, `commitment_id`, and `finalized_at`. Do not call notification, Deepgram, secure storage, or file APIs in the transaction.

- [ ] **Step 5: Implement recovery acknowledgement**

`resolve()` returns null without a marker, clears a stale marker when the Commitment is absent, and returns an existing owner-scoped Commitment ID. `acknowledge(id)` clears only the matching marker after navigation has been issued. Existing users with a normal Commitment and no marker still launch Today.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_finalizer_test.dart test/features/commitments/commitment_recovery_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments apps/soulbuddy/test/features/commitments
git commit -m "feat: finalize commitment formation atomically"
```

---

### Task 8: Add the journey state machine, controller, and recovery-aware routing

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_journey_flow.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_journey_controller.dart`
- Create: `apps/soulbuddy/lib/features/commitments/providers/commitment_journey_providers.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/lib/app/app_overlay_visibility.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_gate.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_screen.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_journey_flow_test.dart`
- Create: `apps/soulbuddy/test/app/commitment_navigation_test.dart`
- Modify: `apps/soulbuddy/test/features/onboarding/onboarding_gate_test.dart`

- [ ] **Step 1: Write failing state and routing tests**

Test stages `invitation`, `quietPlace`, `needs`, `calling`, `practices`, `declaration`, `guide`, `schedule`, `name`, `summary`, and `finalizing`; Back preserves answers; **Not now** preserves exact progress; readiness teaching is optional at `/welcome/commitment/readiness` before saving and `/commitments/:id/readiness` afterward; fresh welcome routes to `/welcome/commitment`; legacy Goal progress routes to `/welcome/goal`; first prayer remains higher priority; an existing normal Commitment does not force launch routing; recovery marker routes once to summary.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_journey_flow_test.dart test/app/commitment_navigation_test.dart test/features/onboarding/onboarding_gate_test.dart
```

Expected: missing routes/provider/callback failures.

- [ ] **Step 3: Add the pure flow and notifier**

Implement `CommitmentJourneyFlow` methods `normalizeForResume`, `markReadinessTeachingSeen`, `completeInvitation`, `continueFromQuietPlace`, `setNeeds`, `continueFromNeeds`, `setCalling`, `continueFromCalling`, `setPracticeDrafts`, `continueFromPractices`, `setDeclaration`, `reviewDeclaration`, `continueFromDeclaration`, `selectGuide`, `continueFromGuide`, `setSchedule`, `continueFromSchedule`, `setName`, `continueFromName`, `beginFinishing`, `defer`, and `goBack`. Serialize controller writes with a private future queue and restore the previous state on save failure.

- [ ] **Step 4: Add routes and overlay ownership**

Add outside the shell:

```text
/welcome/commitment
/welcome/commitment/readiness
/commitments/:commitmentId
/commitments/:commitmentId/readiness
/commitments/:commitmentId/meditate
/commitments/:commitmentId/listen
```

Keep `/welcome/goal` and `/welcome/prayer`. Hide the global spiritual mini-player and reminder overlays on Commitment immersive routes. Wire recovery resolution into `SoulBuddyApp` and route notification responses only to session preparation.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_journey_flow_test.dart test/app/commitment_navigation_test.dart test/features/onboarding/onboarding_gate_test.dart test/architecture/product_invariants_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/app apps/soulbuddy/lib/features/onboarding apps/soulbuddy/lib/features/commitments apps/soulbuddy/test
git commit -m "feat: route resumable commitment formation journey"
```

---

### Task 9: Build reviewed readiness, invitation, guide, listening, and notification assets

**Files:**
- Create: `tools/audio/generate_commitment_assets.ps1`
- Create: `apps/soulbuddy/assets/audio/commitments/`
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_audio_catalog_repository.dart`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Create: `apps/soulbuddy/test/features/commitments/commitment_audio_asset_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_audio_catalog_test.dart`

- [ ] **Step 1: Write failing asset tests**

Assert the manifest contains readiness narration/transcript, invitation narration/transcript, Surrender/Direction/Peace guides, Listening guide, spoken notification, and the exact Aphelion excerpt. Assert all files exist, hashes/durations match, captions are ordered, the Aphelion interval is `00:01:45`–`00:02:15`, and missing optional media is represented as a fallback rather than a crash.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_audio_asset_test.dart test/features/commitments/commitment_audio_catalog_test.dart
```

Expected: missing catalog/assets failures.

- [ ] **Step 3: Add the reviewed content and generation script**

Use these canonical text constants in `catalog_v1.json`:

```text
READINESS:
Imagine a three-year-old looking up and saying, “I’m ready to get married. I would like my own home.” You may be stunned for a moment, and most of us laugh. A real desire can be real before a person is ready to carry its weight. Sometimes we ask God to reveal our purpose before we are formed to carry it. Moses wanted to free his enslaved brothers, but the desert became a place of formation. He waited, and God formed him for the mission in God’s timing. We are created by God. In Christ, our whole life—spirit, mind, body, desires, habits, and work—can be brought back to God. Scripture, prayer, a willing attitude, and healthy activity help form us; they are not a spiritual performance. Prayer is not dependent on a perfect posture or a perfectly quiet room. When you can, turn toward God deliberately. What are you asking God to give you, form in you, and help you carry?

INVITATION:
Rise. Bring your whole life before God. Name the calling you will answer. Choose the good you will do today. Lay down the habit that holds you captive. Ask the Father, through Jesus Christ, for strength. Then take the next faithful step. Serve someone. Keep your word. Plant something good in the garden each day. Commit your life to God. Put your faith into action. Begin now.

SPOKEN INVITATION:
This is a time to be with God, if you can. Open SoulBuddy when you are ready.

COMMON GUIDE OPENING:
Be still, and know that I am God. Let distracting thoughts pass rather than chasing them. You do not have to solve every feeling or hurry toward a spiritual experience. Receive whatever stillness is available. Focus on the divine Father, approached through Jesus. Present your needs, your calling, and your daily practices to God. Tell Him what you hope for, what you fear, and what you are trying to do with the life He has given you. Now listen.

SURRENDER:
Surrender your desires and choices. You are not alone, and you do not need to carry this commitment by yourself. Let honesty take the place of performance. Receive what is already yours in Christ. Stay in this place for a moment and listen.

DIRECTION:
Bring what you believe God has called you to do or become into the light. Ask for clarity around your next faithful step. Receive wisdom, and do not confuse urgency with direction. A calling may take time to become clear. You can ask, listen, learn, and choose the next faithful act without pretending to see the whole road.

PEACE:
Receive God’s presence without trying to manufacture it. Quiet distraction, receive comfort, and let this time become a small faithful practice of attention. You are not required to feel a particular way. Let grace reshape your attention, and receive the peace that is already present in Christ.

LISTENING:
You have practiced turning toward God. Now practice listening. You do not have to force a revelation or manufacture a feeling. Notice what Scripture stirs in you, what distracts you, and what faithful response is possible. The divine Father, approached through Jesus, can speak through His Word, through wisdom, through circumstances, and through a clear next act. Let the silence become a place where you do not rush to fill every space. Receive what is present, and remain open to correction. You do not need to understand the whole road to take the next faithful step. Now listen.
```

The PowerShell script must:

- require `ffmpeg` and `ffprobe`;
- require installed `Microsoft Zira Desktop` and fail rather than silently choose another voice;
- synthesize 24 kHz mono PCM16 WAV files for readiness, invitation, three guides, Listening, and spoken notification;
- download Aphelion to the approved temp directory and cut the exact `105–135` second interval;
- transcode the music excerpt to 192 kbps MP3 with a short fade;
- measure each generated caption from the actual audio segment;
- write `catalog_v1.json` and `ASSET-MANIFEST.md` with source, voice, license, transcript, hash, duration, and required/optional flags;
- never write the downloaded full music file into the repository.

- [ ] **Step 4: Register assets and run generation**

```powershell
Set-Location C:\dev\soulbuddy
Get-Command ffmpeg, ffprobe
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\dev\soulbuddy\tools\audio\generate_commitment_assets.ps1
```

Add `assets/audio/commitments/` and `assets/content/commitment_practices.json` to `pubspec.yaml`. Expected: all reviewed files and manifests exist; Aphelion duration is approximately 30 seconds.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_audio_asset_test.dart test/features/commitments/commitment_audio_catalog_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add tools/audio/generate_commitment_assets.ps1 apps/soulbuddy/assets/audio/commitments apps/soulbuddy/assets/content/commitment_practices.json apps/soulbuddy/pubspec.yaml apps/soulbuddy/lib/features/commitments/data/commitment_audio_catalog_repository.dart apps/soulbuddy/test/features/commitments
git commit -m "feat: add reviewed commitment formation media"
```

---

### Task 10: Implement invitation/readiness audio controllers and synchronized captions

**Files:**
- Create: `apps/soulbuddy/lib/core/audio/reviewed_audio_transcript.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_audio.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_invitation_controller.dart`
- Modify: `apps/soulbuddy/lib/features/commitments/providers/commitment_audio_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_invitation_controller_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_readiness_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Cover no autoplay, 45-second phase lookup, music start at 8 seconds, still bell at 41 seconds, pause/resume/replay/skip, missing music, missing narration, missing bell, generation-safe disposal, readiness playback/seek/replay, and synchronized caption lookup by media position.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_invitation_controller_test.dart test/features/commitments/commitment_readiness_controller_test.dart
```

Expected: missing audio/controller failures.

- [ ] **Step 3: Add the reusable transcript and audio ports**

Use:

```dart
sealed class CommitmentAudioSource {
  const CommitmentAudioSource();
}
final class CommitmentBundledAudioSource extends CommitmentAudioSource {
  const CommitmentBundledAudioSource(this.assetPath);
  final String assetPath;
}
final class CommitmentPrivateAudioSource extends CommitmentAudioSource {
  const CommitmentPrivateAudioSource({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}
abstract interface class CommitmentAudioPlayer {
  Stream<Duration> get positionChanges;
  Stream<Duration> get durationChanges;
  Stream<CommitmentAudioPlaybackStatus> get statusChanges;
  Future<void> play(CommitmentAudioSource source, {required double volume, required double playbackRate, required CommitmentAudioLoopMode loopMode, Duration startAt = Duration.zero});
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
```

`ReviewedAudioTranscript` validates ordered, non-overlapping cues and exposes `cueAt(Duration)`. The invitation uses narration at `.85`, music volume phases `.08/.14/.18/.24/.30/.12`, bell at `41s`, and a 45-second visual clock. Readiness uses its own one-shot player and transcript.

- [ ] **Step 4: Implement generation-safe controllers**

Every delayed callback checks a generation token. Audio failure marks only that source unavailable; the visual/controller phase continues. Controllers never call navigation from `dispose`. They emit one completion event for natural completion or skip.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_invitation_controller_test.dart test/features/commitments/commitment_readiness_controller_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/core/audio/reviewed_audio_transcript.dart apps/soulbuddy/lib/features/commitments/application apps/soulbuddy/lib/features/commitments/providers/commitment_audio_providers.dart apps/soulbuddy/test/features/commitments
git commit -m "feat: coordinate commitment formation audio"
```

---

### Task 11: Build the journey screens, practice picker, declaration, summary, and Goals card

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_journey_screen.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_invitation_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_readiness_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_quiet_place_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_needs_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_calling_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_practice_picker.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_declaration_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_guide_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_schedule_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_name_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_summary_screen.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_goals_entry_card.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_journey_screen_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_practice_picker_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_summary_screen_test.dart`
- Modify: `apps/soulbuddy/test/features/goals/goals_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Test all stage copy and controls, optional readiness link, exact quiet-place text, three need fields, on-device calling fallback, 1–12 practice add/remove/reorder/category selection, six suggestions per category, **Write my own**, editable declaration template fields and **I have prayed this**, schedule validation, name normalization, summary contents, **Not now**, and Goals entry routing for Begin/Continue/View.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_journey_screen_test.dart test/features/commitments/commitment_practice_picker_test.dart test/features/commitments/commitment_summary_screen_test.dart test/features/goals/goals_screen_test.dart
```

Expected: missing screens/card failures.

- [ ] **Step 3: Implement the shared journey scaffold**

Use one `Scaffold` with a progress label, Back, **Not now**, and a scrollable body. Every page persists through the controller before advancing. Use `MediaQuery.disableAnimationsOf(context)` plus the existing reduced-motion preference for the invitation/readiness visuals. Keep all targets at least 48dp and allow 200% text to scroll.

- [ ] **Step 4: Implement the practice picker and declaration**

Render category sections in the exact order Joy/Pleasure, Exploration/Adventure, Attention/Self-Esteem. Each suggestion has Use this, Write my own, and Remove. User-authored text opens a bounded multiline field. Practice order is explicit and persisted. The declaration page shows editable text areas for the full approved template and a non-private **I have prayed this** action.

- [ ] **Step 5: Implement summary and Goals entry**

The summary renders all private fields, categorized practices, declaration, plan, guide, readiness link, linked Goal, Begin now, and cycle review when available. The Goals card appears above ordinary Goal filters and never blocks the existing Goals list. If a draft exists, it opens the journey; if a Commitment exists, it opens summary.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_journey_screen_test.dart test/features/commitments/commitment_practice_picker_test.dart test/features/commitments/commitment_summary_screen_test.dart test/features/goals/goals_screen_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/presentation apps/soulbuddy/lib/features/goals/presentation/goals_screen.dart apps/soulbuddy/test/features/commitments apps/soulbuddy/test/features/goals/goals_screen_test.dart
git commit -m "feat: build commitment formation journey screens"
```

---

### Task 12: Add the device-local reminder coordinator and Android/iOS spoken notification

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_occurrence_calculator.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_reminder_coordinator.dart`
- Create: `apps/soulbuddy/lib/features/commitments/providers/commitment_reminder_providers.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Create: `apps/soulbuddy/android/app/src/main/res/raw/commitment_spoken_invitation_v1.wav`
- Create: `apps/soulbuddy/ios/Runner/Sounds/commitment_spoken_invitation_v1.wav`
- Modify: `apps/soulbuddy/ios/Runner.xcodeproj/project.pbxproj`
- Create: `apps/soulbuddy/test/features/commitments/commitment_occurrence_calculator_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_reminder_coordinator_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_notification_packaging_test.dart`
- Modify: `apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart`

- [ ] **Step 1: Write failing occurrence, coordinator, and packaging tests**

Cover daily/selected-day schedules, DST spring-forward/fall-back, stable IDs, eight one-offs for multiple weekdays, ordinary precision, permission denial, off mode, silent mode, browser no-op, cold-start event buffering, generic title/body, no private payload, no full-screen/ongoing behavior, versioned channel, and byte-identical Android/iOS sound copies.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_occurrence_calculator_test.dart test/features/commitments/commitment_reminder_coordinator_test.dart test/features/commitments/commitment_notification_packaging_test.dart test/features/prayers/prayer_reminder_scheduler_test.dart
```

Expected: missing kind/coordinator/sound failures.

- [ ] **Step 3: Add the scheduler kind and native mapping**

Add `ReminderNotificationKind.commitmentMeditation`. Map it to:

```text
title: Time to be with God
body: Open SoulBuddy when you are ready.
kind: commitmentMeditation
precision: ordinary
schedule mode: inexactAllowWhileIdle
actions: []
fullScreenIntent: false
ongoing: false
autoCancel: true
audio usage: notification
```

Use `commitment_meditation_voice_v1` for voice mode, `commitment_meditation_silent_v1` for silent mode, and no sound for browser. The payload contains exactly `reminder_id`, `occurrence_key`, and `kind`.

- [ ] **Step 4: Implement occurrence calculation and reconciliation**

Use the existing timezone package and DST-tested prayer occurrence logic. For multiple selected weekdays schedule eight one-off notifications with stable IDs. On app start/resume, query OS permission, cancel obsolete IDs, schedule current IDs, and save only device-local state. Notification response events buffer until `events` has a listener and never start a session.

- [ ] **Step 5: Package the notification sound**

Copy the generated master WAV to Android `res/raw` and iOS `Runner/Sounds`, then add matching PBX file/build references. Assert the sound is under the iOS custom-sound duration limit and contains the exact reviewed phrase in the manifest.

- [ ] **Step 6: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_occurrence_calculator_test.dart test/features/commitments/commitment_reminder_coordinator_test.dart test/features/commitments/commitment_notification_packaging_test.dart test/features/prayers/prayer_reminder_scheduler_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/application/commitment_occurrence_calculator.dart apps/soulbuddy/lib/features/commitments/application/commitment_reminder_coordinator.dart apps/soulbuddy/lib/features/commitments/providers/commitment_reminder_providers.dart apps/soulbuddy/lib/features/prayers/application apps/soulbuddy/lib/app/app.dart apps/soulbuddy/android/app/src/main/res/raw/commitment_spoken_invitation_v1.wav apps/soulbuddy/ios/Runner/Sounds/commitment_spoken_invitation_v1.wav apps/soulbuddy/ios/Runner.xcodeproj/project.pbxproj apps/soulbuddy/test/features/commitments apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart
git commit -m "feat: schedule spoken commitment invitations"
```

---

### Task 13: Implement the meditation/listening session controller and shared session audio

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_meditation_session_controller.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_listening_session_controller.dart`
- Create: `apps/soulbuddy/lib/features/commitments/providers/commitment_session_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_meditation_controller_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_listening_controller_test.dart`

- [ ] **Step 1: Write failing state-machine tests**

Cover `preparation → guiding → bell → silence → timing`, pause/resume, natural completion, explicit early end, guide failure, bell failure, optional private prayer, no Goal event, no session on background/dispose, `sessionKind` values, remaining time derived from an injected clock, and exactly one terminal repository write.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_meditation_controller_test.dart test/features/commitments/commitment_listening_controller_test.dart
```

Expected: missing controller failures.

- [ ] **Step 3: Implement the shared controller contract**

Use phases:

```dart
enum CommitmentSessionPhase { preparation, guiding, bell, silence, timing, paused, completed, endedEarly }
```

The controller receives clock, plan, guide player, still-bell player, optional sound-bed player, and session repository. It records `completed` only when the timer reaches zero and `ended_early` only through explicit End. Background callbacks call `pauseForInterruption()` and never record a session. Listening uses the same controller with `sessionKind: listening` and a different reviewed guide.

- [ ] **Step 4: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_meditation_controller_test.dart test/features/commitments/commitment_listening_controller_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/application/commitment_meditation_session_controller.dart apps/soulbuddy/lib/features/commitments/application/commitment_listening_session_controller.dart apps/soulbuddy/lib/features/commitments/providers/commitment_session_providers.dart apps/soulbuddy/test/features/commitments
git commit -m "feat: add foreground commitment session controllers"
```

---

### Task 14: Add optional immutable personal-prayer narration without private Commitment leakage

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/data/commitment_personal_prayer_narration_cache_repository.dart`
- Create: `apps/soulbuddy/lib/features/commitments/data/powersync_commitment_personal_prayer_narration_cache_repository.dart`
- Modify: `apps/soulbuddy/lib/features/commitments/data/commitment_schema.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`
- Modify: `apps/soulbuddy/lib/features/commitments/providers/commitment_audio_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_personal_prayer_narration_test.dart`
- Modify: `apps/soulbuddy/test/features/prayers/personal_prayer_practice_ui_test.dart`

- [ ] **Step 1: Write failing privacy/cache tests**

Assert only the exact personal prayer ID and immutable revision are sent to the existing narration preparation boundary; no Commitment ID, name, needs, calling, practice, declaration, or session text appears in the request. Assert cache bytes are local-only, consent is required, stale revisions are ignored, and playback never records a prayer session.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_personal_prayer_narration_test.dart test/features/prayers/personal_prayer_practice_ui_test.dart
```

Expected: missing cache/privacy failures.

- [ ] **Step 3: Extract and reuse the existing narration preparation service**

Reuse `PrayerNarrationRepository` and `PrayerNarrationPrerequisiteUploader`. The Commitment preparer accepts only prayer ID, prayer revision ID, device ID, and explicit consent. It never accepts a Commitment payload. The existing prayer reminder flow uses the same service without behavior change.

- [ ] **Step 4: Add local-only cache and player integration**

Cache the returned audio bytes/content type in `commitment_personal_prayer_narration_cache` keyed by Commitment, prayer ID, revision ID, and device ID. Load only a valid consented revision. Missing cache/network/consent falls back to the generic guide. Playback uses the private audio source and does not create a prayer or Goal session.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_personal_prayer_narration_test.dart test/features/prayers/personal_prayer_practice_ui_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/data/commitment_personal_prayer_narration_cache_repository.dart apps/soulbuddy/lib/features/commitments/data/powersync_commitment_personal_prayer_narration_cache_repository.dart apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart apps/soulbuddy/lib/features/commitments/providers/commitment_audio_providers.dart apps/soulbuddy/test/features/commitments apps/soulbuddy/test/features/prayers/personal_prayer_practice_ui_test.dart
git commit -m "feat: reuse consented prayer narration safely"
```

---

### Task 15: Build meditation, Listening, end, and Record memory screens

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_meditation_screen.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_listening_screen.dart`
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_session_end_view.dart`
- Create: `apps/soulbuddy/lib/features/commitments/application/commitment_memory_handoff.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_meditation_screen_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_listening_screen_test.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_memory_handoff_test.dart`
- Modify: `apps/soulbuddy/test/features/record/record_remember_flow_test.dart`

- [ ] **Step 1: Write failing session and Record tests**

Test Begin is explicit, guide captions, one bell, timer start after deliberate silence, pause/resume, End, no autoplay from notification, `PracticeAudioScope` background pause, `ScreenAwake` ownership, `sessionKind`, optional memory, selected local date, Encounter initially selected but changeable, written/audio memory save retry, and no automatic memory on Back.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_meditation_screen_test.dart test/features/commitments/commitment_listening_screen_test.dart test/features/commitments/commitment_memory_handoff_test.dart test/features/record/record_remember_flow_test.dart
```

Expected: missing screens/Record date and type-choice failures.

- [ ] **Step 3: Implement shared session screen**

Use `PracticeAudioScope` around `ScreenAwake` and the session controller. Preparation shows guide, duration, sound, optional prayer, and Begin. Guiding shows synchronized captions. Bell/silence are noninteractive phases. Timing shows only remaining time, pause/resume, and End. Listening adds its reviewed teaching/prompts and keeps all controls accessible.

- [ ] **Step 4: Implement the memory handoff**

Build a URI with `Uri` using:

```text
/remember/capture?mode=reflection&source=commitment&date=YYYY-MM-DD&prompt=What%20do%20you%20want%20to%20remember%20from%20this%20time%20with%20God%3F
```

Extend `RecordScreen` and `EncounterForm` with `initialOccurredOn`, `allowMemoryTypeChoice`, and `initialMemoryType`. Only `source=commitment` enables type choice and defaults to Encounter. Never place Commitment private text in the URI. Push the Record route so returning preserves the session end screen.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_meditation_screen_test.dart test/features/commitments/commitment_listening_screen_test.dart test/features/commitments/commitment_memory_handoff_test.dart test/features/record/record_remember_flow_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/presentation apps/soulbuddy/lib/features/commitments/application/commitment_memory_handoff.dart apps/soulbuddy/lib/features/record/presentation apps/soulbuddy/lib/app/router.dart apps/soulbuddy/test/features/commitments apps/soulbuddy/test/features/record/record_remember_flow_test.dart
git commit -m "feat: add commitment meditation and memory handoff"
```

---

### Task 16: Add the ten-day review card and readiness/listening handoffs

**Files:**
- Create: `apps/soulbuddy/lib/features/commitments/presentation/commitment_preparation_review_card.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/features/today/application/today_guidance_engine.dart`
- Modify: `apps/soulbuddy/lib/features/commitments/providers/commitment_providers.dart`
- Create: `apps/soulbuddy/test/features/commitments/commitment_preparation_review_test.dart`
- Modify: `apps/soulbuddy/test/features/today/today_prayer_test.dart`

- [ ] **Step 1: Write failing review tests**

Assert the card is absent before the tenth local date, present on/after the date, contains the exact non-spiritual-status copy, offers Revisit/Listen/Not now, updates cycle state without a score, routes Listening correctly, and does not force a route or block Today.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_preparation_review_test.dart test/features/today/today_prayer_test.dart
```

Expected: missing card/provider failures.

- [ ] **Step 3: Implement the factual review projection**

Compute the local review date from stored start date/timezone. Keep the card below the existing primary Today content and above lower optional sections. `Not now` records `deferred` but keeps the card available later. `Practice listening` records `listening_opened` and routes to `/commitments/:id/listen`.

- [ ] **Step 4: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_preparation_review_test.dart test/features/today/today_prayer_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/commitments/presentation/commitment_preparation_review_card.dart apps/soulbuddy/lib/features/today apps/soulbuddy/lib/features/commitments/providers/commitment_providers.dart apps/soulbuddy/test/features/commitments/commitment_preparation_review_test.dart apps/soulbuddy/test/features/today/today_prayer_test.dart
git commit -m "feat: add commitment preparation review"
```

---

### Task 17: Add credits, documentation, CI path coverage, and privacy invariants

**Files:**
- Create: `apps/soulbuddy/lib/features/settings/presentation/audio_credits_screen.dart`
- Modify: `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/test/architecture/product_invariants_test.dart`
- Modify: `.github/workflows/onboarding-goals.yml`
- Modify: `docs/architecture/local-first.md`
- Modify: `docs/architecture/seek-goals-tranche-0-invariants.md`
- Modify: `README.md`
- Create: `apps/soulbuddy/test/features/settings/audio_credits_screen_test.dart`

- [ ] **Step 1: Write failing credits and invariant tests**

Assert the exact Aphelion credit, official source link, five shell destinations, Commitment routes outside the shell, no private Commitment field names in logging/telemetry calls under `features/commitments`, and no private text in notification payload builders.

- [ ] **Step 2: Run tests and verify red**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/settings/audio_credits_screen_test.dart test/architecture/product_invariants_test.dart
```

Expected: missing credits route and invariant failures.

- [ ] **Step 3: Add the credits page**

Create `/settings/audio-credits` with the exact text **“Aphelion” by Scott Buckley — released under CC BY 4.0. www.scottbuckley.com.au** and a 48dp source link using the existing injectable `openUri` pattern. Add an **Audio credits** Settings row.

- [ ] **Step 4: Update architecture docs and CI**

Document that fresh users enter Commitment, legacy Goal progress remains, private formation data is local-first, static reviewed media is bundled, optional prayer narration remains consent-bound, and no runtime AI content is sent. Add all new Commitment, Goal, Laravel, asset, and platform files to the onboarding-goals workflow path filter.

- [ ] **Step 5: Run tests and commit**

```powershell
Set-Location apps/soulbuddy
flutter test test/features/settings/audio_credits_screen_test.dart test/architecture/product_invariants_test.dart
```

Expected: PASS.

```powershell
Set-Location ../..
git add apps/soulbuddy/lib/features/settings apps/soulbuddy/lib/app/router.dart apps/soulbuddy/test/features/settings/audio_credits_screen_test.dart apps/soulbuddy/test/architecture/product_invariants_test.dart .github/workflows/onboarding-goals.yml docs/architecture/local-first.md docs/architecture/seek-goals-tranche-0-invariants.md README.md
git commit -m "docs: document commitment formation privacy and media"
```

---

### Task 18: Add asset verification and full platform-focused integration tests

**Files:**
- Create: `scripts/commitments/verify_assets.py`
- Create: `apps/soulbuddy/test/features/commitments/commitment_asset_verification_test.dart`
- Create: `apps/soulbuddy/integration_test/commitment_journey_flow_test.dart`
- Create: `apps/soulbuddy/integration_test/commitment_meditation_android_test.dart`
- Create: `apps/soulbuddy/integration_test/commitment_notification_ios_test.dart`

- [ ] **Step 1: Write failing asset-verification tests**

The test invokes the Python verifier against the committed assets and asserts it returns a zero exit code and JSON containing every required asset ID, checksum, duration, transcript, and exact Aphelion interval. It must fail if the catalog references a missing file or if the Android/iOS notification copies differ.

- [ ] **Step 2: Implement the Python verifier**

`verify_assets.py` must parse `catalog_v1.json`, check every path, SHA-256, WAV/MP3 format, duration bounds, caption ordering, provenance, license/credit, and Android/iOS byte identity. It must exit nonzero with a sanitized asset ID on failure and never print private user data.

- [ ] **Step 3: Write focused integration flows**

The web flow covers invitation, optional readiness, practice picker, declaration, schedule, finish, summary, Goals, and Today practices. The Android flow covers permission, generic notification, sound packaging, tap routing, permission denial, schedule persistence, and meditation lifecycle. The iOS flow covers the same notification packaging and session routing on a configured simulator/device.

- [ ] **Step 4: Run verification and commit**

```powershell
Set-Location C:\dev\soulbuddy
python scripts/commitments/verify_assets.py
Set-Location apps/soulbuddy
flutter test test/features/commitments/commitment_asset_verification_test.dart
flutter build web --debug
flutter build apk --debug
```

Expected: asset verifier exit code 0; web and Android debug builds succeed.

```powershell
Set-Location ../..
git add scripts/commitments/verify_assets.py apps/soulbuddy/test/features/commitments/commitment_asset_verification_test.dart apps/soulbuddy/integration_test/commitment_journey_flow_test.dart apps/soulbuddy/integration_test/commitment_meditation_android_test.dart apps/soulbuddy/integration_test/commitment_notification_ios_test.dart
git commit -m "test: verify commitment formation journeys"
```

---

### Task 19: Run the full verification gate and review the diff

**Files:**
- Verify only; do not add unrelated changes.

- [ ] **Step 1: Run Flutter formatting and analysis**

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
```

Expected: PASS with no formatting or analyzer changes.

- [ ] **Step 2: Run all focused Flutter tests**

```powershell
flutter test test/features/commitments test/app/commitment_navigation_test.dart test/app/app_navigation_test.dart test/app/app_overlay_visibility_test.dart test/architecture/product_invariants_test.dart test/features/onboarding test/features/goals/commitment_practice_goal_test.dart test/features/goals/goal_repository_test.dart test/features/goals/goal_today_composer_test.dart test/features/record/record_remember_flow_test.dart test/features/settings/audio_credits_screen_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run Laravel formatting and focused tests**

```powershell
Set-Location C:\dev\soulbuddy\services\api
vendor\bin\pint --test
php artisan test tests/Feature/Commitments tests/Feature/Sync/CommitmentMutationTest.php tests/Feature/Sync/CommitmentMutationValidationTest.php tests/Feature/Sync/GoalMutationTest.php tests/Feature/Goals/GoalSchemaTest.php
```

Expected: PASS.

- [ ] **Step 4: Run asset, web, and repository verification**

```powershell
Set-Location C:\dev\soulbuddy
python scripts/commitments/verify_assets.py
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Expected: PASS for the asset verifier and the repository verification script.

- [ ] **Step 5: Review privacy and scope before final handoff**

```powershell
git diff origin/main --check
git status --short
git log --oneline --decorate -20
```

Confirm:

- no sixth shell destination;
- no private Commitment text in logs, analytics, notification payloads, sync issues, or TTS requests;
- no automatic memory or Goal completion;
- no background full-session service;
- no runtime AI-authored prayer/declaration;
- no score, streak, readiness certification, or comparative status;
- all local-only tables remain outside the sync queue;
- all new media has provenance and a required license credit.

Expected: clean worktree after the final verification commit, or only intentionally staged verification output.
