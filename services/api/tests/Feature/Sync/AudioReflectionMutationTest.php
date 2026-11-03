<?php

use App\Models\Encounter;
use App\Models\MemoryReflection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function audioReflectionMemoryBatch(): array
{
    $id = (string) Str::uuid();
    $revisionId = (string) Str::uuid();

    return [
        [
            'operation_id' => (string) Str::uuid(),
            'table' => 'encounters',
            'type' => 'put',
            'id' => $id,
            'data' => [
                'title' => 'A memory',
                'body' => '',
                'occurred_on' => '2026-11-03',
                'is_altar' => false,
                'current_revision_id' => $revisionId,
            ],
        ],
        [
            'operation_id' => (string) Str::uuid(),
            'table' => 'encounter_revisions',
            'type' => 'put',
            'id' => $revisionId,
            'data' => [
                'encounter_id' => $id,
                'title' => 'A memory',
                'body' => '',
                'device_id' => 'recording-device',
            ],
        ],
    ];
}

function audioReflectionOperation(string $parentId, ?string $audioId): array
{
    return [
        'operation_id' => (string) Str::uuid(),
        'table' => 'memory_reflections',
        'type' => 'put',
        'id' => (string) Str::uuid(),
        'data' => [
            'encounter_id' => $parentId,
            'body' => '',
            'audio_encounter_id' => $audioId,
            'local_date' => '2026-11-03',
            'created_at' => '2026-11-03T09:00:00.000Z',
            'device_id' => 'recording-device',
        ],
    ];
}

it('keeps the original memory and its audio reflection linked in one batch', function () {
    $user = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $audio = audioReflectionMemoryBatch();
    $reflection = audioReflectionOperation($parent[0]['id'], $audio[0]['id']);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [...$parent, ...$audio, $reflection],
    ])->assertOk()->assertJsonPath('accepted', 5)->assertJsonPath('rejected', 0);

    expect(Encounter::count())->toBe(2)
        ->and(MemoryReflection::first()->body)->toBe('')
        ->and(MemoryReflection::first()->encounter_id)->toBe($parent[0]['id'])
        ->and(MemoryReflection::first()->audio_encounter_id)->toBe($audio[0]['id']);
});

it('keeps an owned reflection reference when its source is archived in the same batch', function () {
    $user = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $audio = audioReflectionMemoryBatch();
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [...$parent, ...$audio],
    ])->assertOk()->assertJsonPath('accepted', 4);
    $reflection = audioReflectionOperation($parent[0]['id'], $audio[0]['id']);
    $archive = [
        'operation_id' => (string) Str::uuid(),
        'table' => 'encounters',
        'type' => 'patch',
        'id' => $audio[0]['id'],
        'data' => ['archived_at' => '2026-11-03T10:00:00.000Z'],
    ];

    $this->postJson('/api/sync/mutations', ['operations' => [$reflection, $archive]])
        ->assertOk()->assertJsonPath('accepted', 2)->assertJsonPath('rejected', 0);

    expect(Encounter::findOrFail($audio[0]['id'])->archived_at)->not->toBeNull()
        ->and(MemoryReflection::first()->audio_encounter_id)->toBe($audio[0]['id']);
});

it('accepts owned archived source metadata first synchronized with its reflection', function () {
    $user = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $audio = audioReflectionMemoryBatch();
    $audio[0]['data']['archived_at'] = '2026-11-03T10:00:00.000Z';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [...$parent, ...$audio,
            audioReflectionOperation($parent[0]['id'], $audio[0]['id'])],
    ])->assertOk()->assertJsonPath('accepted', 5)->assertJsonPath('rejected', 0);

    expect(MemoryReflection::first()->audio_encounter_id)->toBe($audio[0]['id']);
});

it('does not attach another persons recording as a reflection', function (bool $archived) {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $audio = audioReflectionMemoryBatch();
    if ($archived) {
        $audio[0]['data']['archived_at'] = '2026-11-03T10:00:00.000Z';
    }
    $this->actingAs($owner)->postJson('/api/sync/mutations', ['operations' => $parent])
        ->assertOk()->assertJsonPath('accepted', 2);
    $this->actingAs($other)->postJson('/api/sync/mutations', ['operations' => $audio])
        ->assertOk()->assertJsonPath('accepted', 2);
    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [audioReflectionOperation($parent[0]['id'], $audio[0]['id'])],
    ])->assertOk()->assertJsonPath('rejected', 1)->assertJsonPath('code', 'inaccessible_record');

    expect(MemoryReflection::count())->toBe(0);
})->with(['active foreign target' => [false], 'archived foreign target' => [true]]);

it('rejects a nonexistent recording reference without a server error', function () {
    $user = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $parent])
        ->assertOk()->assertJsonPath('accepted', 2);

    $this->postJson('/api/sync/mutations', [
        'operations' => [audioReflectionOperation($parent[0]['id'], (string) Str::uuid())],
    ])->assertOk()->assertJsonPath('rejected', 1)->assertJsonPath('code', 'inaccessible_record');

    expect(MemoryReflection::count())->toBe(0);
});

it('rejects a reflection with neither words nor a recording reference', function () {
    $user = User::factory()->create();
    $parent = audioReflectionMemoryBatch();
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $parent])
        ->assertOk()->assertJsonPath('accepted', 2);
    $this->postJson('/api/sync/mutations', [
        'operations' => [audioReflectionOperation($parent[0]['id'], null)],
    ])->assertOk()->assertJsonPath('rejected', 1)->assertJsonPath('code', 'invalid_data');
    expect(MemoryReflection::count())->toBe(0);
});
