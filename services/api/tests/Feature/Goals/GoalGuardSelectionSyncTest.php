<?php

use App\Models\Goal;
use App\Models\GoalGuardSelection;
use App\Models\GoalRevision;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function guardSelectionOperation(
    string $operationId,
    string $type,
    string $id,
    array $data = [],
): array {
    return [
        'operation_id' => $operationId,
        'table' => 'goal_guard_selections',
        'type' => $type,
        'id' => $id,
        'data' => $data,
    ];
}

it('syncs a selected guard and later private-note changes idempotently', function () {
    $user = User::factory()->create();
    $goal = Goal::create([
        'id' => '0198b800-0000-7000-8000-000000000001',
        'user_id' => $user->id,
        'starter_key' => 'stop_control',
        'mode' => 'actionable',
        'status' => 'active',
        'current_revision_id' => null,
        'position' => 0,
        'archived_at' => null,
    ]);
    $selectionId = '0198b800-0000-7000-8000-000000000002';
    $put = guardSelectionOperation(
        '0198b800-0000-7000-8000-000000000011',
        'put',
        $selectionId,
        [
            'owner_id' => 'offline-owner',
            'goal_id' => $goal->id,
            'guard_definition_id' => 'dns-adguard-family',
            'guard_content_version' => 1,
            'private_note' => 'Router configured.',
            'configured_at' => '2026-08-29T08:00:00.000Z',
            'archived_at' => null,
        ],
    );

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$put]])
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$put]])
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('duplicates', 1);

    $patch = guardSelectionOperation(
        '0198b800-0000-7000-8000-000000000012',
        'patch',
        $selectionId,
        [
            'private_note' => 'Router and phone configured.',
            'configured_at' => '2026-08-29T08:05:00.000Z',
        ],
    );
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$patch]])
        ->assertOk()
        ->assertJsonPath('accepted', 1);

    $selection = GoalGuardSelection::findOrFail($selectionId);
    expect($selection->user_id)->toBe($user->id)
        ->and($selection->private_note)->toBe('Router and phone configured.')
        ->and($selection->guard_content_version)->toBe(1);
});

it('accepts a Goal, revision, and selected guard in the same offline batch', function () {
    $user = User::factory()->create();
    $goalId = '0198b800-0000-7000-8000-000000000021';
    $revisionId = '0198b800-0000-7000-8000-000000000022';
    $selectionId = '0198b800-0000-7000-8000-000000000023';
    $operations = [
        [
            'operation_id' => '0198b800-0000-7000-8000-000000000031',
            'table' => 'goals',
            'type' => 'put',
            'id' => $goalId,
            'data' => [
                'owner_id' => 'offline-owner',
                'starter_key' => 'stop_control',
                'mode' => 'actionable',
                'status' => 'active',
                'current_revision_id' => $revisionId,
                'position' => 0,
                'created_at' => '2026-08-29T08:00:00.000Z',
                'updated_at' => '2026-08-29T08:00:00.000Z',
                'archived_at' => null,
            ],
        ],
        [
            'operation_id' => '0198b800-0000-7000-8000-000000000032',
            'table' => 'goal_revisions',
            'type' => 'put',
            'id' => $revisionId,
            'data' => [
                'owner_id' => 'offline-owner',
                'goal_id' => $goalId,
                'title' => 'Stop watching pornography',
                'current_situation' => null,
                'why_it_matters' => null,
                'created_at' => '2026-08-29T08:00:00.000Z',
                'device_id' => 'device-1',
            ],
        ],
        guardSelectionOperation(
            '0198b800-0000-7000-8000-000000000033',
            'put',
            $selectionId,
            [
                'owner_id' => 'offline-owner',
                'goal_id' => $goalId,
                'guard_definition_id' => 'physical-boundary',
                'guard_content_version' => 1,
                'private_note' => null,
                'configured_at' => '2026-08-29T08:00:00.000Z',
                'archived_at' => null,
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 3)
        ->assertJsonPath('rejected', 0);

    expect(Goal::find($goalId))->not->toBeNull()
        ->and(GoalRevision::find($revisionId))->not->toBeNull()
        ->and(GoalGuardSelection::find($selectionId)?->goal_id)->toBe($goalId);
});

it('rejects guard selections for another user or an unavailable Goal', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $goal = Goal::create([
        'id' => '0198b800-0000-7000-8000-000000000041',
        'user_id' => $owner->id,
        'starter_key' => 'stop_control',
        'mode' => 'actionable',
        'status' => 'active',
        'current_revision_id' => null,
        'position' => 0,
        'archived_at' => null,
    ]);
    $operation = guardSelectionOperation(
        '0198b800-0000-7000-8000-000000000051',
        'put',
        '0198b800-0000-7000-8000-000000000052',
        [
            'owner_id' => 'offline-owner',
            'goal_id' => $goal->id,
            'guard_definition_id' => 'remove-access',
            'guard_content_version' => 1,
            'private_note' => null,
            'configured_at' => '2026-08-29T08:00:00.000Z',
            'archived_at' => null,
        ],
    );

    $this->actingAs($attacker)
        ->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'inaccessible_record');

    expect(GoalGuardSelection::find($operation['id']))->toBeNull();
});
