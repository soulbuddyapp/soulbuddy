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
