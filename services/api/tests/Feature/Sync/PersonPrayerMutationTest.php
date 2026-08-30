<?php

use App\Models\Encounter;
use App\Models\EncounterPersonLink;
use App\Models\PersonPrayerOccurrence;
use App\Models\PrayerPerson;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function personOperation(string $operationId, string $table, string $type, string $id, array $data = []): array
{
    return [
        'operation_id' => $operationId,
        'table' => $table,
        'type' => $type,
        'id' => $id,
        'data' => $data,
    ];
}

function personPut(string $personId, string $operationId = '0198c000-0000-7000-8000-000000000001'): array
{
    return personOperation($operationId, 'prayer_people', 'put', $personId, [
        'owner_id' => 'offline-owner',
        'name' => 'Mum',
        'relationship' => 'Mother',
        'cadence' => 'daily',
        'local_time' => '07:30',
        'timezone' => 'Africa/Lagos',
        'weekdays_mask' => 0,
        'created_at' => '2026-08-30T08:00:00.000Z',
        'updated_at' => '2026-08-30T08:00:00.000Z',
        'archived_at' => null,
    ]);
}

it('creates a prayer person and replays the same operation idempotently', function () {
    $user = User::factory()->create();
    $personId = '0198c000-0000-7000-8000-000000000010';
    $operation = personPut($personId);

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()->assertJsonPath('accepted', 1);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()->assertJsonPath('duplicates', 1);

    expect(PrayerPerson::findOrFail($personId)->user_id)->toBe($user->id);
});

it('rejects cross-owner person edits', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $personId = '0198c000-0000-7000-8000-000000000020';
    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [personPut($personId, '0198c001-0000-7000-8000-000000000001')],
    ])->assertOk();

    $this->actingAs($attacker)->postJson('/api/sync/mutations', ['operations' => [
        personOperation(
            '0198c001-0000-7000-8000-000000000002',
            'prayer_people',
            'patch',
            $personId,
            ['name' => 'Changed'],
        ),
    ]])->assertOk()->assertJsonPath('code', 'inaccessible_record');
});

it('keeps prayer occurrence identity immutable and idempotent by date', function () {
    $user = User::factory()->create();
    $personId = '0198c000-0000-7000-8000-000000000030';
    $occurrenceId = '0198c000-0000-7000-8000-000000000031';
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [personPut($personId, '0198c002-0000-7000-8000-000000000001')],
    ])->assertOk();
    $operation = personOperation(
        '0198c002-0000-7000-8000-000000000002',
        'person_prayer_occurrences',
        'put',
        $occurrenceId,
        [
            'owner_id' => 'offline-owner',
            'person_id' => $personId,
            'local_date' => '2026-08-30',
            'occurrence_key' => $personId.':2026-08-30',
            'prayed_at' => '2026-08-30T08:00:00.000Z',
            'device_id' => 'device-1',
        ],
    );
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()->assertJsonPath('accepted', 1);

    $operation['operation_id'] = '0198c002-0000-7000-8000-000000000003';
    $operation['type'] = 'patch';
    $operation['data'] = ['local_date' => '2026-08-31'];
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()->assertJsonPath('code', 'immutable_occurrence');
    expect(PersonPrayerOccurrence::count())->toBe(1);
});

it('links only an owned encounter to an owned person', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $personId = '0198c000-0000-7000-8000-000000000040';
    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [personPut($personId, '0198c003-0000-7000-8000-000000000001')],
    ])->assertOk();
    $encounter = Encounter::create([
        'id' => '0198c000-0000-7000-8000-000000000041',
        'user_id' => $other->id,
        'title' => 'Private', 'body' => '', 'occurred_on' => '2026-08-30',
        'is_altar' => false,
        'current_revision_id' => '0198c000-0000-7000-8000-000000000049',
    ]);
    $link = personOperation(
        '0198c003-0000-7000-8000-000000000002',
        'encounter_person_links',
        'put',
        '0198c000-0000-7000-8000-000000000042',
        [
            'owner_id' => 'offline-owner', 'encounter_id' => $encounter->id,
            'person_id' => $personId, 'created_at' => '2026-08-30T08:00:00.000Z',
        ],
    );

    $this->actingAs($owner)->postJson('/api/sync/mutations', ['operations' => [$link]])
        ->assertOk()->assertJsonPath('code', 'inaccessible_record');
    expect(EncounterPersonLink::count())->toBe(0);
});

it('accepts a new encounter and its person link in the same offline batch', function () {
    $user = User::factory()->create();
    $personId = '0198c000-0000-7000-8000-000000000050';
    $encounterId = '0198c000-0000-7000-8000-000000000051';
    $revisionId = '0198c000-0000-7000-8000-000000000052';
    $linkId = '0198c000-0000-7000-8000-000000000053';

    $operations = [
        personPut($personId, '0198c004-0000-7000-8000-000000000001'),
        personOperation(
            '0198c004-0000-7000-8000-000000000002',
            'encounter_person_links',
            'put',
            $linkId,
            [
                'owner_id' => 'offline-owner',
                'encounter_id' => $encounterId,
                'person_id' => $personId,
                'created_at' => '2026-08-30T08:00:00.000Z',
            ],
        ),
        personOperation(
            '0198c004-0000-7000-8000-000000000003',
            'encounters',
            'put',
            $encounterId,
            [
                'title' => 'Help for Mum',
                'body' => 'I remembered her in prayer.',
                'occurred_on' => '2026-08-30',
                'is_altar' => false,
                'current_revision_id' => $revisionId,
            ],
        ),
        personOperation(
            '0198c004-0000-7000-8000-000000000004',
            'encounter_revisions',
            'put',
            $revisionId,
            [
                'encounter_id' => $encounterId,
                'title' => 'Help for Mum',
                'body' => 'I remembered her in prayer.',
                'device_id' => 'device-1',
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 4)
        ->assertJsonPath('rejected', 0);

    expect(Encounter::find($encounterId)?->user_id)->toBe($user->id)
        ->and(EncounterPersonLink::find($linkId)?->user_id)->toBe($user->id);
});
