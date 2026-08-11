<?php

use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\PrayerReminder;
use App\Models\PrayerSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

function practiceOperation(
    string $operationId,
    string $table,
    string $id,
    array $data,
    string $type = 'put',
): array {
    return [
        'operation_id' => $operationId,
        'table' => $table,
        'type' => $type,
        'id' => $id,
        'data' => $data,
    ];
}

function seedPracticePrayer(User $user, string $suffix = '001'): array
{
    $prayerId = "0198aa00-0000-7000-8000-000000000{$suffix}";
    $revisionId = "0198aa00-0000-7000-8000-000000001{$suffix}";
    PersonalPrayer::create([
        'id' => $prayerId,
        'user_id' => $user->id,
        'title' => 'A private prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    PersonalPrayerRevision::create([
        'id' => $revisionId,
        'prayer_id' => $prayerId,
        'user_id' => $user->id,
        'body' => 'Father, keep me near you today. Amen.',
        'action' => null,
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);
    PersonalPrayer::whereKey($prayerId)->update([
        'current_revision_id' => $revisionId,
    ]);

    return [$prayerId, $revisionId];
}

function reminderData(string $prayerId, array $overrides = []): array
{
    return array_replace([
        'owner_id' => 'ignored-client-owner',
        'personal_prayer_id' => $prayerId,
        'schedule_type' => 'daily',
        'local_time' => '07:30',
        'timezone' => 'Africa/Lagos',
        'once_at' => null,
        'weekdays_mask' => null,
        'enabled' => true,
        'created_at' => '2026-08-11T07:00:00.000Z',
        'updated_at' => '2026-08-11T07:00:00.000Z',
        'archived_at' => null,
    ], $overrides);
}

function sessionData(
    string $prayerId,
    string $revisionId,
    array $overrides = [],
): array {
    return array_replace([
        'owner_id' => 'ignored-client-owner',
        'personal_prayer_id' => $prayerId,
        'prayer_revision_id' => $revisionId,
        'reminder_id' => null,
        'reminder_occurrence_key' => null,
        'source' => 'manual',
        'occurred_at' => '2026-08-11T07:00:00.000Z',
        'local_date' => '2026-08-11',
        'timezone' => 'Africa/Lagos',
        'device_id' => 'device-1',
        'retracted_at' => null,
    ], $overrides);
}

it('creates private reminder and exact-revision session schema', function () {
    expect(Schema::hasColumns('prayer_reminders', [
        'id', 'user_id', 'personal_prayer_id', 'schedule_type', 'local_time',
        'timezone', 'once_at', 'weekdays_mask', 'enabled', 'created_at',
        'updated_at', 'archived_at',
    ]))->toBeTrue()
        ->and(Schema::hasColumns('prayer_sessions', [
            'id', 'user_id', 'personal_prayer_id', 'prayer_revision_id',
            'reminder_id', 'reminder_occurrence_key', 'source', 'occurred_at',
            'local_date', 'timezone', 'device_id', 'retracted_at',
        ]))->toBeTrue();
});

it('accepts a daily reminder and manual exact-revision session', function () {
    $user = User::factory()->create();
    [$prayerId, $revisionId] = seedPracticePrayer($user);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            practiceOperation(
                '0198aa00-0000-7000-8000-000000000010',
                'prayer_reminders',
                '0198aa00-0000-7000-8000-000000000011',
                reminderData($prayerId),
            ),
            practiceOperation(
                '0198aa00-0000-7000-8000-000000000012',
                'prayer_sessions',
                '0198aa00-0000-7000-8000-000000000013',
                sessionData($prayerId, $revisionId),
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(PrayerReminder::first()->user_id)->toBe($user->id)
        ->and(PrayerSession::first()->user_id)->toBe($user->id)
        ->and(PrayerSession::first()->prayer_revision_id)->toBe($revisionId);
});

it('rejects reuse of a reminder id with different schedule content', function () {
    $user = User::factory()->create();
    [$prayerId] = seedPracticePrayer($user, '014');
    $reminderId = '0198aa00-0000-7000-8000-000000000015';
    PrayerReminder::create([
        'id' => $reminderId,
        'user_id' => $user->id,
        'personal_prayer_id' => $prayerId,
        'schedule_type' => 'daily',
        'local_time' => '07:30',
        'timezone' => 'Africa/Lagos',
        'enabled' => true,
    ]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000016',
            'prayer_reminders',
            $reminderId,
            reminderData($prayerId, ['local_time' => '08:30']),
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'conflict');

    expect(PrayerReminder::findOrFail($reminderId)->local_time)->toBe('07:30');
});

it('validates each reminder schedule shape', function (array $overrides) {
    $user = User::factory()->create();
    [$prayerId] = seedPracticePrayer($user);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000020',
            'prayer_reminders',
            '0198aa00-0000-7000-8000-000000000021',
            reminderData($prayerId, $overrides),
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'invalid_data');
})->with([
    'daily cannot carry once_at' => [['once_at' => '2026-08-12T07:30:00.000Z']],
    'once requires once_at' => [['schedule_type' => 'once']],
    'weekdays requires a mask' => [['schedule_type' => 'weekdays']],
    'daily cannot carry weekdays' => [['weekdays_mask' => 5]],
    'weekday mask cannot be zero' => [['schedule_type' => 'weekdays', 'weekdays_mask' => 0]],
    'local time must be real' => [['local_time' => '25:00']],
    'timezone must be IANA' => [['timezone' => 'Not/AZone']],
    'unknown fields are rejected' => [['prayer_body' => 'private']],
]);

it('does not reveal whether a foreign or missing private prayer exists', function (bool $foreign) {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    [$foreignPrayerId] = seedPracticePrayer($owner);
    $prayerId = $foreign
        ? $foreignPrayerId
        : '0198aa00-0000-7000-8000-000000000099';

    $this->actingAs($attacker)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000030',
            'prayer_reminders',
            '0198aa00-0000-7000-8000-000000000031',
            reminderData($prayerId),
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'inaccessible_record');
})->with([true, false]);

