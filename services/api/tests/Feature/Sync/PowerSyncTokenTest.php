<?php

use App\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.powersync', [
        'issuer' => 'https://api.soulbuddy.test',
        'audience' => 'https://sync.soulbuddy.test',
        'secret' => 'test-only-powersync-secret-with-32-bytes',
        'ttl_seconds' => 600,
    ]);
});

it('requires an authenticated application session', function () {
    $this->getJson('/api/sync/token')->assertUnauthorized();
});

it('issues a short-lived private-data-free token for an immutable public user id', function () {
    $user = User::factory()->create([
        'name' => 'Private Name',
        'email' => 'private@example.test',
    ]);

    $response = $this->actingAs($user)
        ->getJson('/api/sync/token')
        ->assertOk()
        ->assertJsonPath('user_id', $user->public_id)
        ->assertJsonMissing(['email' => $user->email, 'name' => $user->name]);

    expect(Str::isUuid($user->public_id))->toBeTrue();

    $claims = (array) JWT::decode(
        $response->json('token'),
        new Key(config('services.powersync.secret'), 'HS256'),
    );

    expect($claims)
        ->sub->toBe($user->public_id)
        ->iss->toBe('https://api.soulbuddy.test')
        ->aud->toBe('https://sync.soulbuddy.test')
        ->not->toHaveKeys(['email', 'name'])
        ->and($claims['exp'] - $claims['iat'])->toBe(600)
        ->and($claims['exp'])->toBeLessThanOrEqual(now()->addMinutes(10)->timestamp);

    $publicId = $user->public_id;
    $user->name = 'Changed private name';
    $user->public_id = (string) Str::uuid();
    $user->save();
    expect($user->refresh()->public_id)->toBe($publicId);
});
