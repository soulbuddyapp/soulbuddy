<?php

use App\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    $encodedSecret = rtrim(strtr(base64_encode('test-only-powersync-secret-with-32-bytes'), '+/', '-_'), '=');
    config()->set('services.powersync', [
        'issuer' => 'https://api.soulbuddy.test',
        'audience' => 'https://sync.soulbuddy.test',
        'secret' => $encodedSecret,
        'kid' => 'soulbuddy-test-hs256',
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
        new Key(JWT::urlsafeB64Decode(config('services.powersync.secret')), 'HS256'),
    );
    $header = (array) JWT::jsonDecode(
        JWT::urlsafeB64Decode(explode('.', $response->json('token'))[0]),
    );

    expect($claims)
        ->sub->toBe($user->public_id)
        ->iss->toBe('https://api.soulbuddy.test')
        ->aud->toBe('https://sync.soulbuddy.test')
        ->not->toHaveKeys(['email', 'name'])
        ->and($claims['exp'] - $claims['iat'])->toBe(600)
        ->and($claims['exp'])->toBeLessThanOrEqual(now()->addMinutes(10)->timestamp)
        ->and($header['kid'])->toBe('soulbuddy-test-hs256');

    $publicId = $user->public_id;
    $user->name = 'Changed private name';
    $user->public_id = (string) Str::uuid();
    $user->save();
    expect($user->refresh()->public_id)->toBe($publicId);
});

it('refuses token lifetimes PowerSync will not accept', function () {
    config()->set('services.powersync.ttl_seconds', 3601);

    $this->actingAs(User::factory()->create())
        ->getJson('/api/sync/token')
        ->assertServiceUnavailable();
});
