<?php

use App\Models\LibraryPrayer;
use App\Models\PersonalPrayer;
use App\Models\PrayerPerson;
use App\Models\SacredHour;
use App\Models\SacredHourOccurrence;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

function sacredHourOperation(
    string $operationId,
    string $table,
    string $type,
    string $id,
    array $data = [],
): array {
    return [
        'operation_id' => $operationId,
        'table' => $table,
        'type' => $type,
        'id' => $id,
        'data' => $data,
    ];
}

function sacredHourPut(
    string $hourId,
    string $operationId = '0198d000-0000-7000-8000-000000000001',
    array $overrides = [],
): array {
    return sacredHourOperation($operationId, 'sacred_hours', 'put', $hourId, array_merge([
        'owner_id' => 'offline-owner',
        'purpose_key' => 'morning',
        'name' => 'Morning Sacred Hour',
        'local_time' => '06:00',
        'timezone' => 'Africa/Lagos',
        'duration_minutes' => 60,
        'prayer_minutes' => 15,
        'enabled' => true,
        'sound_key' => 'gentle_chime',
        'prayer_type' => null,
        'prayer_id' => null,
        'person_id' => null,
        'created_at' => '2026-08-31T05:00:00.000Z',
        'updated_at' => '2026-08-31T05:00:00.000Z',
        'archived_at' => null,
    ], $overrides));
}

it('creates two defaults in one batch and replays idempotently', function () {
    $user = User::factory()->create();
    expect(Schema::hasColumns('sacred_hours', [
        'purpose_key', 'local_time', 'duration_minutes', 'prayer_minutes',
        'sound_key', 'prayer_type', 'prayer_id', 'person_id', 'archived_at',
    ]))->toBeTrue()
        ->and(Schema::hasColumns('sacred_hour_occurrences', [
            'sacred_hour_id', 'due_at', 'local_date', 'status', 'prayer_session_id',
        ]))->toBeTrue();
    $morningId = '0198d000-0000-7000-8000-000000000010';
    $eveningId = '0198d000-0000-7000-8000-000000000011';
    $operations = [
        sacredHourPut($morningId),
        sacredHourPut($eveningId, '0198d000-0000-7000-8000-000000000002', [
            'purpose_key' => 'evening',
            'name' => 'Evening Sacred Hour',
            'local_time' => '22:00',
            'sound_key' => 'evening_chime',
        ]),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 2);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('duplicates', 2);

    expect(SacredHour::where('user_id', $user->id)->count())->toBe(2)
        ->and(SacredHour::findOrFail($morningId)->sound_key)->toBe('gentle_chime');
});

it('rejects invalid fixed shape and prayer references', function (array $overrides) {
    $user = User::factory()->create();
    $operation = sacredHourPut(
        '0198d000-0000-7000-8000-000000000020',
        '0198d001-0000-7000-8000-000000000001',
        $overrides,
    );

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()->assertJsonPath('code', 'invalid_data');
})->with([
    'duration is fixed' => [['duration_minutes' => 45]],
    'prayer opening choice' => [['prayer_minutes' => 20]],
    'known sound' => [['sound_key' => 'cathedral_boom']],
    'paired prayer reference' => [['prayer_type' => 'library', 'prayer_id' => null]],
    'custom purpose is null' => [['purpose_key' => 'custom']],
]);

