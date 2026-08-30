# Goal Action Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Use the user's reviewed first-Goal context to offer safe practical action choices, with a reviewed local fallback and no generated spiritual content.

**Architecture:** Keep Goal navigation in the existing onboarding state machine. Add a provider-neutral suggestion domain and repository, compose immediate local suggestions with an authenticated Laravel result, and render them in a focused panel owned by the Today-action page. The Laravel boundary calls a configured OpenAI-compatible provider, validates the response, and never logs prompt content.

**Tech Stack:** Flutter, Riverpod, `http`, Laravel 12, Sanctum, Laravel HTTP client, Pest.

---

### Task 1: Domain contract and reviewed local fallback

**Files:**
- Create: `apps/soulbuddy/lib/features/goals/domain/goal_action_suggestion.dart`
- Create: `apps/soulbuddy/lib/features/goals/data/goal_action_suggestion_repository.dart`
- Create: `apps/soulbuddy/lib/features/goals/data/reviewed_goal_action_suggestions.dart`
- Test: `apps/soulbuddy/test/features/goals/goal_action_suggestion_test.dart`

- [ ] **Step 1: Write failing tests for normalization and fallback selection**

```dart
test('returns reviewed closer-to-God choices without spiritual claims', () {
  final result = reviewedGoalActionSuggestions(
    const GoalActionSuggestionRequest(
      starterKey: GoalStarterKey.closerToGod,
      title: 'Grow closer to God',
      situation: 'I rush through every morning',
      agencyChoice: GoalAgencyChoice.notSure,
      locale: 'en',
    ),
  );
  expect(result, hasLength(3));
  expect(result.map((item) => item.text), contains('Set aside ten quiet minutes before opening another app'));
});
```

- [ ] **Step 2: Run `flutter test test/features/goals/goal_action_suggestion_test.dart` and confirm it fails because the contract does not exist.**
- [ ] **Step 3: Implement immutable request/suggestion values, repository interface, 160-character normalization, and starter/behavior-keyed reviewed choices.**
- [ ] **Step 4: Re-run the focused test and confirm it passes.**
- [ ] **Step 5: Commit with `feat: add reviewed goal action suggestions`.**

### Task 2: Authenticated Laravel suggestion boundary

**Files:**
- Create: `services/api/app/Domain/GoalGuidance/GoalActionSuggestionProvider.php`
- Create: `services/api/app/Domain/GoalGuidance/GoalActionSuggestionService.php`
- Create: `services/api/app/Domain/GoalGuidance/OpenAiCompatibleGoalActionSuggestionProvider.php`
- Create: `services/api/app/Http/Requests/SuggestGoalActionsRequest.php`
- Create: `services/api/app/Http/Controllers/Api/GoalActionSuggestionController.php`
- Modify: `services/api/app/Providers/AppServiceProvider.php`
- Modify: `services/api/config/services.php`
- Modify: `services/api/.env.example`
- Modify: `services/api/routes/api.php`
- Modify: `services/api/tests/Architecture/SyntheticSpiritualContentTest.php`
- Test: `services/api/tests/Feature/Goals/GoalActionSuggestionTest.php`

- [ ] **Step 1: Write failing feature tests proving authentication, throttling, request limits, three-item normalization, and rejection of prayer/Scripture/divine-claim output.**

```php
it('returns only safe practical actions', function () {
    $provider = Mockery::mock(GoalActionSuggestionProvider::class);
    $provider->shouldReceive('suggest')->once()->andReturn([
        'Put the phone outside the bedroom tonight.',
        'Write the decision factors on one page.',
        'Ask a trusted person for fifteen minutes to talk.',
    ]);
    app()->instance(GoalActionSuggestionProvider::class, $provider);

    $this->actingAs(User::factory()->create())
        ->postJson('/api/goal-action-suggestions', [
            'starter_key' => 'direction',
            'title' => 'Find direction',
            'situation' => 'I am choosing between two paths.',
            'agency_choice' => 'not_sure',
            'locale' => 'en',
        ])
        ->assertOk()
        ->assertJsonCount(3, 'suggestions');
});
```

- [ ] **Step 2: Run `php artisan test --filter=GoalActionSuggestionTest` and confirm missing route/provider failures.**
- [ ] **Step 3: Implement the request, controller, service, provider contract, generic provider configuration, 10-second timeout, no retries, content-free exceptions, and per-user/per-IP rate limits.**
- [ ] **Step 4: Update the architecture test so it still prohibits generated prayer surfaces while permitting the isolated practical-action provider.**
- [ ] **Step 5: Run the feature and architecture tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: add safe goal action suggestion api`.**

### Task 3: Flutter remote repository and fallback composition

**Files:**
- Create: `apps/soulbuddy/lib/features/goals/data/laravel_goal_action_suggestion_repository.dart`
- Create: `apps/soulbuddy/lib/features/goals/data/fallback_goal_action_suggestion_repository.dart`
- Create: `apps/soulbuddy/lib/features/goals/providers/goal_action_suggestion_providers.dart`
- Test: `apps/soulbuddy/test/features/goals/goal_action_suggestion_repository_test.dart`

- [ ] **Step 1: Write failing tests for authenticated JSON mapping, timeout fallback, invalid-response fallback, and no raw-text logging.**
- [ ] **Step 2: Run `flutter test test/features/goals/goal_action_suggestion_repository_test.dart` and confirm missing implementation failures.**
- [ ] **Step 3: Implement a repository that emits reviewed local choices immediately and replaces them with a valid remote set only when the caller has not locked a selection. Use the existing installation token reader and `AppConfig.apiBaseUrl`.**
- [ ] **Step 4: Re-run the repository tests and confirm they pass.**
- [ ] **Step 5: Commit with `feat: connect goal action suggestions`.**

### Task 4: First Goal copy and suggestion panel

**Files:**
- Create: `apps/soulbuddy/lib/features/goals/presentation/goal_action_suggestion_panel.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/first_goal_screen.dart`
- Modify: `apps/soulbuddy/test/features/goals/first_goal_screen_test.dart`

- [ ] **Step 1: Add failing widget tests for the new question on Speak/Write/choice surfaces, automatic suggestions after `I'm not sure`, optional suggestions otherwise, manual editing, and 200% text scaling.**
- [ ] **Step 2: Run `flutter test test/features/goals/first_goal_screen_test.dart` and confirm copy/widget failures.**
- [ ] **Step 3: Replace every situation heading with `Why now? What needs to change?`, retain editable speech text, and render the panel without blocking Write or Not now.**
- [ ] **Step 4: Ensure selecting a suggestion writes only its text into the existing Today-action value and does not persist discarded choices.**
- [ ] **Step 5: Re-run the focused widget tests and confirm they pass.**
- [ ] **Step 6: Commit with `feat: guide first goal actions from user context`.**

### Task 5: Slice verification

**Files:**
- Modify only if verification exposes a regression.

- [ ] **Step 1: Run `dart format --output=none --set-exit-if-changed lib test` from `apps/soulbuddy`.**
- [ ] **Step 2: Run `flutter analyze` from `apps/soulbuddy`.**
- [ ] **Step 3: Run `flutter test test/features/goals test/architecture/product_invariants_test.dart`.**
- [ ] **Step 4: Run `php artisan test --testsuite=Feature --filter=Goal` and `php artisan test tests/Architecture/SyntheticSpiritualContentTest.php` from `services/api`.**
- [ ] **Step 5: Commit any test-proven corrections with `fix: verify goal action guidance`.**

