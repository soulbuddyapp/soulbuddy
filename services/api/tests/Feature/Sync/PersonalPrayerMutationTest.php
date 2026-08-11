<?php

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\PersonalPrayer;
use App\Models\PersonalPrayerLink;
use App\Models\PersonalPrayerRevision;
use App\Models\TodayPrayer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

function personalPrayerOperation(
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

it('creates the private prayer schema and typed Today source', function () {
    expect(Schema::hasColumns('personal_prayers', [
        'id',
        'user_id',
        'title',
        'style',
        'reach',
        'grounding',
        'purpose',
        'current_revision_id',
        'archived_at',
    ]))->toBeTrue()
        ->and(Schema::hasColumn('today_prayers', 'personal_prayer_id'))->toBeTrue();
});

it('accepts a complete prayer revision and structured Scripture link', function () {
    $user = User::factory()->create();
    $prayerId = '0198a800-0000-7000-8000-000000000001';
    $revisionId = '0198a800-0000-7000-8000-000000000002';
    $linkId = '0198a800-0000-7000-8000-000000000003';

    $operations = [
        personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000011',
            'personal_prayers',
            $prayerId,
            [
                'owner_id' => $user->public_id,
                'title' => 'The prayer Jesus taught',
                'style' => 'daily',
                'reach' => 'encompassing',
                'grounding' => 'general_christian',
                'purpose' => 'daily',
                'current_revision_id' => $revisionId,
                'created_at' => '2026-08-11T08:00:00.000Z',
                'updated_at' => '2026-08-11T08:00:00.000Z',
                'archived_at' => null,
            ],
        ),
        personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000012',
            'personal_prayer_revisions',
            $revisionId,
            [
                'owner_id' => $user->public_id,
                'prayer_id' => $prayerId,
                'body' => 'Our Father in heaven, hallowed be your name. Amen.',
                'action' => null,
                'device_id' => 'device-1',
                'created_at' => '2026-08-11T08:00:00.000Z',
            ],
        ),
        personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000013',
            'personal_prayer_links',
            $linkId,
            [
                'owner_id' => $user->public_id,
                'prayer_id' => $prayerId,
                'link_type' => 'scripture',
                'encounter_id' => null,
                'translation' => 'RSVCE',
                'book' => 'Matthew',
                'chapter' => 6,
                'first_verse' => 9,
                'last_verse' => 13,
                'created_at' => '2026-08-11T08:00:00.000Z',
            ],
        ),
        personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000014',
            'today_prayers',
            '0198a800-0000-7000-8000-000000000004',
            [
                'local_date' => '2026-08-11',
                'personal_prayer_id' => $prayerId,
                'include_action' => true,
                'action_completed' => false,
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => $operations,
    ])->assertOk()
        ->assertJsonPath('accepted', 4)
        ->assertJsonPath('rejected', 0);

    expect(PersonalPrayer::count())->toBe(1)
        ->and(PersonalPrayerRevision::count())->toBe(1)
        ->and(PersonalPrayerLink::count())->toBe(1)
        ->and(PersonalPrayer::first()->user_id)->toBe($user->id)
        ->and(TodayPrayer::first()->personal_prayer_id)->toBe($prayerId);
});

it('rejects an incomplete prayer revision pair without writing', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000021',
            'personal_prayers',
            '0198a800-0000-7000-8000-000000000022',
            [
                'title' => 'Missing revision',
                'style' => 'daily',
                'reach' => 'personal',
                'grounding' => 'general_christian',
                'purpose' => 'daily',
                'current_revision_id' => '0198a800-0000-7000-8000-000000000023',
                'archived_at' => null,
            ],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'incomplete_revision_pair');

    expect(PersonalPrayer::count())->toBe(0);
});

it('preserves incomplete pair precedence over malformed prayer data', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000024',
            'personal_prayers',
            '0198a800-0000-7000-8000-000000000025',
            ['current_revision_id' => '0198a800-0000-7000-8000-000000000026'],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'incomplete_revision_pair');
});

it('keeps personal prayer revisions immutable', function (string $type) {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000031',
            'personal_prayer_revisions',
            '0198a800-0000-7000-8000-000000000032',
            $type === 'delete' ? [] : ['body' => 'Changed'],
            $type,
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'immutable_revision');
})->with(['patch', 'delete']);

