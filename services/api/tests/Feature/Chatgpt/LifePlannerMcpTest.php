<?php

use App\Models\User;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

afterEach(function () {
    JWT::$timestamp = null;
});

function configureChatgptTestOAuth(array $introspectionResponses = []): string
{
    config()->set('app.url', 'https://sbuddy.elbiblio.com');
    config()->set('services.chatgpt.issuer', 'https://issuer.example/');
    config()->set('services.chatgpt.audience', 'https://sbuddy.elbiblio.com/mcp');
    config()->set('services.chatgpt.jwks_url', 'https://issuer.example/jwks.json');
    config()->set('services.chatgpt.introspection_url', 'https://issuer.example/introspect');
    config()->set('services.chatgpt.introspection_client_id', 'resource-client');
    config()->set('services.chatgpt.introspection_client_secret', 'test-secret');
    config()->set('services.chatgpt.email_claim', 'https://soulbuddy.app/email');
    config()->set('services.chatgpt.email_verified_claim', 'https://soulbuddy.app/email_verified');
    Cache::flush();

    $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_RSA, 'private_key_bits' => 2048]);
    openssl_pkey_export($key, $pem);
    $rsa = openssl_pkey_get_details($key)['rsa'];
    // The default provider introspection follows the token's subject. Explicit
    // queued overrides simulate revocation, malformed answers and outages.
    $queuedResponses = $introspectionResponses;
    Http::fake(function (\Illuminate\Http\Client\Request $request) use (&$queuedResponses, $rsa) {
        if ($request->url() === 'https://issuer.example/jwks.json') {
            return Http::response(['keys' => [[
                'kty' => 'RSA', 'alg' => 'RS256', 'use' => 'sig',
                'kid' => 'soulbuddy-test-key',
                'n' => JWT::urlsafeB64Encode($rsa['n']),
                'e' => JWT::urlsafeB64Encode($rsa['e']),
            ]]]);
        }
        if ($request->url() === 'https://issuer.example/introspect') {
            if ($queuedResponses !== []) {
                $next = array_shift($queuedResponses);
                if ($next['connection_failure'] ?? false) {
                    throw new \Illuminate\Http\Client\ConnectionException('Simulated provider outage');
                }

                return Http::response($next['body'], $next['status']);
            }

            $parts = explode('.', (string) ($request['token'] ?? ''));
            $claims = count($parts) === 3
                ? json_decode(JWT::urlsafeB64Decode($parts[1]), true)
                : [];

            return Http::response(['active' => true, 'sub' => $claims['sub'] ?? null]);
        }

        return Http::response([], 404);
    });

    return $pem;
}

function chatgptTestBearer(string $pem, string $email, string $scope = 'life.read life.write', array $overrides = []): array
{
    $claims = array_merge([
        'iss' => 'https://issuer.example/',
        'aud' => 'https://sbuddy.elbiblio.com/mcp',
        'sub' => 'auth0|person',
        'iat' => now()->timestamp,
        'exp' => now()->addMinutes(15)->timestamp,
        'scope' => $scope,
        'https://soulbuddy.app/email' => $email,
        'https://soulbuddy.app/email_verified' => true,
    ], $overrides);

    return ['Authorization' => 'Bearer '.JWT::encode($claims, $pem, 'RS256', 'soulbuddy-test-key')];
}

function chatgptBindTestIdentity(
    string $email,
    string $subject = 'auth0|person',
    string $issuer = 'https://issuer.example/',
    ?User $existing = null,
): User {
    $user = $existing ?? User::factory()->create([
        'email' => $email,
        'email_verified_at' => now(),
    ]);
    DB::table('chatgpt_oauth_identities')->insert([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'issuer' => $issuer,
        'subject' => $subject,
        'identity_hash' => hash('sha256', $issuer."\0".$subject),
        'issuer_hash' => hash('sha256', $issuer),
        'created_at' => now(),
        'updated_at' => now(),
    ]);

    return $user;
}

function chatgptTestPlan(): array
{
    return [
        'request_id' => (string) Str::uuid(),
        'confirmed' => true,
        'focus' => 'Grow in responsibility, prayer and care for family',
        'starts_on' => now('UTC')->toDateString(),
        'timezone' => 'UTC',
        'items' => array_map(fn (int $day): array => [
            'day' => $day,
            'domain' => 'self_examination',
            'title' => 'Reflect on how I treated other people',
            'minutes' => 8,
        ], range(0, 6)),
    ];
}

function chatgptTestCall(string $name, array $arguments = [], int $id = 1): array
{
    return [
        'jsonrpc' => '2.0',
        'id' => $id,
        'method' => 'tools/call',
        'params' => ['name' => $name, 'arguments' => $arguments],
    ];
}

