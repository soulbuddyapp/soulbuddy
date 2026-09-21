<?php

use App\Domain\Notifications\FirebasePushSender;
use App\Models\AppInstallation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function morningInstallation(string $timeZone = 'Africa/Lagos'): array
{
    $response = test()->postJson('/api/installations/session', [
        'owner_id' => (string) Str::uuid(),
        'device_id' => $deviceId = (string) Str::uuid(),
        'installation_secret' => Str::random(64),
    ])->assertCreated();

    auth()->forgetGuards();
    test()->withToken($response->json('token'))->postJson('/api/installations/push', [
        'device_id' => $deviceId,
        'push_token' => 'test-token-'.$deviceId,
        'time_zone' => $timeZone,
    ])->assertOk()->assertJsonPath('registered', true);

    return [$deviceId, $response->json('token')];
}

it('registers only its own installation and can disable push', function () {
    [$deviceId, $token] = morningInstallation();
    [$otherDevice] = morningInstallation();

    auth()->forgetGuards();
    $this->withToken($token)->postJson('/api/installations/push', [
        'device_id' => $otherDevice,
        'push_token' => 'hijack',
        'time_zone' => 'Africa/Lagos',
    ])->assertNotFound();
    $this->withToken($token)->postJson('/api/installations/push', [
        'device_id' => $deviceId,
        'push_token' => 'x',
        'time_zone' => 'invalid',
    ])->assertUnprocessable();
    $this->withToken($token)->postJson('/api/installations/push', [
        'device_id' => $deviceId,
        'push_token' => null,
        'time_zone' => 'Africa/Lagos',
    ])->assertOk()->assertJsonPath('registered', false);
    expect(AppInstallation::findOrFail($deviceId)->push_token)->toBeNull();
});

it('sends after local 5:30 once per day and retries failed deliveries', function () {
    [$lagos] = morningInstallation('Africa/Lagos');
    [$london] = morningInstallation('UTC');
    $sender = Mockery::mock(FirebasePushSender::class);
    $sender->shouldReceive('sendMorning')->once()->with('test-token-'.$lagos)->andReturn(false);
    $this->app->instance(FirebasePushSender::class, $sender);

    $this->travelTo(now()->setDate(2026, 9, 21)->setTime(4, 30)->utc());
    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    expect(AppInstallation::findOrFail($lagos)->last_morning_sent_on)->toBeNull();
    expect(AppInstallation::findOrFail($london)->last_morning_sent_on)->toBeNull();

    $sender = Mockery::mock(FirebasePushSender::class);
    $sender->shouldReceive('sendMorning')->once()->with('test-token-'.$lagos)->andReturn(true);
    $this->app->instance(FirebasePushSender::class, $sender);
    expect(Artisan::call('morning-notifications:send'))->toBe(0);
    expect(AppInstallation::findOrFail($lagos)->last_morning_sent_on->toDateString())->toBe('2026-09-21');
    expect(AppInstallation::findOrFail($london)->last_morning_sent_on)->toBeNull();

    $sender = Mockery::mock(FirebasePushSender::class);
    $sender->shouldReceive('sendMorning')->once()->with('test-token-'.$london)->andReturn(true);
    $this->app->instance(FirebasePushSender::class, $sender);
    $this->travelTo(now()->addHour());
    expect(Artisan::call('morning-notifications:send'))->toBe(0);
    expect(AppInstallation::findOrFail($london)->last_morning_sent_on->toDateString())->toBe('2026-09-21');
});

it('uses a signed service account assertion and an Android morning channel', function () {
    $opensslConfig = tempnam(sys_get_temp_dir(), 'openssl-config-');
    file_put_contents($opensslConfig, "[req]\ndistinguished_name=req_distinguished_name\n[req_distinguished_name]\n");
    $key = openssl_pkey_new(['private_key_bits' => 2048, 'config' => $opensslConfig]);
    openssl_pkey_export($key, $privateKey, null, ['config' => $opensslConfig]);
    $path = tempnam(sys_get_temp_dir(), 'soulbuddy-fcm-');
    file_put_contents($path, json_encode([
        'client_email' => 'test@example.invalid',
        'private_key' => $privateKey,
    ]));
    config()->set('services.firebase.project_id', 'test-project');
    config()->set('services.firebase.service_account_path', $path);
    Cache::forget('firebase_messaging_access_token');
    Http::fake([
        'oauth2.googleapis.com/token' => Http::response(['access_token' => 'test-access-token']),
        'fcm.googleapis.com/*' => Http::response(['name' => 'sent-message']),
    ]);

    try {
        expect(app(FirebasePushSender::class)->sendMorning('test-device-token'))->toBeTrue();
        Http::assertSent(fn ($request) => str_contains($request->url(), 'oauth2.googleapis.com/token')
            && $request['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer');
        Http::assertSent(fn ($request) => str_contains($request->url(), 'fcm.googleapis.com/v1/projects/test-project/messages:send')
            && $request->hasHeader('Authorization', 'Bearer test-access-token')
            && $request['message']['token'] === 'test-device-token'
            && $request['message']['android']['notification']['channel_id'] === 'soulbuddy_morning_v1');
    } finally {
        unlink($path);
        unlink($opensslConfig);
        Cache::forget('firebase_messaging_access_token');
    }
});