it('rejects foreign Encounter links and malformed Scripture links', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $encounterId = '0198a800-0000-7000-8000-000000000041';
    $revisionId = '0198a800-0000-7000-8000-000000000042';
    Encounter::create([
        'id' => $encounterId,
        'user_id' => $other->id,
        'title' => 'Private encounter',
        'body' => null,
        'occurred_on' => '2026-08-11',
        'is_altar' => true,
        'current_revision_id' => $revisionId,
    ]);
    EncounterRevision::create([
        'id' => $revisionId,
        'encounter_id' => $encounterId,
        'user_id' => $other->id,
        'title' => 'Private encounter',
        'body' => null,
        'device_id' => 'device-2',
        'created_at' => now(),
    ]);

    foreach ([
        [
            'link_type' => 'encounter',
            'encounter_id' => $encounterId,
            'translation' => null,
            'book' => null,
            'chapter' => null,
            'first_verse' => null,
            'last_verse' => null,
        ],
        [
            'link_type' => 'scripture',
            'encounter_id' => null,
            'translation' => 'RSVCE',
            'book' => 'Matthew',
            'chapter' => 6,
            'first_verse' => 13,
            'last_verse' => 9,
        ],
    ] as $index => $link) {
        $prayerId = sprintf('0198a800-0000-7000-8000-%012d', 50 + $index);
        $currentRevisionId = sprintf('0198a800-0000-7000-8000-%012d', 60 + $index);
        $operations = [
            personalPrayerOperation(
                sprintf('0198a800-0000-7000-8000-%012d', 70 + ($index * 3)),
                'personal_prayers',
                $prayerId,
                [
                    'title' => 'Linked prayer',
                    'style' => 'daily',
                    'reach' => 'personal',
                    'grounding' => 'general_christian',
                    'purpose' => 'guidance',
                    'current_revision_id' => $currentRevisionId,
                    'archived_at' => null,
                ],
            ),
            personalPrayerOperation(
                sprintf('0198a800-0000-7000-8000-%012d', 71 + ($index * 3)),
                'personal_prayer_revisions',
                $currentRevisionId,
                [
                    'prayer_id' => $prayerId,
                    'body' => 'Father, guide me. Amen.',
                    'action' => null,
                    'device_id' => 'device-1',
                ],
            ),
            personalPrayerOperation(
                sprintf('0198a800-0000-7000-8000-%012d', 72 + ($index * 3)),
                'personal_prayer_links',
                sprintf('0198a800-0000-7000-8000-%012d', 80 + $index),
                ['prayer_id' => $prayerId] + $link,
            ),
        ];

        $this->actingAs($owner)->postJson('/api/sync/mutations', [
            'operations' => $operations,
        ])->assertOk()
            ->assertJsonPath('accepted', 0)
            ->assertJsonPath('code', 'invalid_link');
    }

    expect(PersonalPrayer::count())->toBe(0)
        ->and(PersonalPrayerLink::count())->toBe(0);
});

it('rolls back the whole accepted prayer batch on a link conflict', function () {
    $user = User::factory()->create();
    $prayerId = '0198a800-0000-7000-8000-000000000091';
    $revisionId = '0198a800-0000-7000-8000-000000000092';
    $linkId = '0198a800-0000-7000-8000-000000000093';
    $link = [
        'prayer_id' => $prayerId,
        'link_type' => 'scripture',
        'encounter_id' => null,
        'translation' => 'RSVCE',
        'book' => 'Matthew',
        'chapter' => 6,
        'first_verse' => 9,
        'last_verse' => 13,
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000094',
                'personal_prayers',
                $prayerId,
                [
                    'title' => 'Rollback prayer',
                    'style' => 'daily',
                    'reach' => 'personal',
                    'grounding' => 'catholic',
                    'purpose' => 'daily',
                    'current_revision_id' => $revisionId,
                    'archived_at' => null,
                ],
            ),
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000095',
                'personal_prayer_revisions',
                $revisionId,
                [
                    'prayer_id' => $prayerId,
                    'body' => 'Father, lead me. Amen.',
                    'action' => null,
                    'device_id' => 'device-1',
                ],
            ),
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000096',
                'personal_prayer_links',
                $linkId,
                $link,
            ),
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000097',
                'personal_prayer_links',
                $linkId,
                $link,
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'conflict');

    expect(PersonalPrayer::count())->toBe(0)
        ->and(PersonalPrayerRevision::count())->toBe(0)
        ->and(PersonalPrayerLink::count())->toBe(0);
});

