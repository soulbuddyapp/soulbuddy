<?php

use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerRevision;
use App\Models\User;
use App\Models\VoiceTablet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function recordedPrayerBatch(User $user): array
{
    $prayerId = (string) Str::uuid();
    $revisionId = (string) Str::uuid();
    $operation = fn (string $table, string $id, array $data): array => [
        'operation_id' => (string) Str::uuid(),
        'table' => $table,
        'type' => 'put',
        'id' => $id,
        'data' => $data,
    ];

    return [
        $operation('personal_prayers', $prayerId, [
            'owner_id' => $user->public_id,
            'title' => 'For my family',
            'style' => 'situational',
            'reach' => 'personal',
            'grounding' => 'general_christian',
            'purpose' => 'family',
            'current_revision_id' => $revisionId,
            'archived_at' => null,
        ]),
        $operation('personal_prayer_revisions', $revisionId, [
            'owner_id' => $user->public_id,
            'prayer_id' => $prayerId,
            'body' => '',
            'content_format' => 'audio',
            'action' => null,
            'device_id' => 'recording-device',
        ]),
        $operation('voice_tablets', (string) Str::uuid(), [
            'owner_id' => $user->public_id,
            'source_type' => 'personal_prayer',
            'personal_prayer_id' => $prayerId,
            'library_prayer_id' => null,
            'prayer_revision_id' => $revisionId,
            'title' => 'For my family',
            'full_audio_id' => (string) Str::uuid(),
            'refrain_audio_id' => null,
            'recording_device_id' => 'recording-device',
            'archived_at' => null,
        ]),
    ];
}

it('accepts a recorded prayer and exact Voice Tablet in one offline batch', function () {
    $user = User::factory()->create();
    $operations = recordedPrayerBatch($user);

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 3)->assertJsonPath('rejected', 0);

    expect(PersonalPrayer::count())->toBe(1)
        ->and(PersonalPrayerRevision::first()->body)->toBe('')
        ->and(PersonalPrayerRevision::first()->content_format)->toBe('audio')
        ->and(VoiceTablet::first()->prayer_revision_id)->toBe($operations[1]['id'])
        ->and(VoiceTablet::first()->user_id)->toBe($user->id);

    $this->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 3)->assertJsonPath('duplicates', 3);
    expect(PersonalPrayer::count())->toBe(1);
});

it('does not create an audio prayer without recording metadata', function () {
    $user = User::factory()->create();
    $operations = array_slice(recordedPrayerBatch($user), 0, 2);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('rejected', 2)->assertJsonPath('code', 'incomplete_audio_prayer');
    expect(PersonalPrayer::count())->toBe(0)
        ->and(PersonalPrayerRevision::count())->toBe(0);
});

it('rolls back an earlier prayer put when a later domain mutation rejects', function () {
    $user = User::factory()->create();
    $operations = recordedPrayerBatch($user);
    $operations[] = [
        'operation_id' => (string) Str::uuid(),
        'table' => 'personal_prayers',
        'type' => 'patch',
        'id' => (string) Str::uuid(),
        'data' => ['title' => 'Missing prayer'],
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('rejected', 4)->assertJsonPath('code', 'inaccessible_record');

    expect(PersonalPrayer::count())->toBe(0)
        ->and(PersonalPrayerRevision::count())->toBe(0)
        ->and(VoiceTablet::count())->toBe(0);
    $this->assertDatabaseCount('sync_operations', 0);
});

it('rejects conflicting new tablet sources before either audio prayer is created', function () {
    $user = User::factory()->create();
    $first = recordedPrayerBatch($user);
    $second = recordedPrayerBatch($user);
    $second[2]['id'] = $first[2]['id'];

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => array_merge($first, $second),
    ])->assertOk()->assertJsonPath('rejected', 6)->assertJsonPath('code', 'conflict');

    expect(PersonalPrayer::count())->toBe(0)
        ->and(PersonalPrayerRevision::count())->toBe(0)
        ->and(VoiceTablet::count())->toBe(0);
    $this->assertDatabaseCount('sync_operations', 0);
});

it('accepts equivalent tablet puts in the same batch without duplicating the recording', function () {
    $user = User::factory()->create();
    $operations = recordedPrayerBatch($user);
    $retry = $operations[2];
    $retry['operation_id'] = (string) Str::uuid();
    $retry['data'] = array_reverse($retry['data'], true);
    $operations[] = $retry;

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 4)->assertJsonPath('rejected', 0);
    expect(PersonalPrayer::count())->toBe(1)->and(VoiceTablet::count())->toBe(1);
});

it('validates recorded and legacy text bodies distinctly', function (string $format, ?string $body) {
    $user = User::factory()->create();
    $operations = recordedPrayerBatch($user);
    $operations[1]['data']['content_format'] = $format;
    $operations[1]['data']['body'] = $body;
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('rejected', 3)->assertJsonPath('code', 'invalid_data');
    expect(PersonalPrayer::count())->toBe(0)->and(VoiceTablet::count())->toBe(0);
})->with([
    'text requires words' => ['text', ''],
    'audio cannot masquerade as text' => ['audio', 'Invented transcript'],
    'unknown content format' => ['video', null],
]);

it('keeps the recorded content format immutable', function () {
    $user = User::factory()->create();
    $operations = recordedPrayerBatch($user);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 3);

    $revision = $operations[1];
    $revision['operation_id'] = (string) Str::uuid();
    $revision['data']['content_format'] = 'text';
    $revision['data']['body'] = 'Replacement words';
    $this->postJson('/api/sync/mutations', ['operations' => [$revision]])
        ->assertOk()->assertJsonPath('rejected', 1)->assertJsonPath('code', 'immutable_revision');
    expect(PersonalPrayerRevision::first()->content_format)->toBe('audio')
        ->and(PersonalPrayerRevision::first()->body)->toBe('');
});

it('rejects a recording pointing to another persons prayer without partial writes', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $owned = recordedPrayerBatch($owner);
    $this->actingAs($owner)->postJson('/api/sync/mutations', ['operations' => $owned])
        ->assertOk()->assertJsonPath('accepted', 3);

    $forged = recordedPrayerBatch($other);
    $forged[0]['id'] = $owned[0]['id'];
    $forged[1]['data']['prayer_id'] = $owned[0]['id'];
    $forged[2]['data']['personal_prayer_id'] = $owned[0]['id'];
    $this->actingAs($other)->postJson('/api/sync/mutations', ['operations' => $forged])
        ->assertOk()->assertJsonPath('rejected', 3);

    expect(PersonalPrayer::count())->toBe(1)
        ->and(PersonalPrayerRevision::count())->toBe(1)
        ->and(VoiceTablet::count())->toBe(1);
});
