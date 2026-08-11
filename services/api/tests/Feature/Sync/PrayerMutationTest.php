<?php

use App\Domain\Sync\ApplySyncMutation;
use App\Models\LibraryPrayer;
use App\Models\PrayerVote;
use App\Models\SyncOperation;
use App\Models\TodayPrayer;
use App\Models\User;
use Database\Seeders\PrayerLibrarySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Ramsey\Uuid\Uuid;

uses(RefreshDatabase::class);

function seededPrayerId(int $number = 1): string
{
    return sprintf('0198a100-0000-7000-8000-%012d', $number);
}

function voteId(User $user, string $prayerId): string
{
    return Uuid::uuid5(Uuid::NAMESPACE_URL, "{$user->public_id}:{$prayerId}")->toString();
}

function todayId(User $user, string $localDate): string
{
    return Uuid::uuid5(Uuid::NAMESPACE_URL, "{$user->public_id}:{$localDate}")->toString();
}

function syncPrayerOperation(
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

beforeEach(function () {
    $this->seed(PrayerLibrarySeeder::class);
});

it('seeds the exact canonical editorial library from the Flutter asset', function () {
    $asset = json_decode(
        file_get_contents(base_path('../../apps/soulbuddy/assets/content/prayer_library.json')),
        true,
        flags: JSON_THROW_ON_ERROR,
    );
    $expected = collect($asset['prayers'])
        ->map(fn (array $prayer) => $prayer + ['helpful_count' => 0])
        ->sortBy('id')
        ->values()
        ->all();
    $actual = LibraryPrayer::query()
        ->orderBy('id')
        ->get(['id', 'title', 'body', 'grounding', 'purpose', 'action', 'helpful_count'])
        ->map(fn (LibraryPrayer $prayer) => $prayer->attributesToArray())
        ->all();

    expect($actual)->toBe($expected)
        ->and(LibraryPrayer::query()->whereNull('published_at')->count())->toBe(0)
        ->and(LibraryPrayer::query()->whereNotNull('archived_at')->count())->toBe(0);

    LibraryPrayer::whereKey(seededPrayerId())->update(['helpful_count' => 7]);
    $this->seed(PrayerLibrarySeeder::class);

    expect(LibraryPrayer::findOrFail(seededPrayerId())->helpful_count)->toBe(7);
});

it('rejects client writes to the canonical library without echoing prayer text', function () {
    $user = User::factory()->create();
    $privateText = 'private prayer words must not leave the device';
    Log::spy();

    $response = $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000001',
            'library_prayers',
            'patch',
            seededPrayerId(),
            ['body' => $privateText, 'helpful_count' => 999],
        )],
    ]);

    $response->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1);
    expect($response->getContent())->not->toContain($privateText)
        ->and(LibraryPrayer::findOrFail(seededPrayerId())->helpful_count)->toBe(0);
    foreach (['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }
});

it('creates one deterministic vote, treats retries as duplicates, and derives the count', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $voteId = voteId($user, $prayerId);
    $operation = syncPrayerOperation(
        '0198a200-0000-7000-8000-000000000002',
        'prayer_votes',
        'put',
        $voteId,
        [
            'owner_id' => $user->public_id,
            'prayer_id' => $prayerId,
            'created_at' => '2026-08-11T08:00:00.000Z',
        ],
    );

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('duplicates', 1);

    $sameVoteNewOperation = $operation;
    $sameVoteNewOperation['operation_id'] = '0198a200-0000-7000-8000-000000000003';
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$sameVoteNewOperation]])
        ->assertOk()
        ->assertJsonPath('accepted', 1);

    expect(PrayerVote::count())->toBe(1)
        ->and(PrayerVote::first()->user_id)->toBe($user->id)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(1);
});