it('advertises discovery, MCP handshake and accurate auth metadata without credentials', function () {
    configureChatgptTestOAuth();

    $this->getJson('/.well-known/oauth-protected-resource')
        ->assertOk()->assertJsonPath('resource', 'https://sbuddy.elbiblio.com/mcp')
        ->assertJsonPath('authorization_servers.0', 'https://issuer.example/');

    $this->getJson('/.well-known/oauth-protected-resource/mcp')
        ->assertOk()->assertJsonPath('resource', 'https://sbuddy.elbiblio.com/mcp')
        ->assertJsonPath('authorization_servers.0', 'https://issuer.example/');

    $initialized = $this->postJson('/mcp', [
        'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize',
        'params' => ['protocolVersion' => '2025-11-25'],
    ])->assertOk()->assertJsonPath('result.serverInfo.name', 'soulbuddy-life-planner');
    expect($initialized->json('result.instructions'))
        ->toContain('get_daily_life_plan')
        ->toContain('consent')
        ->toContain('time zone')
        ->toContain('generic')
        ->toContain('get_connection_management')
        ->toContain('confirmed');

    $listed = $this->postJson('/mcp', [
        'jsonrpc' => '2.0', 'id' => 2, 'method' => 'tools/list',
    ])->assertOk();
    expect(collect($listed->json('result.tools'))->pluck('name')->all())
        ->toContain('get_planning_guide', 'create_seven_day_plan', 'record_daily_checkin', 'review_week');
    $create = collect($listed->json('result.tools'))->firstWhere('name', 'create_seven_day_plan');
    expect($create['securitySchemes'][0]['scopes'])->toBe(['life.write'])
        ->and($create['inputSchema']['required'])->toContain('confirmed');

    $this->postJson('/mcp', [
        'jsonrpc' => '2.0', 'method' => 'notifications/initialized',
    ])->assertStatus(202);
});

it('does not expose private plans without a verified scoped bearer', function () {
    $pem = configureChatgptTestOAuth();
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'))->assertOk()
        ->assertJsonPath('result.isError', true)
        ->assertJsonStructure(['result' => ['_meta' => ['mcp/www_authenticate']]]);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), chatgptTestBearer(
        $pem, 'private@example.com', 'life.read', ['aud' => 'another-service']
    ))->assertJsonPath('result.isError', true);

    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', chatgptTestPlan()),
        chatgptTestBearer($pem, 'private@example.com', 'life.read')
    )->assertJsonPath('result.isError', true);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), chatgptTestBearer(
        $pem, 'private@example.com', 'life.read', ['https://soulbuddy.app/email_verified' => false]
    ))->assertJsonPath('result.isError', true);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), chatgptTestBearer(
        $pem, 'private@example.com', 'life.read', ['exp' => null]
    ))->assertJsonPath('result.isError', true);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), chatgptTestBearer(
        $pem, 'private@example.com', 'life.read', ['exp' => now()->addHours(25)->timestamp]
    ))->assertJsonPath('result.isError', true);

    expect(DB::table('life_plans')->count())->toBe(0);
});

it('returns a concise empty-plan result without instructions to the assistant', function () {
    $pem = configureChatgptTestOAuth();
    chatgptBindTestIdentity('empty-plan@example.com');
    $response = $this->postJson('/mcp', chatgptTestCall('get_life_plan'),
        chatgptTestBearer($pem, 'empty-plan@example.com', 'life.read')
    )->assertOk()->assertJsonPath('result.structuredContent.plan', null)
        ->assertJsonPath('result.structuredContent.message', 'No seven-day plan yet.');

    expect($response->json('result.content.0.text'))->not->toContain('Ask the person');
});

it('offers provider access controls without requiring an active connection', function () {
    configureChatgptTestOAuth();
    config()->set('services.chatgpt.account_management_url', 'https://issuer.example/realm/account/');
    $listed = $this->postJson('/mcp', ['jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list'])->json('result.tools');
    $tool = collect($listed)->firstWhere('name', 'get_connection_management');
    expect($tool)->not->toBeNull()
        ->and($tool['securitySchemes'])->toBe([['type' => 'noauth']])
        ->and($tool['annotations']['readOnlyHint'])->toBeTrue();

    $this->postJson('/mcp', chatgptTestCall('get_connection_management'))
        ->assertOk()
        ->assertJsonPath('result.structuredContent.status', 'available')
        ->assertJsonPath('result.structuredContent.url', 'https://issuer.example/realm/account/');
});

it('does not return an unsafe or unconfigured provider access link', function () {
    configureChatgptTestOAuth();
    foreach ([null, 'http://issuer.example/account', 'https://evil.example/account',
        'https://user@issuer.example/account', 'https://issuer.example:444/account',
        'https://issuer.example/account?token=unsafe', 'https://issuer.example/account#fragment'] as $url) {
        config()->set('services.chatgpt.account_management_url', $url);
        $this->postJson('/mcp', chatgptTestCall('get_connection_management'))
            ->assertOk()->assertJsonPath('result.structuredContent.status', 'unavailable')
            ->assertJsonMissingPath('result.structuredContent.url');
    }
    config()->set('services.chatgpt.account_management_url', 'https://issuer.example/account');
    config()->set('services.chatgpt.issuer', 'https://user@issuer.example/realm');
    $this->postJson('/mcp', chatgptTestCall('get_connection_management'))
        ->assertJsonPath('result.structuredContent.status', 'unavailable');
    config()->set('services.chatgpt.issuer', 'https://issuer.example/');
    config()->set('services.chatgpt.introspection_url', null);
    $this->postJson('/mcp', chatgptTestCall('get_connection_management'))
        ->assertJsonPath('result.structuredContent.status', 'unavailable');
});

