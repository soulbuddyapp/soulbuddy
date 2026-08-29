<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('rejects invalid owner lifecycle transitions through the API', function () {
    $owner = User::factory()->create();
    $payload = [
        'name' => 'Draft Circle',
        'category' => 'accountability',
        'description' => 'A Circle that is not published yet.',
        'visibility' => 'public',
        'status' => 'draft',
        'provider' => 'telegram',
        'open_url' => 'https://t.me/+draft-circle',
    ];
    $publicId = $this->actingAs($owner)
        ->postJson('/api/circles', $payload)
        ->assertCreated()
        ->assertJsonPath('status', 'draft')
        ->json('public_id');

    $this->actingAs($owner)
        ->patchJson("/api/circles/{$publicId}", ['status' => 'paused'])
        ->assertUnprocessable()
        ->assertJsonPath('errors.status.0', 'invalid_transition');
    $this->assertDatabaseHas('circles', [
        'public_id' => $publicId,
        'status' => 'draft',
    ]);

    $this->actingAs($owner)
        ->patchJson("/api/circles/{$publicId}", ['status' => 'active'])
        ->assertOk()
        ->assertJsonPath('status', 'active');

    $this->actingAs($owner)
        ->patchJson("/api/circles/{$publicId}", ['status' => 'draft'])
        ->assertUnprocessable()
        ->assertJsonPath('errors.status.0', 'invalid_transition');
    $this->assertDatabaseHas('circles', [
        'public_id' => $publicId,
        'status' => 'active',
    ]);
});