it('accepts owned Prayer and Person links and rejects cross-owner links', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $person = PrayerPerson::create([
        'id' => '0198d000-0000-7000-8000-000000000030',
        'user_id' => $owner->id,
        'name' => 'Mum',
        'cadence' => 'daily',
        'weekdays_mask' => 0,
    ]);
    $prayer = LibraryPrayer::create([
        'id' => '0198d000-0000-7000-8000-000000000031',
        'title' => 'For this day',
        'body' => 'Father, lead me today. Amen.',
        'grounding' => 'general_christian',
        'language_style' => 'daily',
        'purpose' => 'daily',
        'helpful_count' => 0,
        'published_at' => now(),
    ]);
    $linked = sacredHourPut(
        '0198d000-0000-7000-8000-000000000032',
        '0198d002-0000-7000-8000-000000000001',
        [
            'purpose_key' => null,
            'prayer_type' => 'library',
            'prayer_id' => $prayer->id,
            'person_id' => $person->id,
        ],
    );
    $this->actingAs($owner)->postJson('/api/sync/mutations', ['operations' => [$linked]])
        ->assertOk()->assertJsonPath('accepted', 1);

    $crossOwner = sacredHourPut(
        '0198d000-0000-7000-8000-000000000033',
        '0198d002-0000-7000-8000-000000000002',
        ['purpose_key' => null, 'person_id' => $person->id],
    );
    $this->actingAs($other)->postJson('/api/sync/mutations', ['operations' => [$crossOwner]])
        ->assertOk()->assertJsonPath('code', 'inaccessible_record');

    $personalPrayer = PersonalPrayer::create([
        'id' => '0198d000-0000-7000-8000-000000000034',
        'user_id' => $owner->id,
        'title' => 'A prayer I saved',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
    ]);
    $crossOwnerPrayer = sacredHourPut(
        '0198d000-0000-7000-8000-000000000035',
        '0198d002-0000-7000-8000-000000000003',
        [
            'purpose_key' => null,
            'prayer_type' => 'personal',
            'prayer_id' => $personalPrayer->id,
        ],
    );
    $this->actingAs($other)->postJson('/api/sync/mutations', ['operations' => [$crossOwnerPrayer]])
        ->assertOk()->assertJsonPath('code', 'inaccessible_record');
});

it('stores one occurrence per hour and due instant while allowing status updates', function () {
    $user = User::factory()->create();
    $hourId = '0198d000-0000-7000-8000-000000000040';
    $occurrenceId = '0198d000-0000-7000-8000-000000000041';
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [sacredHourPut($hourId, '0198d003-0000-7000-8000-000000000001')],
    ])->assertOk();
    $put = sacredHourOperation(
        '0198d003-0000-7000-8000-000000000002',
        'sacred_hour_occurrences',
        'put',
        $occurrenceId,
        [
            'owner_id' => 'offline-owner',
            'sacred_hour_id' => $hourId,
            'due_at' => '2026-08-31T05:00:00.000Z',
            'local_date' => '2026-08-31',
            'status' => 'begun',
            'prayer_session_id' => null,
            'created_at' => '2026-08-31T05:00:00.000Z',
            'updated_at' => '2026-08-31T05:00:00.000Z',
        ],
    );
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$put]])
        ->assertOk()->assertJsonPath('accepted', 1);
    $patch = sacredHourOperation(
        '0198d003-0000-7000-8000-000000000003',
        'sacred_hour_occurrences',
        'patch',
        $occurrenceId,
        ['status' => 'completed', 'updated_at' => '2026-08-31T05:15:00.000Z'],
    );
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$patch]])
        ->assertOk()->assertJsonPath('accepted', 1);

    $duplicateDue = $put;
    $duplicateDue['operation_id'] = '0198d003-0000-7000-8000-000000000004';
    $duplicateDue['id'] = '0198d000-0000-7000-8000-000000000042';
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$duplicateDue]])
        ->assertOk()->assertJsonPath('code', 'conflict');

    expect(SacredHourOccurrence::count())->toBe(1)
        ->and(SacredHourOccurrence::firstOrFail()->status)->toBe('completed');
});

it('soft archives an hour and disables it', function () {
    $user = User::factory()->create();
    $hourId = '0198d000-0000-7000-8000-000000000050';
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [sacredHourPut($hourId, '0198d004-0000-7000-8000-000000000001')],
    ])->assertOk();

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [
        sacredHourOperation(
            '0198d004-0000-7000-8000-000000000002',
            'sacred_hours',
            'delete',
            $hourId,
        ),
    ]])->assertOk()->assertJsonPath('accepted', 1);

    $hour = SacredHour::findOrFail($hourId);
    expect($hour->enabled)->toBeFalse()->and($hour->archived_at)->not->toBeNull();
});