it('advertises a scoped read-only daily plan and distinguishes an absent plan from an auth failure', function () {
    $pem = configureChatgptTestOAuth();
    $listed = $this->postJson('/mcp', ['jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list'])->json('result.tools');
    $daily = collect($listed)->firstWhere('name', 'get_daily_life_plan');
    expect($daily)->not->toBeNull()
        ->and($daily['securitySchemes'][0]['scopes'])->toBe(['life.read'])
        ->and($daily['annotations']['readOnlyHint'])->toBeTrue();

    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'))
        ->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), chatgptTestBearer($pem, 'empty-daily@example.com', 'life.write'))
        ->assertJsonPath('result.isError', true);
    chatgptBindTestIdentity('empty-daily@example.com');
    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), chatgptTestBearer($pem, 'empty-daily@example.com', 'life.read'))
        ->assertJsonPath('result.structuredContent.state', 'no_plan');
});

it('returns only the owner’s current local-day commitments without private notes', function () {
    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-10-28 00:30:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $pem = configureChatgptTestOAuth();
    chatgptBindTestIdentity('daily-owner@example.com');
    chatgptBindTestIdentity('other-daily@example.com', 'auth0|other-daily');
    $auth = chatgptTestBearer($pem, 'daily-owner@example.com');
    $payload = chatgptTestPlan();
    $payload['starts_on'] = '2026-10-28';
    $payload['timezone'] = 'America/Los_Angeles';
    $created = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $payload), $auth)
        ->assertOk();
    $itemId = $created->json('result.structuredContent.items.0.id');
    expect($itemId)->not->toBeNull();

    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.state', 'upcoming')
        ->assertJsonPath('result.structuredContent.starts_on', '2026-10-28');
    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), chatgptTestBearer($pem, 'other-daily@example.com', 'life.read', ['sub' => 'auth0|other-daily']))
        ->assertJsonPath('result.structuredContent.state', 'no_plan');

    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-10-28 07:30:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $auth = chatgptTestBearer($pem, 'daily-owner@example.com');
    $this->postJson('/mcp', chatgptTestCall('record_daily_checkin', [
        'item_id' => $itemId, 'outcome' => 'partial', 'note' => 'Private check-in', 'confirmed' => true,
    ]), $auth)->assertJsonPath('result.structuredContent.items.0.outcome', 'partial');
    $daily = $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.state', 'today')
        ->assertJsonPath('result.structuredContent.date', '2026-10-28')
        ->assertJsonPath('result.structuredContent.timezone', 'America/Los_Angeles')
        ->assertJsonPath('result.structuredContent.items.0.outcome', 'partial')
        ->assertJsonCount(1, 'result.structuredContent.items')
        ->assertJsonMissingPath('result.structuredContent.items.0.note')
        ->assertJsonMissingPath('result.structuredContent.review');
    expect($daily->getContent())->not->toContain('Private check-in');

    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-11-03 08:30:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), chatgptTestBearer($pem, 'daily-owner@example.com', 'life.read'))
        ->assertJsonPath('result.structuredContent.state', 'today')
        ->assertJsonPath('result.structuredContent.date', '2026-11-03');
    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-11-04 08:30:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $this->postJson('/mcp', chatgptTestCall('get_daily_life_plan'), chatgptTestBearer($pem, 'daily-owner@example.com', 'life.read'))
        ->assertJsonPath('result.structuredContent.state', 'finished')
        ->assertJsonPath('result.structuredContent.ends_on', '2026-11-03');
});