it('accepts offline installation ids while assigning ownership from authentication', function () {
    $user = User::factory()->create();
    $localOwnerId = '0198a200-0000-7000-8000-000000000090';
    $prayerId = seededPrayerId();
    $voteId = '0198a200-0000-7000-8000-000000000091';
    $todayId = '0198a200-0000-7000-8000-000000000092';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            syncPrayerOperation(
                '0198a200-0000-7000-8000-000000000004',
                'prayer_votes',
                'put',
                $voteId,
                ['owner_id' => $localOwnerId, 'prayer_id' => $prayerId],
            ),
            syncPrayerOperation(
                '0198a200-0000-7000-8000-000000000005',
                'today_prayers',
                'put',
                $todayId,
                [
                    'owner_id' => $localOwnerId,
                    'local_date' => '2026-08-11',
                    'prayer_id' => $prayerId,
                    'include_action' => true,
                    'action_completed' => false,
                ],
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(PrayerVote::findOrFail($voteId)->user_id)->toBe($user->id)
        ->and(TodayPrayer::findOrFail($todayId)->user_id)->toBe($user->id);
});

it('accepts second-installation PUTs by authenticated unique keys', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();

    foreach ([1, 2] as $installation) {
        $this->actingAs($user)->postJson('/api/sync/mutations', [
            'operations' => [
                syncPrayerOperation(
                    sprintf('0198a300-0000-7000-8000-%012d', $installation),
                    'prayer_votes',
                    'put',
                    sprintf('0198a300-0000-7000-8000-%012d', 10 + $installation),
                    ['prayer_id' => $prayerId],
                ),
                syncPrayerOperation(
                    sprintf('0198a300-0000-7000-8000-%012d', 20 + $installation),
                    'today_prayers',
                    'put',
                    sprintf('0198a300-0000-7000-8000-%012d', 30 + $installation),
                    [
                        'local_date' => '2026-08-11',
                        'prayer_id' => seededPrayerId($installation),
                        'include_action' => $installation === 1,
                        'action_completed' => false,
                    ],
                ),
            ],
        ])->assertOk()
            ->assertJsonPath('accepted', 2)
            ->assertJsonPath('rejected', 0);
    }

    expect(PrayerVote::count())->toBe(1)
        ->and(TodayPrayer::count())->toBe(1)
        ->and(TodayPrayer::first()->prayer_id)->toBe(seededPrayerId(2))
        ->and(TodayPrayer::first()->include_action)->toBeFalse();
});

it('deletes votes idempotently, forbids deleting another users row, and recomputes counts', function () {
    $first = User::factory()->create();
    $second = User::factory()->create();
    $prayerId = seededPrayerId();

    foreach ([$first, $second] as $index => $user) {
        $this->actingAs($user)->postJson('/api/sync/mutations', [
            'operations' => [syncPrayerOperation(
                sprintf('0198a200-0000-7000-8000-%012d', 10 + $index),
                'prayer_votes',
                'put',
                voteId($user, $prayerId),
                ['prayer_id' => $prayerId],
            )],
        ])->assertOk()->assertJsonPath('accepted', 1);
    }

    expect(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(2);

    $this->actingAs($second)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000012',
            'prayer_votes',
            'delete',
            voteId($first, $prayerId),
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'inaccessible_record');

    $this->actingAs($first)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000013',
            'prayer_votes',
            'delete',
            voteId($first, $prayerId),
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(PrayerVote::count())->toBe(1)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(1);

    $this->actingAs($first)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000014',
            'prayer_votes',
            'delete',
            voteId($first, $prayerId),
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(1);
});

it('puts patches and deletes a deterministic Today selection', function () {
    $user = User::factory()->create();
    $date = '2026-08-11';
    $id = todayId($user, $date);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000020',
            'today_prayers',
            'put',
            $id,
            [
                'owner_id' => $user->public_id,
                'local_date' => $date,
                'prayer_id' => seededPrayerId(),
                'include_action' => true,
                'action_completed' => false,
                'created_at' => '2026-08-11T08:00:00.000Z',
            ],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000021',
            'today_prayers',
            'patch',
            $id,
            ['prayer_id' => seededPrayerId(2), 'include_action' => false, 'action_completed' => true],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(TodayPrayer::first())
        ->user_id->toBe($user->id)
        ->local_date->format('Y-m-d')->toBe($date)
        ->prayer_id->toBe(seededPrayerId(2))
        ->include_action->toBeFalse()
        ->action_completed->toBeTrue();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000024',
            'today_prayers',
            'put',
            $id,
            [
                'local_date' => $date,
                'prayer_id' => seededPrayerId(),
                'include_action' => true,
                'action_completed' => false,
            ],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(TodayPrayer::count())->toBe(1)
        ->and(TodayPrayer::first()->id)->toBe($id)
        ->and(TodayPrayer::first()->prayer_id)->toBe(seededPrayerId());

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000022',
            'today_prayers',
            'delete',
            $id,
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000023',
            'today_prayers',
            'delete',
            $id,
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(TodayPrayer::count())->toBe(0);
});

it('uses one code for inaccessible and missing private Today patches', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $date = '2026-08-11';
    $id = todayId($owner, $date);

    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000030',
            'today_prayers',
            'put',
            $id,
            [
                'local_date' => $date,
                'prayer_id' => seededPrayerId(),
                'include_action' => true,
                'action_completed' => false,
            ],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $this->actingAs($attacker)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000031',
            'today_prayers',
            'patch',
            $id,
            ['action_completed' => true],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'inaccessible_record');

    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000032',
            'today_prayers',
            'patch',
            todayId($owner, '2026-08-12'),
            ['action_completed' => true],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'inaccessible_record');
});

