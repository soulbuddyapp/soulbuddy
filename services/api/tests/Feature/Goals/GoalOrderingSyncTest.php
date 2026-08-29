<?php

use App\Models\Goal;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('applies multiple Goal position patches from one sync batch', function () {
    $user = User::factory()->create();
    $firstId = '0198b400-0000-7000-8000-000000000001';
    $secondId = '0198b400-0000-7000-8000-000000000002';

    Goal::create([
        'id' => $firstId,
        'user_id' => $user->id,
        'mode' => 'mixed',
        'status' => 'active',
        'current_revision_id' => null,
        'position' => 0,
    ]);
    Goal::create([
        'id' => $secondId,
        'user_id' => $user->id,
        'mode' => 'mixed',
        'status' => 'active',
        'current_revision_id' => null,
        'position' => 2,
    ]);

    $operations = [
        [
            'operation_id' => '0198b400-0000-7000-8000-000000000011',
            'table' => 'goals',
            'type' => 'patch',
            'id' => $firstId,
            'data' => [
                'position' => 2,
                'updated_at' => '2026-08-29T07:00:00.000Z',
            ],
        ],
        [
            'operation_id' => '0198b400-0000-7000-8000-000000000012',
            'table' => 'goals',
            'type' => 'patch',
            'id' => $secondId,
            'data' => [
                'position' => 0,
                'updated_at' => '2026-08-29T07:00:00.000Z',
            ],
        ],
    ];

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(Goal::findOrFail($firstId)->position)->toBe(2)
        ->and(Goal::findOrFail($secondId)->position)->toBe(0);
});