it('saves idempotent plans, scopes access and records reversible observations rather than spiritual scores', function () {
    $pem = configureChatgptTestOAuth();
    $a = User::factory()->create(['email' => 'a@example.com', 'email_verified_at' => now()]);
    $b = User::factory()->create(['email' => 'b@example.com', 'email_verified_at' => now()]);
    chatgptBindTestIdentity('a@example.com', 'auth0|person', 'https://issuer.example/', $a);
    chatgptBindTestIdentity('b@example.com', 'auth0|person-b', 'https://issuer.example/', $b);
    $authA = chatgptTestBearer($pem, 'a@example.com');
    $authB = chatgptTestBearer($pem, 'b@example.com', 'life.read life.write', ['sub' => 'auth0|person-b']);
    $payload = chatgptTestPlan();

    $created = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $payload), $authA)
        ->assertOk()->assertJsonPath('result.structuredContent.plan.focus', $payload['focus']);
    $planId = $created->json('result.structuredContent.plan.id');
    $itemId = $created->json('result.structuredContent.items.0.id');
    expect(DB::table('life_plans')->where('user_id', $a->id)->count())->toBe(1)
        ->and(DB::table('life_plan_items')->where('plan_id', $planId)->count())->toBe(7);

    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $payload), $authA)
        ->assertJsonPath('result.structuredContent.plan.id', $planId);
    expect(DB::table('life_plans')->count())->toBe(1);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $authB)
        ->assertJsonPath('result.structuredContent.plan', null);
    $this->postJson('/mcp', chatgptTestCall('record_daily_checkin', [
        'item_id' => $itemId, 'outcome' => 'done', 'confirmed' => true,
    ]), $authB)->assertJsonPath('result.isError', true);

    $this->postJson('/mcp', chatgptTestCall('record_daily_checkin', [
        'item_id' => $itemId, 'outcome' => 'done', 'confirmed' => true,
    ]), $authA)->assertJsonPath('result.structuredContent.items.0.outcome', 'done');
    $this->postJson('/mcp', chatgptTestCall('record_daily_checkin', [
        'item_id' => $itemId, 'outcome' => 'partial', 'note' => 'I need a quieter time.', 'confirmed' => true,
    ]), $authA)->assertJsonPath('result.structuredContent.items.0.outcome', 'partial');
    expect(DB::table('life_plan_checkins')->where('item_id', $itemId)->count())->toBe(1);

    $this->postJson('/mcp', chatgptTestCall('review_week'), $authA)
        ->assertJsonPath('result.structuredContent.outcomes.partial', 1)
        ->assertJsonMissingPath('result.structuredContent.holiness_score');

    $this->postJson('/mcp', chatgptTestCall('save_weekly_review', [
        'plan_id' => $planId,
        'reflection' => 'I was more thoughtful with my time and family today.',
        'next_adjustment' => 'Move reflection to after supper.',
        'confirmed' => true,
    ]), $authA)->assertJsonPath('result.structuredContent.review.next_adjustment', 'Move reflection to after supper.');

    $this->postJson('/mcp', chatgptTestCall('delete_life_plan', [
        'plan_id' => $planId, 'confirmed' => true,
    ]), $authB)->assertJsonPath('result.structuredContent.deleted', false);
    $this->postJson('/mcp', chatgptTestCall('delete_life_plan', [
        'plan_id' => $planId, 'confirmed' => true,
    ]), $authA)->assertJsonPath('result.structuredContent.deleted', true);
    expect(DB::table('life_plan_items')->count())->toBe(0)
        ->and(DB::table('life_plan_checkins')->count())->toBe(0)
        ->and(DB::table('life_plan_reviews')->count())->toBe(0);
});

it('refuses unapproved changes, incomplete weeks and unverified local accounts', function () {
    $pem = configureChatgptTestOAuth();
    User::factory()->unverified()->create(['email' => 'unverified@example.com']);

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'),
        chatgptTestBearer($pem, 'unverified@example.com')
    )->assertJsonPath('result.isError', true);

    chatgptBindTestIdentity('newperson@example.com');
    $auth = chatgptTestBearer($pem, 'newperson@example.com');
    $bad = chatgptTestPlan();
    $bad['confirmed'] = false;
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $bad), $auth)
        ->assertJsonPath('result.isError', true);
    $bad['confirmed'] = true;
    array_pop($bad['items']);
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $bad), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('life_plans')->count())->toBe(0);
});

it('does not advertise account linking until an identity provider is configured', function () {
    config()->set('services.chatgpt.issuer', null);
    config()->set('services.chatgpt.audience', null);
    config()->set('services.chatgpt.jwks_url', null);

    $this->getJson('/.well-known/oauth-protected-resource')->assertStatus(503);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'))
        ->assertJsonPath('result.isError', true);
});

it('lets an owner find, inspect and delete archived plans without exposing them to another account', function () {
    $pem = configureChatgptTestOAuth();
    chatgptBindTestIdentity('history-a@example.com');
    chatgptBindTestIdentity('history-b@example.com', 'auth0|history-b');
    $authA = chatgptTestBearer($pem, 'history-a@example.com');
    $authB = chatgptTestBearer($pem, 'history-b@example.com', 'life.read life.write', ['sub' => 'auth0|history-b']);
    $first = chatgptTestPlan();
    $old = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $first), $authA)
        ->json('result.structuredContent.plan.id');
    $second = chatgptTestPlan();
    $second['replace_active'] = true;
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $second), $authA)
        ->assertJsonPath('result.structuredContent.plan.archived', false);

    $this->postJson('/mcp', chatgptTestCall('list_life_plans'), $authA)
        ->assertJsonCount(2, 'result.structuredContent.plans')
        ->assertJsonFragment(['id' => $old, 'archived' => true]);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan', ['plan_id' => $old]), $authA)
        ->assertJsonPath('result.structuredContent.plan.id', $old)
        ->assertJsonPath('result.structuredContent.plan.archived', true);
    $this->postJson('/mcp', chatgptTestCall('list_life_plans'), $authB)
        ->assertJsonCount(0, 'result.structuredContent.plans');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan', ['plan_id' => $old]), $authB)
        ->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('delete_life_plan', ['plan_id' => $old, 'confirmed' => true]), $authA)
        ->assertJsonPath('result.structuredContent.deleted', true);
    $this->postJson('/mcp', chatgptTestCall('list_life_plans'), $authA)
        ->assertJsonCount(1, 'result.structuredContent.plans');
});