it('selects exactly one owned personal prayer for Today', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $prayerId = '0198a800-0000-7000-8000-000000000101';
    $revisionId = '0198a800-0000-7000-8000-000000000102';
    PersonalPrayer::create([
        'id' => $prayerId,
        'user_id' => $owner->id,
        'title' => 'Private prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    PersonalPrayerRevision::create([
        'id' => $revisionId,
        'prayer_id' => $prayerId,
        'user_id' => $owner->id,
        'body' => 'Father, guide me today. Amen.',
        'action' => null,
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);
    PersonalPrayer::whereKey($prayerId)->update(['current_revision_id' => $revisionId]);

    $operation = fn (User $user, string $operationId, string $recordId, array $data) => [
        'operations' => [personalPrayerOperation(
            $operationId,
            'today_prayers',
            $recordId,
            ['local_date' => '2026-08-11', 'include_action' => true, 'action_completed' => false] + $data,
        )],
    ];
    $this->actingAs($owner)->postJson('/api/sync/mutations', $operation(
        $owner,
        '0198a800-0000-7000-8000-000000000103',
        '0198a800-0000-7000-8000-000000000104',
        ['personal_prayer_id' => $prayerId],
    ))->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [personalPrayerOperation(
            '0198a800-0000-7000-8000-000000000109',
            'today_prayers',
            '0198a800-0000-7000-8000-000000000104',
            ['action_completed' => true],
            'patch',
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($attacker)->postJson('/api/sync/mutations', $operation(
        $attacker,
        '0198a800-0000-7000-8000-000000000105',
        '0198a800-0000-7000-8000-000000000106',
        ['personal_prayer_id' => $prayerId],
    ))->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'invalid_prayer');

    $this->actingAs($owner)->postJson('/api/sync/mutations', $operation(
        $owner,
        '0198a800-0000-7000-8000-000000000107',
        '0198a800-0000-7000-8000-000000000108',
        ['prayer_id' => '0198a100-0000-7000-8000-000000000001', 'personal_prayer_id' => $prayerId],
    ))->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'invalid_data');

    expect(TodayPrayer::count())->toBe(1)
        ->and(TodayPrayer::first()->personal_prayer_id)->toBe($prayerId)
        ->and(TodayPrayer::first()->prayer_id)->toBeNull()
        ->and(TodayPrayer::first()->action_completed)->toBeTrue();
});

it('moves a saved prayer to a newly paired immutable revision', function () {
    $user = User::factory()->create();
    $prayerId = '0198a800-0000-7000-8000-000000000111';
    $firstRevisionId = '0198a800-0000-7000-8000-000000000112';
    $secondRevisionId = '0198a800-0000-7000-8000-000000000113';
    PersonalPrayer::create([
        'id' => $prayerId,
        'user_id' => $user->id,
        'title' => 'A prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    PersonalPrayerRevision::create([
        'id' => $firstRevisionId,
        'prayer_id' => $prayerId,
        'user_id' => $user->id,
        'body' => 'Father, guide me. Amen.',
        'action' => null,
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);
    PersonalPrayer::whereKey($prayerId)->update(['current_revision_id' => $firstRevisionId]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000114',
                'personal_prayers',
                $prayerId,
                ['current_revision_id' => $secondRevisionId],
                'patch',
            ),
            personalPrayerOperation(
                '0198a800-0000-7000-8000-000000000115',
                'personal_prayer_revisions',
                $secondRevisionId,
                [
                    'prayer_id' => $prayerId,
                    'body' => 'Father, guide me and teach me to listen. Amen.',
                    'action' => 'Listen before speaking.',
                    'device_id' => 'device-1',
                ],
            ),
        ],
    ])->assertOk()->assertJsonPath('accepted', 2);

    expect(PersonalPrayer::findOrFail($prayerId)->current_revision_id)->toBe($secondRevisionId)
        ->and(PersonalPrayerRevision::count())->toBe(2);
});
