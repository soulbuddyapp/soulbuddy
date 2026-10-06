<?php

use App\Mail\AccountEmailVerification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

it('creates an email verification challenge without changing the private owner', function () {
    Mail::fake();
    $user = User::factory()->unverified()->create([
        'email' => Str::uuid().'@install.soulbuddy.invalid',
    ]);
    $ownerId = $user->public_id;

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/account/email/challenges', [
            'email' => 'beloved@example.com',
        ])
        ->assertAccepted()
        ->assertJsonStructure(['challenge_id']);

    $challenge = DB::table('account_challenges')->first();

    expect($challenge->user_id)->toBe($user->id)
        ->and($challenge->email)->toBe('beloved@example.com')
        ->and($challenge->purpose)->toBe('attach_email')
        ->and($challenge->token_hash)->toMatch('/^[a-f0-9]{64}$/')
        ->and($user->fresh()->public_id)->toBe($ownerId)
        ->and($user->fresh()->email)->toEndWith('@install.soulbuddy.invalid');

    Mail::assertSent(AccountEmailVerification::class, function (AccountEmailVerification $mail): bool {
        return str_contains($mail->verificationUrl, '/app/verify#challenge=')
            && str_contains($mail->verificationUrl, '&token=');
    });
});

it('verifies a challenge once without replacing the private owner', function () {
    $user = User::factory()->unverified()->create([
        'email' => Str::uuid().'@install.soulbuddy.invalid',
    ]);
    $ownerId = $user->public_id;
    $challengeId = (string) Str::uuid();
    $token = bin2hex(random_bytes(32));

    DB::table('account_challenges')->insert([
        'id' => $challengeId,
        'user_id' => $user->id,
        'purpose' => 'attach_email',
        'email' => 'beloved@example.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
        'created_at' => now(),
    ]);

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/account/email/confirm', [
            'challenge_id' => $challengeId,
            'token' => $token,
        ])
        ->assertOk();

    expect($user->fresh()->email)->toBe('beloved@example.com')
        ->and($user->fresh()->email_verified_at)->not->toBeNull()
        ->and($user->fresh()->public_id)->toBe($ownerId)
        ->and(DB::table('account_challenges')->where('id', $challengeId)->value('consumed_at'))
        ->not->toBeNull();

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/account/email/confirm', [
            'challenge_id' => $challengeId,
            'token' => $token,
        ])
        ->assertStatus(410);
});

it('rejects an incorrect email verification token without consuming the challenge', function () {
    $owner = User::factory()->unverified()->create();
    $challengeId = (string) Str::uuid();
    $token = bin2hex(random_bytes(32));

    DB::table('account_challenges')->insert([
        'id' => $challengeId,
        'user_id' => $owner->id,
        'purpose' => 'attach_email',
        'email' => 'beloved@example.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
        'created_at' => now(),
    ]);

    $this->postJson('/auth/email/confirm', [
        'challenge_id' => $challengeId,
        'token' => bin2hex(random_bytes(32)),
    ])
        ->assertStatus(410);

    expect(DB::table('account_challenges')->where('id', $challengeId)->value('consumed_at'))
        ->toBeNull()
        ->and($owner->fresh()->email_verified_at)->toBeNull();
});

it('rejects an expired email verification challenge', function () {
    $user = User::factory()->unverified()->create();
    $challengeId = (string) Str::uuid();
    $token = bin2hex(random_bytes(32));

    DB::table('account_challenges')->insert([
        'id' => $challengeId,
        'user_id' => $user->id,
        'purpose' => 'attach_email',
        'email' => 'beloved@example.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->subSecond(),
        'created_at' => now()->subMinutes(11),
    ]);

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/account/email/confirm', [
            'challenge_id' => $challengeId,
            'token' => $token,
        ])
        ->assertStatus(410);
});

it('confirms an email link into a browser session', function () {
    $user = User::factory()->unverified()->create();
    $challengeId = (string) Str::uuid();
    $token = bin2hex(random_bytes(32));

    DB::table('account_challenges')->insert([
        'id' => $challengeId,
        'user_id' => $user->id,
        'purpose' => 'attach_email',
        'email' => 'beloved@example.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
        'created_at' => now(),
    ]);

    $this->postJson('/auth/email/confirm', [
        'challenge_id' => $challengeId,
        'token' => $token,
    ])->assertOk()
        ->assertJsonPath('status', 'verified');

    $this->assertAuthenticatedAs($user)
        ->assertDatabaseHas('account_challenges', [
            'id' => $challengeId,
        ]);
    expect(DB::table('account_challenges')->where('id', $challengeId)->value('consumed_at'))
        ->not->toBeNull();
});