it('advertises explicit and accurate safety annotations on every tool', function () {
    $listed = $this->postJson('/mcp', ['jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list'])->json('result.tools');
    foreach ($listed as $tool) {
        expect($tool['annotations'])->toHaveKeys(['readOnlyHint', 'destructiveHint', 'openWorldHint']);
        foreach ($tool['annotations'] as $value) {
            expect($value)->toBeBool();
        }
    }
    foreach (['create_seven_day_plan', 'record_daily_checkin', 'save_weekly_review', 'delete_life_plan'] as $name) {
        expect(collect($listed)->firstWhere('name', $name)['annotations']['destructiveHint'])->toBeTrue();
    }
});

it('paginates plan history without including another owner’s records', function () {
    $pem = configureChatgptTestOAuth();
    $owner = User::factory()->create(['email' => 'paged@example.com', 'email_verified_at' => now()]);
    chatgptBindTestIdentity('paged@example.com', 'auth0|person', 'https://issuer.example/', $owner);
    $other = User::factory()->create(['email' => 'other@example.com', 'email_verified_at' => now()]);
    foreach (range(1, 21) as $number) {
        DB::table('life_plans')->insert([
            'id' => (string) Str::uuid(), 'user_id' => $owner->id, 'request_id' => (string) Str::uuid(),
            'focus' => 'Plan '.$number, 'starts_on' => now()->toDateString(), 'timezone' => 'UTC',
            'archived_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }
    DB::table('life_plans')->insert([
        'id' => (string) Str::uuid(), 'user_id' => $other->id, 'request_id' => (string) Str::uuid(),
        'focus' => 'Other person', 'starts_on' => now()->toDateString(), 'timezone' => 'UTC',
        'created_at' => now(), 'updated_at' => now(),
    ]);
    $auth = chatgptTestBearer($pem, 'paged@example.com', 'life.read');
    $first = $this->postJson('/mcp', chatgptTestCall('list_life_plans'), $auth)
        ->assertJsonCount(20, 'result.structuredContent.plans')
        ->assertJsonPath('result.structuredContent.next_page', 2)
        ->json('result.structuredContent.plans');
    $second = $this->postJson('/mcp', chatgptTestCall('list_life_plans', ['page' => 2]), $auth)
        ->assertJsonCount(1, 'result.structuredContent.plans')
        ->assertJsonPath('result.structuredContent.next_page', null)
        ->json('result.structuredContent.plans');
    expect(collect(array_merge($first, $second))->pluck('id')->unique()->count())->toBe(21)
        ->and(collect(array_merge($first, $second))->pluck('focus'))->not->toContain('Other person');
});

it('uses the configured issuer exactly including its trailing slash', function () {
    $pem = configureChatgptTestOAuth();
    config()->set('services.chatgpt.issuer', 'https://issuer.example');
    chatgptBindTestIdentity('exact-issuer@example.com', 'auth0|person', 'https://issuer.example');
    $this->getJson('/.well-known/oauth-protected-resource')
        ->assertJsonPath('authorization_servers.0', 'https://issuer.example');
    $auth = chatgptTestBearer($pem, 'exact-issuer@example.com', 'life.read', ['iss' => 'https://issuer.example']);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.plan', null);
});

it('checks every valid token against the issuer and refuses a token after revocation', function () {
    $pem = configureChatgptTestOAuth([
        ['status' => 200, 'body' => ['active' => true, 'sub' => 'auth0|person']],
        ['status' => 200, 'body' => ['active' => false]],
    ]);
    chatgptBindTestIdentity('revoked@example.com');
    $auth = chatgptTestBearer($pem, 'revoked@example.com', 'life.read');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.plan', null);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.isError', true);
    Http::assertSentCount(3); // One JWKS request and one introspection per call.
    Http::assertSent(fn ($request) => $request->url() === 'https://issuer.example/introspect'
        && $request->method() === 'POST' && $request->hasHeader('Authorization', 'Basic '.base64_encode('resource-client:test-secret'))
        && ($request['token'] ?? '') === substr($auth['Authorization'], 7));
});

it('fails closed when introspection fails, is malformed or reports a different subject', function () {
    $pem = configureChatgptTestOAuth([
        ['status' => 503, 'body' => []],
        ['status' => 302, 'body' => ['active' => true, 'sub' => 'auth0|person']],
        ['connection_failure' => true],
        ['status' => 200, 'body' => ['active' => 'true', 'sub' => 'auth0|person']],
        ['status' => 200, 'body' => ['active' => true, 'sub' => 'someone-else']],
    ]);
    chatgptBindTestIdentity('fail-closed@example.com');
    $auth = chatgptTestBearer($pem, 'fail-closed@example.com', 'life.read');
    foreach (range(1, 5) as $attempt) {
        $this->postJson('/mcp', chatgptTestCall('get_life_plan', [], $attempt), $auth)
            ->assertJsonPath('result.isError', true);
    }
    expect(User::query()->where('email', 'fail-closed@example.com')->exists())->toBeTrue()
        ->and(DB::table('life_plans')->count())->toBe(0);
});

it('does not enable protected access without secure introspection configuration', function () {
    $pem = configureChatgptTestOAuth();
    config()->set('services.chatgpt.introspection_url', 'http://issuer.example/introspect');
    $this->getJson('/.well-known/oauth-protected-resource')->assertStatus(503);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), chatgptTestBearer($pem, 'missing@example.com'))
        ->assertJsonPath('result.isError', true);
});

