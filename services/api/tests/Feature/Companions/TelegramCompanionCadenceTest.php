<?php

use App\Models\PersonalPrayer;
use App\Models\PrayerPerson;
use App\Models\PrayerReminder;
use App\Models\SacredHour;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function companionUser(): User
{
    return User::factory()->create();
}

function companionLinkSession(): array
{
    config()->set('services.telegram.bot_username', 'soul_buddy_bot');
    $response = test()->postJson('/api/installations/session', [
        'owner_id' => (string) Str::uuid(),
        'device_id' => (string) Str::uuid(),
        'installation_secret' => Str::random(64),
    ])->assertCreated();
    auth()->forgetGuards();

    return [
        User::query()->where('public_id', $response->json('owner_id'))->firstOrFail(),
        $response->json('token'),
    ];
}

function companionConnection(User $user, array $attributes = []): string
{
    $id = (string) Str::uuid();
    DB::table('telegram_connections')->insert(array_merge([
        'id' => $id,
        'user_id' => $user->id,
        'chat_id' => (string) random_int(100000, 999999),
        'username' => 'beloved',
        'daily_enabled' => true,
        'created_at' => now(),
        'updated_at' => now(),
    ], $attributes));

    return $id;
}

it('activates the companion when a private Telegram chat is linked', function () {
    [$user, $token] = companionLinkSession();
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    $code = $this->withToken($token)
        ->postJson('/api/companions/telegram/link-codes')
        ->assertAccepted()
        ->json('code');

    $this->withHeader('X-Telegram-Bot-Api-Secret-Token', 'webhook-secret')
        ->postJson('/integrations/telegram/webhook', [
            'message' => [
                'chat' => ['id' => 123456789, 'type' => 'private'],
                'from' => ['id' => 123456789, 'username' => 'beloved'],
                'text' => '/start '.$code,
            ],
        ])
        ->assertOk()
        ->assertJsonPath('linked', true);

    $this->assertDatabaseHas('telegram_connections', [
        'user_id' => $user->id,
        'daily_enabled' => true,
    ]);
});

it('sends one weekly prayer prompt for an unattended person', function () {
    $this->travelTo(now()->setDate(2026, 10, 4)->setTime(8, 0)->utc());
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    $user = companionUser();
    $connectionId = companionConnection($user);
    PrayerPerson::query()->create([
        'id' => $personId = (string) Str::uuid(),
        'user_id' => $user->id,
        'name' => 'Grace',
        'cadence' => 'weekly',
        'weekdays_mask' => 0,
        'created_at' => now()->subDays(8),
        'updated_at' => now()->subDays(8),
    ]);

    expect(Artisan::call('telegram-companion:send'))->toBe(0);

    expect(DB::table('telegram_companion_deliveries')
        ->where('telegram_connection_id', $connectionId)
        ->where('kind', 'weekly_person_prayer')
        ->count())->toBe(1);

    expect(Artisan::call('telegram-companion:send'))->toBe(0);
    expect(DB::table('telegram_companion_deliveries')
        ->where('telegram_connection_id', $connectionId)
        ->where('kind', 'weekly_person_prayer')
        ->count())->toBe(1);
    Http::assertSentCount(2);
});

it('delivers due prayer and Sacred Hour prompts after a short scheduler delay', function () {
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    $user = companionUser();
    $connectionId = companionConnection($user);
    $prayer = PersonalPrayer::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'title' => 'Morning prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'growth',
    ]);
    PrayerReminder::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'personal_prayer_id' => $prayer->id,
        'schedule_type' => 'daily',
        'local_time' => '06:00',
        'timezone' => 'UTC',
        'enabled' => true,
    ]);
    SacredHour::query()->create([
        'id' => (string) Str::uuid(),
        'user_id' => $user->id,
        'name' => 'Morning offering',
        'local_time' => '06:00',
        'timezone' => 'UTC',
        'duration_minutes' => 60,
        'prayer_minutes' => 15,
        'enabled' => true,
        'sound_key' => 'gentle_chime',
    ]);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(6, 2)->utc());
    expect(Artisan::call('telegram-companion:send'))->toBe(0);

    expect(DB::table('telegram_companion_deliveries')
        ->where('telegram_connection_id', $connectionId)
        ->where('kind', 'prayer_reminder')
        ->count())->toBe(1)
        ->and(DB::table('telegram_companion_deliveries')
            ->where('telegram_connection_id', $connectionId)
            ->where('kind', 'sacred_hour')
            ->count())->toBe(1);
});