it('requires a session revision to belong to the selected prayer', function () {
    $user = User::factory()->create();
    [$firstPrayerId] = seedPracticePrayer($user, '041');
    [, $secondRevisionId] = seedPracticePrayer($user, '042');

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000043',
            'prayer_sessions',
            '0198aa00-0000-7000-8000-000000000044',
            sessionData($firstPrayerId, $secondRevisionId),
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'invalid_revision');
});

it('treats replay of one reminder occurrence as one session', function () {
    $user = User::factory()->create();
    [$prayerId, $revisionId] = seedPracticePrayer($user, '051');
    $reminderId = '0198aa00-0000-7000-8000-000000000052';
    $sessionId = '0198aa00-0000-5000-8000-000000000053';
    $occurrence = "$reminderId@2026-08-11T07:30:00.000Z";
    PrayerReminder::create([
        'id' => $reminderId,
        'user_id' => $user->id,
        'personal_prayer_id' => $prayerId,
        'schedule_type' => 'daily',
        'local_time' => '07:30',
        'timezone' => 'Africa/Lagos',
        'enabled' => true,
    ]);
    $payload = sessionData($prayerId, $revisionId, [
        'reminder_id' => $reminderId,
        'reminder_occurrence_key' => $occurrence,
        'source' => 'reminder',
    ]);

    foreach ([
        '0198aa00-0000-7000-8000-000000000054',
        '0198aa00-0000-7000-8000-000000000055',
    ] as $operationId) {
        $this->actingAs($user)->postJson('/api/sync/mutations', [
            'operations' => [practiceOperation(
                $operationId,
                'prayer_sessions',
                $sessionId,
                $payload,
            )],
        ])->assertOk()->assertJsonPath('accepted', 1);
    }

    expect(PrayerSession::count())->toBe(1)
        ->and(PrayerSession::first()->reminder_occurrence_key)->toBe($occurrence);
});

it('allows only retracted_at to change and enforces the five minute window', function () {
    $user = User::factory()->create();
    [$prayerId, $revisionId] = seedPracticePrayer($user, '061');
    $sessionId = '0198aa00-0000-7000-8000-000000000062';
    PrayerSession::create([
        'id' => $sessionId,
        'user_id' => $user->id,
        'personal_prayer_id' => $prayerId,
        'prayer_revision_id' => $revisionId,
        'source' => 'manual',
        'occurred_at' => '2026-08-11T07:00:00.000Z',
        'local_date' => '2026-08-11',
        'timezone' => 'Africa/Lagos',
        'device_id' => 'device-1',
    ]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000063',
            'prayer_sessions',
            $sessionId,
            ['retracted_at' => '2026-08-11T07:04:59.000Z'],
            'patch',
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000064',
            'prayer_sessions',
            $sessionId,
            ['prayer_revision_id' => $revisionId],
            'patch',
        )],
    ])->assertOk()->assertJsonPath('code', 'immutable_session');

    expect(PrayerSession::findOrFail($sessionId)->retracted_at)->not->toBeNull();
});

it('rejects a retraction timestamp after five minutes', function () {
    $user = User::factory()->create();
    [$prayerId, $revisionId] = seedPracticePrayer($user, '071');
    $sessionId = '0198aa00-0000-7000-8000-000000000072';
    PrayerSession::create([
        'id' => $sessionId,
        'user_id' => $user->id,
        'personal_prayer_id' => $prayerId,
        'prayer_revision_id' => $revisionId,
        'source' => 'manual',
        'occurred_at' => '2026-08-11T07:00:00.000Z',
        'local_date' => '2026-08-11',
        'timezone' => 'Africa/Lagos',
        'device_id' => 'device-1',
    ]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation(
            '0198aa00-0000-7000-8000-000000000073',
            'prayer_sessions',
            $sessionId,
            ['retracted_at' => '2026-08-11T07:05:01.000Z'],
            'patch',
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'retraction_window_closed');
});

it('rolls back a valid reminder when a session in the batch is invalid', function () {
    $user = User::factory()->create();
    [$prayerId] = seedPracticePrayer($user, '081');

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            practiceOperation(
                '0198aa00-0000-7000-8000-000000000082',
                'prayer_reminders',
                '0198aa00-0000-7000-8000-000000000083',
                reminderData($prayerId),
            ),
            practiceOperation(
                '0198aa00-0000-7000-8000-000000000084',
                'prayer_sessions',
                '0198aa00-0000-7000-8000-000000000085',
                sessionData(
                    $prayerId,
                    '0198aa00-0000-7000-8000-000000000099',
                ),
            ),
        ],
    ])->assertOk()->assertJsonPath('accepted', 0);

    expect(PrayerReminder::count())->toBe(0)
        ->and(PrayerSession::count())->toBe(0);
});