it('accepts the site origin when the configured MCP resource uses a path prefix', function () {
    configureChatgptTestOAuth();
    config()->set('app.url', 'https://sbuddy.elbiblio.com/sb-stage');
    $body = ['jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list'];
    $this->postJson('/mcp', $body, ['Origin' => 'https://sbuddy.elbiblio.com'])->assertOk();
    $this->postJson('/mcp', $body, ['Origin' => 'https://untrusted.example'])->assertStatus(403);
});


it('does not provision users or retrieve private records when a verified OAuth identity is unlinked', function () {
    $pem = configureChatgptTestOAuth();
    $auth = chatgptTestBearer($pem, 'unlinked@example.com');

    $this->postJson('/mcp', chatgptTestCall('get_account_link_status'), $auth)
        ->assertJsonPath('result.structuredContent.status', 'not_linked');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('users')->count())->toBe(0)
        ->and(DB::table('chatgpt_oauth_identities')->count())->toBe(0);

    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => false]), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('users')->count())->toBe(0);
});

it('explicitly provisions a new owner with a stable provider key and permits idempotent retries', function () {
    $pem = configureChatgptTestOAuth();
    $auth = chatgptTestBearer($pem, 'newmember@example.com');

    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $auth)
        ->assertJsonPath('result.structuredContent.status', 'linked');
    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $auth)
        ->assertJsonPath('result.structuredContent.status', 'linked');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.plan', null);
    expect(User::query()->where('email', 'newmember@example.com')->count())->toBe(1)
        ->and(DB::table('chatgpt_oauth_identities')->count())->toBe(1)
        ->and(DB::table('chatgpt_oauth_identities')->value('subject'))->toBe('auth0|person');
});

it('never inherits an existing SoulBuddy account from an email-only match', function () {
    $pem = configureChatgptTestOAuth();
    $owner = User::factory()->create(['email' => 'existing@example.com', 'email_verified_at' => now()]);
    $auth = chatgptTestBearer($pem, 'existing@example.com');

    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('chatgpt_oauth_identities')->count())->toBe(0)
        ->and(User::query()->count())->toBe(1)
        ->and($owner->fresh()->public_id)->toBe($owner->public_id);
});

it('links an existing verified account only with a one-use owner-issued code and explicit consent', function () {
    $pem = configureChatgptTestOAuth();
    $owner = User::factory()->create(['email' => 'linked@example.com', 'email_verified_at' => now()]);
    $auth = chatgptTestBearer($pem, 'linked@example.com');

    $this->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])->assertUnauthorized();
    $challengeResponse = $this->actingAs($owner, 'sanctum')
        ->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])->assertCreated();
    $code = $challengeResponse->json('code');
    expect($code)->toMatch('/^[a-f0-9]{32}$/')
        ->and(DB::table('chatgpt_account_link_codes')->value('code_hash'))->toBe(hash('sha256', $code))
        ->and(DB::table('chatgpt_account_link_codes')->value('code_hash'))->not->toBe($code);

    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => false,
    ]), $auth)->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => true,
    ]), $auth)->assertJsonPath('result.structuredContent.status', 'linked');
    $this->postJson('/mcp', chatgptTestCall('get_account_link_status'), $auth)
        ->assertJsonPath('result.structuredContent.status', 'linked');

    expect(DB::table('chatgpt_oauth_identities')->value('user_id'))->toBe($owner->id)
        ->and(DB::table('chatgpt_account_link_codes')->value('consumed_at'))->not->toBeNull();
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => true,
    ]), $auth)->assertJsonPath('result.isError', true);

    $this->postJson('/api/account/chatgpt/unlink', ['confirmed' => false])->assertUnprocessable();
    $this->postJson('/api/account/chatgpt/unlink', ['confirmed' => true])
        ->assertJsonPath('unlinked', true);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('chatgpt_oauth_identities')->count())->toBe(0);
});

it('refuses expired codes, mismatched identities and unverified SoulBuddy owners', function () {
    $pem = configureChatgptTestOAuth();
    $unverified = User::factory()->unverified()->create(['email' => 'pending@example.com']);
    $this->actingAs($unverified, 'sanctum')
        ->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])->assertUnprocessable();

    $owner = User::factory()->create(['email' => 'account@example.com', 'email_verified_at' => now()]);
    $code = $this->actingAs($owner, 'sanctum')
        ->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])->assertCreated()->json('code');
    $wrongAuth = chatgptTestBearer($pem, 'another@example.com');
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => true,
    ]), $wrongAuth)->assertJsonPath('result.isError', true);
    expect(DB::table('chatgpt_account_link_codes')->value('consumed_at'))->toBeNull();

    DB::table('chatgpt_account_link_codes')->update(['expires_at' => now()->subSecond()]);
    $rightAuth = chatgptTestBearer($pem, 'account@example.com');
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => true,
    ]), $rightAuth)->assertJsonPath('result.isError', true);
    expect(DB::table('chatgpt_oauth_identities')->count())->toBe(0);
});