it('requires published non-archived prayer references', function () {
    $user = User::factory()->create();
    LibraryPrayer::whereKey(seededPrayerId())->update(['published_at' => null]);
    LibraryPrayer::whereKey(seededPrayerId(2))->update(['archived_at' => now()]);

    foreach ([seededPrayerId(), seededPrayerId(2), seededPrayerId(99)] as $index => $prayerId) {
        $this->actingAs($user)->postJson('/api/sync/mutations', [
            'operations' => [syncPrayerOperation(
                sprintf('0198a200-0000-7000-8000-%012d', 40 + $index),
                'prayer_votes',
                'put',
                voteId($user, $prayerId),
                ['prayer_id' => $prayerId],
            )],
        ])->assertOk()
            ->assertJsonPath('accepted', 0)
            ->assertJsonPath('rejected', 1)
            ->assertJsonPath('code', 'invalid_prayer');
    }

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000043',
            'today_prayers',
            'put',
            todayId($user, '2026-08-11'),
            [
                'local_date' => '2026-08-11',
                'prayer_id' => seededPrayerId(2),
                'include_action' => false,
                'action_completed' => false,
            ],
        )],
    ])->assertOk()->assertJsonPath('code', 'invalid_prayer');
});

it('rejects a mixed invalid domain batch and accepts a later valid batch', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            syncPrayerOperation(
                '0198a200-0000-7000-8000-000000000050',
                'prayer_votes',
                'patch',
                voteId($user, $prayerId),
                ['helpful_count' => 50],
            ),
            syncPrayerOperation(
                '0198a200-0000-7000-8000-000000000052',
                'prayer_votes',
                'put',
                voteId($user, $prayerId),
                ['prayer_id' => $prayerId],
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 2)
        ->assertJsonPath('code', 'unsupported_operation');

    expect(PrayerVote::count())->toBe(0);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000051',
            'prayer_votes',
            'put',
            voteId($user, $prayerId),
            ['prayer_id' => $prayerId],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);

    expect(PrayerVote::count())->toBe(1);
});

it('validates prayer mutation data by table and operation type', function (string $table, string $type, array $data) {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $id = $table === 'prayer_votes'
        ? voteId($user, $prayerId)
        : todayId($user, '2026-08-11');

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000070',
            $table,
            $type,
            $id,
            $data,
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'invalid_data');
})->with([
    'vote cannot submit helpful count' => [
        'prayer_votes',
        'put',
        ['prayer_id' => seededPrayerId(), 'helpful_count' => 40],
    ],
    'Today PUT requires all fields' => [
        'today_prayers',
        'put',
        ['local_date' => '2026-08-11', 'prayer_id' => seededPrayerId(), 'include_action' => true],
    ],
    'Today PATCH only accepts mutable fields' => [
        'today_prayers',
        'patch',
        ['local_date' => '2026-08-11'],
    ],
]);

it('rejects legacy operation ids without fingerprint metadata for prayer tables', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $voteId = voteId($user, $prayerId);

    SyncOperation::create([
        'operation_id' => '0198a200-0000-7000-8000-000000000060',
        'user_id' => $user->id,
        'table_name' => 'prayer_votes',
        'record_id' => $voteId,
        'created_at' => now(),
    ]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000060',
            'prayer_votes',
            'put',
            $voteId,
            ['prayer_id' => $prayerId],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'operation_conflict');

    expect(PrayerVote::count())->toBe(0);
});

it('rechecks stored fingerprints after a concurrent operation insert race', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $operation = syncPrayerOperation(
        '0198a200-0000-7000-8000-000000000080',
        'prayer_votes',
        'put',
        '0198a200-0000-7000-8000-000000000081',
        ['prayer_id' => $prayerId],
    );

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()
        ->assertJsonPath('accepted', 1);

    $service = new class extends ApplySyncMutation
    {
        public function resolveReplay(User $user, Collection $pending, int $duplicates, int $total): ?array
        {
            return $this->concurrentReplayResult($user, $pending, $duplicates, $total);
        }
    };

    expect($service->resolveReplay($user, collect([$operation]), 0, 1))->toBe([
        'accepted' => 1,
        'rejected' => 0,
        'duplicates' => 1,
    ]);
});

it('recomputes cached helpful counts when a voting user is deleted', function () {
    $first = User::factory()->create();
    $second = User::factory()->create();
    $prayerId = seededPrayerId();

    foreach ([$first, $second] as $index => $user) {
        $this->actingAs($user)->postJson('/api/sync/mutations', [
            'operations' => [syncPrayerOperation(
                sprintf('0198a200-0000-7000-8000-%012d', 90 + $index),
                'prayer_votes',
                'put',
                sprintf('0198a200-0000-7000-8000-%012d', 92 + $index),
                ['prayer_id' => $prayerId],
            )],
        ])->assertOk()->assertJsonPath('accepted', 1);
    }

    expect(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(2);

    $first->delete();

    expect(PrayerVote::count())->toBe(1)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(1);
});
