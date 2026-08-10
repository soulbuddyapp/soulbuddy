<?php

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\SyncOperation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function encounterBatch(array $overrides = []): array
{
    return array_replace([
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000001',
            'table' => 'encounters',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000002',
            'data' => [
                'title' => 'The help I received',
                'body' => 'I remembered that I was not alone.',
                'occurred_on' => '2026-08-10',
                'is_altar' => false,
                'current_revision_id' => '0198a000-0000-7000-8000-000000000003',
            ],
        ], [
            'operation_id' => '0198a000-0000-7000-8000-000000000004',
            'table' => 'encounter_revisions',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000003',
            'data' => [
                'encounter_id' => '0198a000-0000-7000-8000-000000000002',
                'title' => 'The help I received',
                'body' => 'I remembered that I was not alone.',
                'device_id' => 'test-device',
            ],
        ]],
    ], $overrides);
}

it('applies an encounter and revision atomically', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', encounterBatch())
        ->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(Encounter::first()->user_id)->toBe($user->id)
        ->and(EncounterRevision::count())->toBe(1)
        ->and(SyncOperation::count())->toBe(2);
});

it('treats repeated operation ids as already accepted', function () {
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', encounterBatch())->assertOk();

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', encounterBatch())
        ->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('duplicates', 2);

    expect(Encounter::count())->toBe(1)
        ->and(EncounterRevision::count())->toBe(1);
});

it('applies partial encounter patches without requiring a replacement revision', function () {
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', encounterBatch())->assertOk();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000010',
            'table' => 'encounters',
            'type' => 'patch',
            'id' => '0198a000-0000-7000-8000-000000000002',
            'data' => [
                'is_altar' => true,
                'archived_at' => '2026-08-11T08:00:00.000Z',
                'updated_at' => '2026-08-11T08:00:00.000Z',
            ],
        ]],
    ])->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);

    expect(Encounter::first())
        ->is_altar->toBeTrue()
        ->archived_at->not->toBeNull()
        ->current_revision_id->toBe('0198a000-0000-7000-8000-000000000003');
});

it('rejects updates and deletes for a missing encounter without a server error', function (string $type) {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000015',
            'table' => 'encounters',
            'type' => $type,
            'id' => '0198a000-0000-7000-8000-000000000016',
            'data' => $type === 'patch' ? ['title' => 'Still missing'] : [],
        ]],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'missing_record');
})->with(['patch', 'delete']);

it('never overwrites an existing immutable revision', function () {
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', encounterBatch())->assertOk();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000017',
            'table' => 'encounter_revisions',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000003',
            'data' => [
                'encounter_id' => '0198a000-0000-7000-8000-000000000002',
                'title' => 'Overwritten history',
                'body' => null,
                'device_id' => 'other-device',
            ],
        ]],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'immutable_revision');

    expect(EncounterRevision::first()->title)->toBe('The help I received');
});

it('rejects reuse of an operation id with a different user or payload', function () {
    $firstUser = User::factory()->create();
    $secondUser = User::factory()->create();
    $this->actingAs($firstUser)->postJson('/api/sync/mutations', encounterBatch())->assertOk();

    $changed = encounterBatch();
    $changed['operations'][0]['data']['title'] = 'A different title';
    $this->actingAs($firstUser)->postJson('/api/sync/mutations', $changed)
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'operation_conflict');

    $otherUserOperation = [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000001',
            'table' => 'encounters',
            'type' => 'delete',
            'id' => '0198a000-0000-7000-8000-000000000099',
            'data' => [],
        ]],
    ];
    $this->actingAs($secondUser)->postJson('/api/sync/mutations', $otherUserOperation)
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'operation_conflict');

    expect(Encounter::first()->title)->toBe('The help I received');
});

it('rejects a legacy operation row without fingerprint metadata safely', function () {
    $user = User::factory()->create();
    SyncOperation::create([
        'operation_id' => '0198a000-0000-7000-8000-000000000001',
        'user_id' => $user->id,
        'table_name' => 'encounters',
        'record_id' => '0198a000-0000-7000-8000-000000000002',
        'created_at' => now(),
    ]);

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', encounterBatch())
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 2)
        ->assertJsonPath('code', 'operation_conflict');
});

it('rejects an incomplete encounter revision pair without partial writes', function () {
    $user = User::factory()->create();
    $batch = encounterBatch();
    array_pop($batch['operations']);

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', $batch)
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1);

    expect(Encounter::count())->toBe(0)
        ->and(SyncOperation::count())->toBe(0);
});

it('rejects unknown tables and unauthenticated batches', function () {
    $user = User::factory()->create();
    $batch = encounterBatch([
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000011',
            'table' => 'people',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000012',
            'data' => ['name' => 'Not in this milestone'],
        ]],
    ]);

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', $batch)
        ->assertOk()
        ->assertJsonPath('rejected', 1);

});

it('rejects revision updates and deletes because revisions are immutable', function (string $type) {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000013',
            'table' => 'encounter_revisions',
            'type' => $type,
            'id' => '0198a000-0000-7000-8000-000000000014',
            'data' => [],
        ]],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'immutable_revision');
})->with(['patch', 'delete']);

it('requires authentication', function () {
    $this->postJson('/api/sync/mutations', encounterBatch())->assertUnauthorized();
});

it('rejects another users update without changing the record', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $this->actingAs($owner)->postJson('/api/sync/mutations', encounterBatch())->assertOk();

    $batch = encounterBatch();
    $batch['operations'][0]['operation_id'] = '0198a000-0000-7000-8000-000000000021';
    $batch['operations'][1]['operation_id'] = '0198a000-0000-7000-8000-000000000022';
    $batch['operations'][0]['data']['title'] = 'Changed by someone else';

    $this->actingAs($attacker)
        ->postJson('/api/sync/mutations', $batch)
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 2)
        ->assertJsonPath('code', 'forbidden');

    expect(Encounter::first()->user_id)->toBe($owner->id)
        ->and(Encounter::first()->title)->toBe('The help I received')
        ->and(SyncOperation::count())->toBe(2);
});

it('returns validation errors for a structurally invalid batch', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->postJson('/api/sync/mutations', ['operations' => []])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('operations');
});
