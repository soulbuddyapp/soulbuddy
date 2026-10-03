<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function telegramLinkSession(): array
{
    $response = test()->postJson('/api/installations/session', [
        'owner_id' => (string) Str::uuid(),
        'device_id' => (string) Str::uuid(),
        'installation_secret' => Str::random(64),
    ])->assertCreated();

    return [
        User::query()->where('public_id', $response->json('owner_id'))->firstOrFail(),
        $response->json('token'),
    ];
}

it('issues a short lived Telegram link code without storing the raw code', function () {
    [, $token] = telegramLinkSession();
    config()->set('services.telegram.bot_username', 'SoulBuddyTestBot');

    $response = $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()
        ->assertJsonStructure(['code', 'expires_at', 'start_url']);

    expect($response->json('code'))->toMatch('/^[A-Za-z0-9_-]{32,64}$/')
        ->and($response->json('start_url'))->toBe(
            'https://t.me/SoulBuddyTestBot?start='.$response->json('code'),
        );
    $stored = DB::table('companion_link_codes')->sole();
    expect($stored->token_hash)->not->toBe($response->json('code'))
        ->and($stored->consumed_at)->toBeNull();
});

it('binds a Telegram chat once after the webhook secret is verified', function () {
    [$user, $token] = telegramLinkSession();
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    $code = $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()
        ->json('code');

    $update = [
        'update_id' => 42,
        'message' => [
            'chat' => ['id' => 123456789, 'type' => 'private'],
            'from' => ['id' => 123456789, 'username' => 'beloved'],
            'text' => '/start '.$code,
        ],
    ];
    $this->withHeader('X-Telegram-Bot-Api-Secret-Token', 'webhook-secret')
        ->postJson('/integrations/telegram/webhook', $update)
        ->assertOk()
        ->assertJsonPath('linked', true);

    $this->assertDatabaseHas('telegram_connections', [
        'user_id' => $user->id,
        'chat_id' => '123456789',
        'username' => 'beloved',
        'daily_enabled' => false,
    ]);
    expect(DB::table('companion_link_codes')->sole()->consumed_at)->not->toBeNull();

    $this->withHeader('X-Telegram-Bot-Api-Secret-Token', 'webhook-secret')
        ->postJson('/integrations/telegram/webhook', $update)
        ->assertOk()
        ->assertJsonPath('linked', false);
    expect(DB::table('telegram_connections')->count())->toBe(1);
});

it('does not consume a Telegram link code without the webhook secret', function () {
    [, $token] = telegramLinkSession();
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    $code = $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()
        ->json('code');

    $this->postJson('/integrations/telegram/webhook', [
        'message' => [
            'chat' => ['id' => 123456789, 'type' => 'private'],
            'text' => '/start '.$code,
        ],
    ])->assertForbidden();

    expect(DB::table('companion_link_codes')->sole()->consumed_at)->toBeNull()
        ->and(DB::table('telegram_connections')->count())->toBe(0);
});

it('acknowledges a successful Telegram link without exposing private content', function () {
    [, $token] = telegramLinkSession();
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    $code = $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()
        ->json('code');

    $this->withHeader('X-Telegram-Bot-Api-Secret-Token', 'webhook-secret')
        ->postJson('/integrations/telegram/webhook', [
            'message' => [
                'chat' => ['id' => 123456789, 'type' => 'private'],
                'text' => '/start '.$code,
            ],
        ])
        ->assertOk()
        ->assertJsonPath('linked', true)
        ->assertJsonPath('acknowledged', true);

    Http::assertSent(fn ($request) => str_contains($request->url(), '/botbot-token/sendMessage')
        && $request['chat_id'] === '123456789'
        && $request['text'] === 'SoulBuddy connected. Daily notes are off.');
});