it('delivers the next reviewed formation video with a watched confirmation', function () {
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();
    $user = companionUser();
    $connectionId = companionConnection($user);

    $this->travelTo(now()->setDate(2026, 10, 5)->setTime(7, 1)->utc());
    expect(Artisan::call('telegram-companion:send'))->toBe(0);

    expect(DB::table('telegram_companion_deliveries')
        ->where('telegram_connection_id', $connectionId)
        ->where('kind', 'daily_formation')
        ->count())->toBe(1);
    Http::assertSent(fn ($request) => str_contains($request['text'], 'Daily formation')
        && str_starts_with(
            $request['reply_markup']['inline_keyboard'][1][0]['callback_data'],
            'formation:',
        ));
});

it('records a formation video as watched from a private Telegram callback', function () {
    $user = companionUser();
    companionConnection($user, ['chat_id' => '123456789']);
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);

    $this->withHeader('X-Telegram-Bot-Api-Secret-Token', 'webhook-secret')
        ->postJson('/integrations/telegram/webhook', [
            'callback_query' => [
                'id' => 'callback-id',
                'from' => ['id' => 123456789],
                'message' => ['chat' => ['id' => 123456789, 'type' => 'private']],
                'data' => 'formation:video-1',
            ],
        ])
        ->assertOk()
        ->assertJsonPath('recorded', true);

    $this->assertDatabaseHas('formation_activity_events', [
        'user_id' => $user->id,
        'formation_video_id' => 'video-1',
        'source' => 'telegram',
    ]);
});

it('pauses and resumes Telegram prompts from the private chat', function () {
    $user = companionUser();
    companionConnection($user, ['chat_id' => '123456789']);
    config()->set('services.telegram.webhook_secret', 'webhook-secret');
    config()->set('services.telegram.bot_token', 'bot-token');
    Http::fake(['api.telegram.org/*' => Http::response(['ok' => true])]);
    $headers = ['X-Telegram-Bot-Api-Secret-Token' => 'webhook-secret'];

    $this->withHeaders($headers)->postJson('/integrations/telegram/webhook', [
        'message' => ['chat' => ['id' => 123456789, 'type' => 'private'], 'text' => '/pause'],
    ])->assertOk()->assertJsonPath('updated', true);
    $this->assertDatabaseHas('telegram_connections', [
        'user_id' => $user->id,
        'daily_enabled' => false,
    ]);

    $this->withHeaders($headers)->postJson('/integrations/telegram/webhook', [
        'message' => ['chat' => ['id' => 123456789, 'type' => 'private'], 'text' => '/resume'],
    ])->assertOk()->assertJsonPath('updated', true);
    $this->assertDatabaseHas('telegram_connections', [
        'user_id' => $user->id,
        'daily_enabled' => true,
    ]);
});

it('records formation activity from the authenticated app', function () {
    [, $token] = companionLinkSession();

    $this->withToken($token)
        ->postJson('/api/formation/activity', [
            'formation_video_id' => 'video-1',
            'activity_type' => 'opened',
        ])
        ->assertCreated()
        ->assertJsonPath('recorded', true);

    $this->assertDatabaseHas('formation_activity_events', [
        'formation_video_id' => 'video-1',
        'source' => 'app',
        'activity_type' => 'opened',
    ]);
});
