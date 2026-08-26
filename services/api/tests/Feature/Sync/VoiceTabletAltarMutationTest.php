<?php

use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

function voiceTabletOperation(
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

it('creates synchronized Voice Tablet and Altar metadata tables', function () {
    expect(Schema::hasColumns('voice_tablets', [
        'id', 'user_id', 'source_type', 'personal_prayer_id',
        'library_prayer_id', 'prayer_revision_id', 'title',
        'full_audio_id', 'refrain_audio_id', 'recording_device_id',
        'archived_at',
    ]))->toBeTrue()
        ->and(Schema::hasColumns('altar_items', [
            'id', 'user_id', 'target_type', 'encounter_id',
            'personal_prayer_id', 'library_prayer_id', 'voice_tablet_id',
            'archived_at',
        ]))->toBeTrue()
        ->and(Schema::hasColumns('altar_rituals', [
            'id', 'user_id', 'altar_item_id', 'schedule_type', 'local_time',
            'timezone', 'weekdays_mask', 'playback_mode', 'enabled',
            'archived_at',
        ]))->toBeTrue();
});

it('accepts an owned Voice Tablet for one exact prayer revision', function () {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerForVoiceTablet($user);
    $tabletId = '0198ff00-0000-7000-8000-000000000003';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [voiceTabletOperation(
            '0198ff00-0000-7000-8000-000000000004',
            'voice_tablets',
            $tabletId,
            [
                'owner_id' => $user->public_id,
                'source_type' => 'personal_prayer',
                'personal_prayer_id' => $prayer->id,
                'library_prayer_id' => null,
                'prayer_revision_id' => $revision->id,
                'title' => 'Morning surrender',
                'full_audio_id' => '0198ff00-0000-7000-8000-000000000005',
                'refrain_audio_id' => '0198ff00-0000-7000-8000-000000000006',
                'recording_device_id' => 'device-1',
                'created_at' => '2026-08-26T07:00:00.000Z',
                'updated_at' => '2026-08-26T07:00:00.000Z',
                'archived_at' => null,
            ],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);

    expect(DB::table('voice_tablets')->where('id', $tabletId)->value('user_id'))
        ->toBe($user->id);
});

it('creates a daily Altar ritual for a Voice Tablet in the same sync batch', function () {
    $user = User::factory()->create();
    [$prayer, $revision] = ownedPrayerForVoiceTablet($user);
    $tabletId = '0198ff00-0000-7000-8000-000000000010';
    $altarItemId = '0198ff00-0000-7000-8000-000000000011';
    $ritualId = '0198ff00-0000-7000-8000-000000000012';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            voiceTabletOperation('0198ff00-0000-7000-8000-000000000013', 'voice_tablets', $tabletId, [
                'owner_id' => $user->public_id,
                'source_type' => 'personal_prayer',
                'personal_prayer_id' => $prayer->id,
                'library_prayer_id' => null,
                'prayer_revision_id' => $revision->id,
                'title' => 'Return to trust',
                'full_audio_id' => '0198ff00-0000-7000-8000-000000000014',
                'refrain_audio_id' => '0198ff00-0000-7000-8000-000000000015',
                'recording_device_id' => 'device-1',
                'archived_at' => null,
            ]),
            voiceTabletOperation('0198ff00-0000-7000-8000-000000000016', 'altar_items', $altarItemId, [
                'owner_id' => $user->public_id,
                'target_type' => 'voice_tablet',
                'encounter_id' => null,
                'personal_prayer_id' => null,
                'library_prayer_id' => null,
                'voice_tablet_id' => $tabletId,
                'archived_at' => null,
            ]),
            voiceTabletOperation('0198ff00-0000-7000-8000-000000000017', 'altar_rituals', $ritualId, [
                'owner_id' => $user->public_id,
                'altar_item_id' => $altarItemId,
                'schedule_type' => 'daily',
                'local_time' => '07:15',
                'timezone' => 'Africa/Lagos',
                'weekdays_mask' => null,
                'playback_mode' => 'refrain',
                'enabled' => true,
                'archived_at' => null,
            ]),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 3)
        ->assertJsonPath('rejected', 0);

    expect(DB::table('altar_items')->where('id', $altarItemId)->value('voice_tablet_id'))
        ->toBe($tabletId)
        ->and(DB::table('altar_rituals')->where('id', $ritualId)->value('local_time'))
        ->toBe('07:15');
});

it('rejects a Voice Tablet whose revision does not belong to its prayer', function () {
    $user = User::factory()->create();
    [$prayer] = ownedPrayerForVoiceTablet($user);
    $otherPrayer = PersonalPrayer::create([
        'id' => '0198ff00-0000-7000-8000-000000000020',
        'user_id' => $user->id,
        'title' => 'Other prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    $otherRevision = PersonalPrayerRevision::create([
        'id' => '0198ff00-0000-7000-8000-000000000021',
        'prayer_id' => $otherPrayer->id,
        'user_id' => $user->id,
        'body' => 'Father, teach me to listen.',
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [voiceTabletOperation(
            '0198ff00-0000-7000-8000-000000000022',
            'voice_tablets',
            '0198ff00-0000-7000-8000-000000000023',
            [
                'source_type' => 'personal_prayer',
                'personal_prayer_id' => $prayer->id,
                'library_prayer_id' => null,
                'prayer_revision_id' => $otherRevision->id,
                'title' => 'Wrong revision',
                'full_audio_id' => '0198ff00-0000-7000-8000-000000000024',
                'refrain_audio_id' => null,
                'recording_device_id' => 'device-1',
                'archived_at' => null,
            ],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'invalid_revision');
});

function ownedPrayerForVoiceTablet(User $user): array
{
    $prayer = PersonalPrayer::create([
        'id' => '0198ff00-0000-7000-8000-000000000001',
        'user_id' => $user->id,
        'title' => 'Morning surrender',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    $revision = PersonalPrayerRevision::create([
        'id' => '0198ff00-0000-7000-8000-000000000002',
        'prayer_id' => $prayer->id,
        'user_id' => $user->id,
        'body' => 'Father, keep me in your truth today.',
        'action' => null,
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);
    $prayer->forceFill(['current_revision_id' => $revision->id])->save();

    return [$prayer->fresh(), $revision];
}
