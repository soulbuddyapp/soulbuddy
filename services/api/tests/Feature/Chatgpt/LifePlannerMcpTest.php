<?php

use App\Models\User;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function configureChatgptTestOAuth(): string
{
    config()->set('app.url', 'https://sbuddy.elbiblio.com');
    config()->set('services.chatgpt.issuer', 'https://issuer.example/');
    config()->set('services.chatgpt.audience', 'https://sbuddy.elbiblio.com/mcp');
    config()->set('services.chatgpt.jwks_url', 'https://issuer.example/jwks.json');
    config()->set('services.chatgpt.email_claim', 'https://soulbuddy.app/email');
    config()->set('services.chatgpt.email_verified_claim', 'https://soulbuddy.app/email_verified');
    Cache::flush();

    $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_RSA, 'private_key_bits' => 2048]);
    openssl_pkey_export($key, $pem);
    $rsa = openssl_pkey_get_details($key)['rsa'];
    Http::fake(['https://issuer.example/jwks.json' => Http::response([
        'keys' => [[
            'kty' => 'RSA',
            'alg' => 'RS256',
            'use' => 'sig',
            'kid' => 'soulbuddy-test-key',
            'n' => JWT::urlsafeB64Encode($rsa['n']),
            'e' => JWT::urlsafeB64Encode($rsa['e']),
        ]],
    ])]);

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

    $this->postJson('/mcp', [
        'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize',
        'params' => ['protocolVersion' => '2025-11-25'],
    ])->assertOk()->assertJsonPath('result.serverInfo.name', 'soulbuddy-life-planner');

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
    ])->assertStatus(202)->assertNoContent();
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

    expect(DB::table('life_plans')->count())->toBe(0);
});

it('saves idempotent plans, scopes access and records reversible observations rather than spiritual scores', function () {
    $pem = configureChatgptTestOAuth();
    $a = User::factory()->create(['email' => 'a@example.com', 'email_verified_at' => now()]);
    $b = User::factory()->create(['email' => 'b@example.com', 'email_verified_at' => now()]);
    $authA = chatgptTestBearer($pem, 'a@example.com');
    $authB = chatgptTestBearer($pem, 'b@example.com');
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