it('keeps private history bound to subject after email changes and blocks reassignment', function () {
    $pem = configureChatgptTestOAuth();
    $alice = chatgptTestBearer($pem, 'first@example.com');
    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $alice)
        ->assertJsonPath('result.structuredContent.status', 'linked');
    $planId = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', chatgptTestPlan()), $alice)
        ->json('result.structuredContent.plan.id');
    expect($planId)->not->toBeNull();

    // A new provider subject with the same verified email cannot inherit the plan.
    $other = chatgptTestBearer($pem, 'first@example.com', 'life.read life.write', ['sub' => 'auth0|other-person']);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $other)
        ->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $other)
        ->assertJsonPath('result.isError', true);

    $owner = User::query()->where('email', 'first@example.com')->firstOrFail();
    $owner->forceFill(['email' => 'renamed@example.com'])->save();
    // Same issuer/subject can still read even with changed or absent email claim.
    $renamed = chatgptTestBearer($pem, 'renamed@example.com', 'life.read');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $renamed)
        ->assertJsonPath('result.structuredContent.plan.id', $planId);
    $missingEmail = chatgptTestBearer($pem, 'renamed@example.com', 'life.read', [
        'https://soulbuddy.app/email' => null,
        'https://soulbuddy.app/email_verified' => false,
    ]);
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $missingEmail)
        ->assertJsonPath('result.structuredContent.plan.id', $planId);

    // Reassignment creates a distinct account when the email is genuinely free.
    $this->postJson('/mcp', chatgptTestCall('create_soulbuddy_account', ['confirmed' => true]), $other)
        ->assertJsonPath('result.structuredContent.status', 'linked');
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $other)
        ->assertJsonPath('result.structuredContent.plan', null);
    expect(User::query()->count())->toBe(2)
        ->and(DB::table('chatgpt_oauth_identities')->count())->toBe(2);
});

it('rejects linking two different subjects from the same provider to one SoulBuddy account', function () {
    $pem = configureChatgptTestOAuth();
    $owner = User::factory()->create(['email' => 'single@example.com', 'email_verified_at' => now()]);
    $first = chatgptTestBearer($pem, 'single@example.com');
    $second = chatgptTestBearer($pem, 'single@example.com', 'life.write', ['sub' => 'auth0|second']);

    $code = $this->actingAs($owner, 'sanctum')
        ->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])->json('code');
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $code, 'confirmed' => true,
    ]), $first)->assertJsonPath('result.structuredContent.status', 'linked');

    $anotherCode = $this->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])
        ->assertCreated()->json('code');
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $anotherCode, 'confirmed' => true,
    ]), $second)->assertJsonPath('result.isError', true);
    expect(DB::table('chatgpt_oauth_identities')->count())->toBe(1);
});


it('invalidates older account link codes when a new one is issued or access is unlinked', function () {
    $pem = configureChatgptTestOAuth();
    $owner = User::factory()->create(['email' => 'rotate@example.com', 'email_verified_at' => now()]);
    $auth = chatgptTestBearer($pem, 'rotate@example.com');

    $first = $this->actingAs($owner, 'sanctum')
        ->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])
        ->assertCreated()->json('code');
    $second = $this->postJson('/api/account/chatgpt/link-codes', ['confirmed' => true])
        ->assertCreated()->json('code');

    expect($second)->not->toBe($first);
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $first, 'confirmed' => true,
    ]), $auth)->assertJsonPath('result.isError', true);

    $this->postJson('/api/account/chatgpt/unlink', ['confirmed' => true])
        ->assertJsonPath('unlinked', false);
    $this->postJson('/mcp', chatgptTestCall('link_existing_soulbuddy_account', [
        'code' => $second, 'confirmed' => true,
    ]), $auth)->assertJsonPath('result.isError', true);

    expect(DB::table('chatgpt_account_link_codes')->whereNull('consumed_at')->count())->toBe(0);
});


it('returns only a boolean ChatGPT connection status to the authenticated SoulBuddy owner', function () {
    $owner = User::factory()->create(['email' => 'linked-status@example.com', 'email_verified_at' => now()]);
    $other = User::factory()->create(['email' => 'unlinked-status@example.com', 'email_verified_at' => now()]);

    $this->getJson('/api/account/chatgpt/status')->assertUnauthorized();
    $this->actingAs($owner, 'sanctum')
        ->getJson('/api/account/chatgpt/status')
        ->assertOk()->assertExactJson(['linked' => false]);

    // Laravel also adds a private cache directive to authenticated responses.

    chatgptBindTestIdentity('linked-status@example.com', 'provider|owner', 'https://issuer.example/', $owner);

    $this->getJson('/api/account/chatgpt/status')
        ->assertOk()->assertExactJson(['linked' => true]);
    $this->actingAs($other, 'sanctum')
        ->getJson('/api/account/chatgpt/status')
        ->assertOk()->assertExactJson(['linked' => false]);

    $this->actingAs($owner, 'sanctum')
        ->postJson('/api/account/chatgpt/unlink', ['confirmed' => true])
        ->assertJsonPath('unlinked', true);
    $this->getJson('/api/account/chatgpt/status')
        ->assertExactJson(['linked' => false]);
});

