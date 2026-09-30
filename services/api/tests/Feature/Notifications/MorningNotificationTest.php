<?php

use App\Domain\Notifications\FirebasePushSender;
use App\Models\AppInstallation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
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

it('uses a signed service account assertion and an Android morning channel', function (bool $expiredAccessToken) {
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
    if ($expiredAccessToken) {
        Cache::put('firebase_messaging_access_token', 'expired-access-token');
    }
    $fcm = Http::sequence();
    if ($expiredAccessToken) {
        $fcm->push(['error' => ['status' => 'UNAUTHENTICATED']], 401);
    }
    $fcm->push(['name' => 'sent-message']);
    Http::fake([
        'oauth2.googleapis.com/token' => Http::response(['access_token' => 'test-access-token']),
        'fcm.googleapis.com/*' => $fcm,
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
})->with([false, true]);

function fakeMorningDeliveryError(string $code): array
{
    config()->set('services.firebase.project_id', 'test-project');
    Cache::put('firebase_messaging_access_token', 'test-access-token');
    test()->travelTo(now()->setDate(2026, 9, 21)->setTime(6, 30)->utc());

    return ['error' => [
        'message' => 'private token and user content must not be logged',
        'status' => 'untrusted status must not be logged',
        'details' => [[
            '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
            'errorCode' => $code,
        ]],
    ]];
}

it('clears an unregistered token and records only sanitized delivery diagnostics', function () {
    [$deviceId] = morningInstallation();
    Http::fake(['fcm.googleapis.com/*' => Http::response(fakeMorningDeliveryError('UNREGISTERED'), 404)]);
    Log::spy();

    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    expect(AppInstallation::findOrFail($deviceId)->push_token)->toBeNull();
    expect(AppInstallation::findOrFail($deviceId)->last_morning_sent_on)->toBeNull();
    Log::shouldHaveReceived('warning')->with('Firebase morning notification rejected.', [
        'http_status' => 404,
        'error_code' => 'UNREGISTERED',
    ])->once();
    Log::shouldHaveReceived('info')->with('Morning notification delivery summary.', [
        'accepted' => 0, 'failed' => 1, 'invalid_tokens_removed' => 1,
    ])->once();
});

it('preserves a newly refreshed token when an earlier token is rejected', function () {
    [$deviceId] = morningInstallation();
    $body = fakeMorningDeliveryError('UNREGISTERED');
    Http::fake(function () use ($deviceId, $body) {
        AppInstallation::whereKey($deviceId)->update(['push_token' => 'new-token']);

        return Http::response($body, 404);
    });

    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    expect(AppInstallation::findOrFail($deviceId)->push_token)->toBe('new-token');
});

it('retains a token on nonpermanent errors and retries next run', function (string $code, int $status) {
    [$deviceId] = morningInstallation();
    Http::fake(['fcm.googleapis.com/*' => Http::sequence()
        ->push(fakeMorningDeliveryError($code), $status)
        ->push(['name' => 'accepted'])]);
    Log::spy();

    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    expect(AppInstallation::findOrFail($deviceId)->push_token)->toBe('test-token-'.$deviceId);
    expect(AppInstallation::findOrFail($deviceId)->last_morning_sent_on)->toBeNull();
    Log::shouldHaveReceived('warning')->with('Firebase morning notification rejected.', [
        'http_status' => $status,
        'error_code' => in_array($code, ['INVALID_ARGUMENT', 'UNAVAILABLE']) ? $code : 'UNKNOWN',
    ])->once();
    expect(Artisan::call('morning-notifications:send'))->toBe(0);
    expect(AppInstallation::findOrFail($deviceId)->last_morning_sent_on->toDateString())->toBe('2026-09-21');
})->with([
    ['INVALID_ARGUMENT', 400],
    ['UNAVAILABLE', 503],
    ['private untrusted error code', 500],
]);

it('does not log exception messages containing request credentials', function () {
    morningInstallation();
    fakeMorningDeliveryError('UNAVAILABLE');
    Http::fake(fn () => throw new ConnectionException('secret token and request body'));
    Log::spy();

    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    Log::shouldHaveReceived('warning')->with('Morning notification delivery failed.', [
        'exception_type' => ConnectionException::class,
    ])->once();
    Log::shouldNotHaveReceived('error');
});

it('processes every installation when invalid tokens remove earlier rows from eligibility', function () {
    [$deviceId] = morningInstallation();
    $installation = AppInstallation::findOrFail($deviceId);
    for ($i = 0; $i < 200; $i++) {
        $copy = $installation->replicate();
        $copy->id = (string) Str::uuid();
        $copy->save();
    }
    Http::fake(['fcm.googleapis.com/*' => Http::response(fakeMorningDeliveryError('UNREGISTERED'), 404)]);

    expect(Artisan::call('morning-notifications:send'))->toBe(1);
    expect(AppInstallation::whereNotNull('push_token')->count())->toBe(0);
    Http::assertSentCount(201);
});
