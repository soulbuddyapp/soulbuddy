# Telegram Launch Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a shared mobile and web flow that launches the SoulBuddy Telegram bot, explains the required Telegram action, and confirms the secure connection on return.

**Architecture:** The API issues a user-scoped, one-time link code and returns an opaque challenge ID. The web/mobile client holds only that ID, opens the public bot start URL, then queries a status endpoint after resuming. Telegram remains the only party that can consume a code through the secret-verified webhook.

**Tech Stack:** Flutter, Riverpod, `url_launcher`, Laravel 12, Pest, PostgreSQL/SQLite migrations, Telegram Bot HTTP API.

---

### Task 1: Add an owner-scoped Telegram link status API

**Files:**
- Modify: `services/api/app/Domain/Companions/TelegramLinkService.php`
- Modify: `services/api/app/Http/Controllers/Api/TelegramLinkCodeController.php`
- Create: `services/api/app/Http/Controllers/Api/TelegramLinkStatusController.php`
- Modify: `services/api/routes/api.php`
- Modify: `services/api/tests/Feature/Companions/TelegramLinkTest.php`

- [ ] **Step 1: Write failing feature tests for configuration, ownership, and state**

```php
it('does not issue a code until the Telegram bot username is configured', function () {
    [, $token] = telegramLinkSession();
    config()->set('services.telegram.bot_username', null);

    $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertServiceUnavailable();
    expect(DB::table('companion_link_codes')->count())->toBe(0);
});

it('returns only the issuing user\'s Telegram link state', function () {
    [, $firstToken] = telegramLinkSession();
    [, $secondToken] = telegramLinkSession();
    config()->set('services.telegram.bot_username', 'soul_buddy_bot');
    $id = $this->withToken($firstToken)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()->json('id');

    $this->withToken($secondToken)
        ->getJson("/api/companions/telegram/link-codes/{$id}")
        ->assertNotFound();
    $this->withToken($firstToken)
        ->getJson("/api/companions/telegram/link-codes/{$id}")
        ->assertOk()->assertJsonPath('status', 'pending');
});
```

- [ ] **Step 2: Run the tests and verify they fail because the API does not yet expose the behavior**

Run: `php artisan test tests/Feature/Companions/TelegramLinkTest.php`

Expected: failure for `503`, missing `id`, and missing status route.

- [ ] **Step 3: Return the opaque challenge ID and implement a status method**

```php
// TelegramLinkService.php
public function status(User $user, string $id): array
{
    $link = DB::table('companion_link_codes')
        ->where('id', $id)->where('user_id', $user->id)
        ->where('channel', 'telegram')->first();
    abort_if($link === null, 404);

    return [
        'id' => $link->id,
        'expires_at' => Carbon::parse($link->expires_at)->toIso8601String(),
        'status' => $link->consumed_at !== null ? 'connected'
            : (now()->greaterThan($link->expires_at) ? 'expired' : 'pending'),
    ];
}
```

```php
// routes/api.php
Route::get('/companions/telegram/link-codes/{id}', TelegramLinkStatusController::class)
    ->whereUuid('id')
    ->middleware('throttle:account-email-challenges');
```

`issue()` must check `services.telegram.bot_username` before creating a row and throw a `503` HTTP response when blank. Its success result must include `id`.

- [ ] **Step 4: Run the feature test and formatter**

Run: `php artisan test tests/Feature/Companions/TelegramLinkTest.php && ./vendor/bin/pint --dirty`

Expected: PASS with the original link, webhook, and new status tests.

- [ ] **Step 5: Commit the backend API**

```bash
git add services/api/app/Domain/Companions/TelegramLinkService.php \
  services/api/app/Http/Controllers/Api/TelegramLinkCodeController.php \
  services/api/app/Http/Controllers/Api/TelegramLinkStatusController.php \
  services/api/routes/api.php services/api/tests/Feature/Companions/TelegramLinkTest.php
git commit -m "feat: expose Telegram link status"
```

### Task 2: Extend the Flutter Telegram client for status checks

**Files:**
- Modify: `apps/soulbuddy/lib/core/identity/telegram_link_client.dart`
- Modify: `apps/soulbuddy/test/core/identity/telegram_link_client_test.dart`

- [ ] **Step 1: Write failing tests for challenge ID parsing and status requests**

```dart
test('reads the Telegram link state using the installation session', () async {
  final client = TelegramLinkClient(/* MockClient returns 200 */);
  final status = await client.status('challenge-id');

  expect(captured.url.path, '/api/companions/telegram/link-codes/challenge-id');
  expect(captured.headers['authorization'], 'Bearer installation-token');
  expect(status, TelegramLinkState.connected);
});
```

- [ ] **Step 2: Run the test and verify it fails because `status` and the state enum do not exist**

Run: `flutter test test/core/identity/telegram_link_client_test.dart`

Expected: compilation failure for missing `TelegramLinkState` and `status`.

- [ ] **Step 3: Add explicit link state types and robust response parsing**