it('prunes only expired account link codes without deleting current codes or OAuth bindings', function () {
    $owner = User::factory()->create(['email' => 'prune@example.com', 'email_verified_at' => now()]);
    chatgptBindTestIdentity('prune@example.com', 'auth0|prune', 'https://issuer.example/', $owner);

    foreach ([
        ['id' => (string) Str::uuid(), 'code_hash' => hash('sha256', 'expired'), 'expires_at' => now()->subMinute()],
        ['id' => (string) Str::uuid(), 'code_hash' => hash('sha256', 'active'), 'expires_at' => now()->addMinutes(5)],
    ] as $code) {
        DB::table('chatgpt_account_link_codes')->insert([
            'id' => $code['id'],
            'user_id' => $owner->id,
            'code_hash' => $code['code_hash'],
            'expires_at' => $code['expires_at'],
            'consumed_at' => null,
            'created_at' => now(),
        ]);
    }

    $this->artisan('chatgpt:prune-link-codes')->assertSuccessful();

    expect(DB::table('chatgpt_account_link_codes')->count())->toBe(1)
        ->and(DB::table('chatgpt_account_link_codes')->value('code_hash'))->toBe(hash('sha256', 'active'))
        ->and(DB::table('chatgpt_oauth_identities')->count())->toBe(1);
});


it('rolls a finished week forward without interrupting active dates or losing historical review', function () {
    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-10-28 10:00:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $pem = configureChatgptTestOAuth();
    chatgptBindTestIdentity('rollover@example.com');
    chatgptBindTestIdentity('not-owner@example.com', 'auth0|not-owner');
    $auth = chatgptTestBearer($pem, 'rollover@example.com');

    $first = chatgptTestPlan();
    $firstId = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $first), $auth)
        ->assertJsonPath('result.structuredContent.plan.archived', false)
        ->json('result.structuredContent.plan.id');
    expect($firstId)->toBeString();

    $premature = chatgptTestPlan();
    $premature['starts_on'] = '2026-10-29';
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $premature), $auth)
        ->assertJsonPath('result.isError', true);
    expect(DB::table('life_plans')->count())->toBe(1);

    // On the seventh day, it is still too early to archive the plan without
    // the person's explicit request to interrupt the active week.
    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-11-03 10:00:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $auth = chatgptTestBearer($pem, 'rollover@example.com');
    $next = chatgptTestPlan();
    $next['starts_on'] = '2026-11-04';
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $next), $auth)
        ->assertJsonPath('result.isError', true);

    $this->travelTo(\Illuminate\Support\Carbon::parse('2026-11-04 10:00:00', 'UTC'));
    JWT::$timestamp = now()->timestamp;
    $auth = chatgptTestBearer($pem, 'rollover@example.com');
    $nextId = $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $next), $auth)
        ->assertJsonPath('result.structuredContent.plan.archived', false)
        ->json('result.structuredContent.plan.id');

    expect($nextId)->toBeString()->not->toBe($firstId)
        ->and(DB::table('life_plans')->whereNull('archived_at')->count())->toBe(1)
        ->and(DB::table('life_plans')->where('id', $firstId)->whereNotNull('archived_at')->exists())->toBeTrue();

    // A late network retry with the same request_id remains idempotent even
    // when the original week is in the past and has since been archived.
    $this->postJson('/mcp', chatgptTestCall('create_seven_day_plan', $first), $auth)
        ->assertJsonPath('result.structuredContent.plan.id', $firstId)
        ->assertJsonPath('result.structuredContent.plan.archived', true);
    expect(DB::table('life_plans')->count())->toBe(2);

    $this->postJson('/mcp', chatgptTestCall('review_week', ['plan_id' => $firstId]), $auth)
        ->assertJsonPath('result.structuredContent.plan.id', $firstId)
        ->assertJsonPath('result.structuredContent.plan.archived', true)
        ->assertJsonPath('result.structuredContent.outcomes.not_recorded', 7);

    $this->postJson('/mcp', chatgptTestCall('save_weekly_review', [
        'plan_id' => $firstId,
        'reflection' => 'Our first week helped me make more time for my family.',
        'next_adjustment' => 'Keep the evening reflection practical.',
        'confirmed' => true,
    ]), $auth)->assertJsonPath('result.structuredContent.plan.id', $firstId)
        ->assertJsonPath('result.structuredContent.review.next_adjustment', 'Keep the evening reflection practical.');

    // The historical review does not become the active plan and cannot be
    // inspected or changed by another authenticated account.
    $this->postJson('/mcp', chatgptTestCall('get_life_plan'), $auth)
        ->assertJsonPath('result.structuredContent.plan.id', $nextId);
    $other = chatgptTestBearer($pem, 'not-owner@example.com', 'life.read life.write', [
        'sub' => 'auth0|not-owner',
    ]);
    $this->postJson('/mcp', chatgptTestCall('review_week', ['plan_id' => $firstId]), $other)
        ->assertJsonPath('result.isError', true);
    $this->postJson('/mcp', chatgptTestCall('save_weekly_review', [
        'plan_id' => $firstId,
        'reflection' => 'A forged review should not be saved.',
        'next_adjustment' => 'A forged adjustment.',
        'confirmed' => true,
    ]), $other)->assertJsonPath('result.isError', true);

    expect(DB::table('life_plan_reviews')->where('plan_id', $firstId)->count())->toBe(1);
});
