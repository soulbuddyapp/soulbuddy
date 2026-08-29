<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

it('deduplicates exact Circle create retries and rejects key reuse with different payloads', function () {
    $owner = User::factory()->create();
    $payload = [
        'creation_key' => '550e8400-e29b-41d4-a716-446655440000',
        'name' => 'Walk together',
        'category' => 'accountability',
        'description' => 'A small group for honest accountability and prayer.',
        'visibility' => 'public',
        'status' => 'active',
        'provider' => 'telegram',
        'open_url' => 'https://t.me/+idempotent-circle',
    ];

    $first = $this->actingAs($owner)
        ->postJson('/api/circles', $payload)
        ->assertCreated();
    $publicId = $first->json('public_id');

    $this->actingAs($owner)
        ->postJson('/api/circles', $payload)
        ->assertOk()
        ->assertJsonPath('public_id', $publicId);

    expect(DB::table('circles')->count())->toBe(1)
        ->and(DB::table('circle_provider_bindings')->count())->toBe(1);

    $changed = $payload;
    $changed['name'] = 'Different Circle';
    $this->actingAs($owner)
        ->postJson('/api/circles', $changed)
        ->assertUnprocessable()
        ->assertJsonPath('errors.creation_key.0', 'idempotency_conflict');

    $this->assertDatabaseHas('circles', [
        'public_id' => $publicId,
        'name' => 'Walk together',
    ]);
    $this->assertDatabaseMissing('circles', ['name' => 'Different Circle']);
});

it('scopes Circle creation keys to the owner', function () {
    $firstOwner = User::factory()->create();
    $secondOwner = User::factory()->create();
    $payload = [
        'creation_key' => '550e8400-e29b-41d4-a716-446655440001',
        'name' => 'Shared client key',
        'category' => 'bible_study',
        'description' => 'The same UUID is safe across different owners.',
        'visibility' => 'unlisted',
        'provider' => 'telegram',
        'open_url' => 'https://t.me/+owner-scoped-key',
    ];

    $this->actingAs($firstOwner)->postJson('/api/circles', $payload)->assertCreated();
    $this->actingAs($secondOwner)->postJson('/api/circles', $payload)->assertCreated();

    expect(DB::table('circles')->count())->toBe(2);
});