```dart
enum TelegramLinkState { pending, connected, expired }

class TelegramLink {
  const TelegramLink({required this.id, required this.code, required this.expiresAt, required this.startUrl});
  final String id;
  // Existing fields remain.
}

Future<TelegramLinkState> status(String linkId) async {
  final response = await _authorizedGet('/api/companions/telegram/link-codes/$linkId');
  return TelegramLinkState.values.byName(_requiredString(response, 'status'));
}
```

Use the same session, timeout, unconfigured-API, and malformed-payload behavior as `createLink()`. Do not persist the code or start URL.

- [ ] **Step 4: Run the client test and analysis**

Run: `flutter test test/core/identity/telegram_link_client_test.dart && flutter analyze lib/core/identity/telegram_link_client.dart`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 5: Commit the client**

```bash
git add apps/soulbuddy/lib/core/identity/telegram_link_client.dart \
  apps/soulbuddy/test/core/identity/telegram_link_client_test.dart
git commit -m "feat: check Telegram link state"
```

### Task 3: Replace the Telegram button with a shared step guide

**Files:**
- Create: `apps/soulbuddy/lib/features/settings/presentation/telegram_launch_guide.dart`
- Modify: `apps/soulbuddy/lib/features/settings/presentation/telegram_link_section.dart`
- Modify: `apps/soulbuddy/test/features/settings/telegram_link_section_test.dart`

- [ ] **Step 1: Write failing widget tests for the guide and return confirmation**

```dart
testWidgets('shows the three Telegram steps before opening the bot', (tester) async {
  await tester.pumpWidget(host(createLink: pendingLink, openUri: opened.add));
  await tester.tap(find.text('Connect Telegram'));
  await tester.pumpAndSettle();

  expect(find.text('1. Open SoulBuddy on Telegram'), findsOneWidget);
  expect(find.text('2. Select Start'), findsOneWidget);
  expect(find.text('3. Return after the confirmation message'), findsOneWidget);
  expect(opened, isEmpty);
});

testWidgets('confirms a consumed link when the app resumes', (tester) async {
  final observer = TestWidgetsFlutterBinding.ensureInitialized();
  await tester.pumpWidget(host(status: (_) async => TelegramLinkState.connected));
  await tester.tap(find.text('Open Telegram'));
  observer.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();

  expect(find.text('Telegram connected.'), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget tests and verify they fail because the guide does not exist**

Run: `flutter test test/features/settings/telegram_link_section_test.dart`

Expected: compilation failure for `TelegramLaunchGuide` and the new step labels.

- [ ] **Step 3: Implement a reusable lifecycle-aware guide**

```dart
class TelegramLaunchGuide extends StatefulWidget {
  const TelegramLaunchGuide({required this.link, required this.openUri, required this.status, super.key});
  final TelegramLink link;
  final Future<bool> Function(Uri) openUri;
  final Future<TelegramLinkState> Function(String) status;
}

class _TelegramLaunchGuideState extends State<TelegramLaunchGuide>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }
}
```

The guide must show the three approved instructions, a primary `Open Telegram` action, an explicit `Check connection` action, and concise states for connected, pending, expired, unavailable, and open failure. The section creates a fresh link before opening the guide. Use the existing card/theme/spacing primitives. All new copy must follow the repository-wide product-copy rule.

- [ ] **Step 4: Run widget tests, focused analysis, and the combined Flutter suite**

Run: `flutter test test/features/settings/telegram_link_section_test.dart test/core/identity/telegram_link_client_test.dart && flutter analyze lib/features/settings/presentation/telegram_launch_guide.dart lib/features/settings/presentation/telegram_link_section.dart lib/core/identity/telegram_link_client.dart`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 5: Commit the guide**

```bash
git add apps/soulbuddy/lib/features/settings/presentation/telegram_launch_guide.dart \
  apps/soulbuddy/lib/features/settings/presentation/telegram_link_section.dart \
  apps/soulbuddy/test/features/settings/telegram_link_section_test.dart
git commit -m "feat: guide Telegram companion launch"
```

### Task 4: Verify the complete flow

**Files:**
- Verify only.

- [ ] **Step 1: Run the focused backend verification**

Run: `php artisan test tests/Feature/Accounts/VerifiedAccountTest.php tests/Feature/Auth/InstallationSessionTest.php tests/Feature/Companions/TelegramLinkTest.php tests/Feature/Notifications/MorningNotificationTest.php && ./vendor/bin/pint --test`

Expected: PASS.

- [ ] **Step 2: Run the focused Flutter verification**

Run: `flutter test test/core/identity/account_email_link_client_test.dart test/core/identity/telegram_link_client_test.dart test/features/settings/account_email_link_section_test.dart test/features/settings/telegram_link_section_test.dart && flutter analyze lib/core/identity`

Expected: PASS with no analyzer diagnostics.

- [ ] **Step 3: Confirm the working tree is reviewable**

Run: `git diff --check && git status --short && git log --oneline -6`

Expected: no whitespace errors and no uncommitted implementation files.
