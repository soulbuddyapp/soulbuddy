<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

it('creates one private application session for a new installation', function () {
    $ownerId = (string) Str::uuid();
    $deviceId = (string) Str::uuid();
    $secret = Str::random(64);
    Log::spy();

    $response = $this->postJson('/api/installations/session', [
        'owner_id' => $ownerId,
        'device_id' => $deviceId,
        'installation_secret' => $secret,
    ])->assertCreated()
        ->assertJsonPath('owner_id', $ownerId)
        ->assertJsonStructure(['token', 'owner_id']);

    $user = User::where('public_id', $ownerId)->firstOrFail();
    $installation = $user->installations()->whereKey($deviceId)->firstOrFail();
    expect($response->json('token'))->toBeString()->not->toContain($secret)
        ->and(Hash::check($secret, $installation->secret_hash))->toBeTrue()
        ->and($installation->secret_hash)->not->toContain($secret);
    foreach (['error', 'warning', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }
});

it('reissues only for the same device secret and rejects identity claiming', function () {
    $payload = [
        'owner_id' => (string) Str::uuid(),
        'device_id' => (string) Str::uuid(),
        'installation_secret' => Str::random(64),
    ];
    $this->postJson('/api/installations/session', $payload)->assertCreated();
    $this->postJson('/api/installations/session', $payload)->assertOk();

    $wrong = $payload;
    $wrong['installation_secret'] = Str::random(64);
    $this->postJson('/api/installations/session', $wrong)->assertUnauthorized();

    $claimed = $payload;
    $claimed['device_id'] = (string) Str::uuid();
    $claimed['installation_secret'] = Str::random(64);
    $this->postJson('/api/installations/session', $claimed)->assertConflict();
});

it('rejects unknown fields and malformed identifiers without echoing secrets', function () {
    $secret = Str::random(64);
    $response = $this->postJson('/api/installations/session', [
        'owner_id' => 'bad',
        'device_id' => (string) Str::uuid(),
        'installation_secret' => $secret,
        'name' => 'claim',
    ])->assertUnprocessable();

    expect($response->getContent())->not->toContain($secret);
});
