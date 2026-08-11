<?php

use App\Domain\Sync\ApplySyncMutation;
use App\Models\LibraryPrayer;
use App\Models\PrayerVote;
use App\Models\SyncOperation;
use App\Models\TodayPrayer;
use App\Models\User;
use Database\Seeders\PrayerLibrarySeeder;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
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

it('records user-before-prayer acquisition order for vote PUTs in SQLite', function () {
    // SQLite proves the application acquisition contract; real FOR UPDATE behavior is a Postgres deployment test.
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $queries = [];

    DB::listen(function ($query) use (&$queries): void {
        $queries[] = strtolower($query->sql);
    });

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000094',
            'prayer_votes',
            'put',
            '0198a200-0000-7000-8000-000000000095',
            ['prayer_id' => $prayerId],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    $userLockIndex = collect($queries)->search(
        fn (string $sql): bool => str_starts_with($sql, 'select *') && str_contains($sql, 'from "users"'),
    );
    $prayerLockIndex = collect($queries)->search(
        fn (string $sql): bool => str_starts_with($sql, 'select *') && str_contains($sql, 'from "library_prayers"'),
    );

    expect($userLockIndex)->not->toBeFalse()
        ->and($prayerLockIndex)->not->toBeFalse()
        ->and($userLockIndex)->toBeLessThan($prayerLockIndex);
});

it('uses the same sorted prayer acquisition order for A-B and B-A batches in SQLite', function () {
    // SQLite proves the application acquisition contract; real FOR UPDATE behavior is a Postgres deployment test.
    $first = User::factory()->create();
    $second = User::factory()->create();
    $prayerA = seededPrayerId();
    $prayerB = seededPrayerId(2);
    $queries = [];

    DB::listen(function ($query) use (&$queries): void {
        $queries[] = [
            'sql' => strtolower($query->sql),
            'bindings' => $query->bindings,
        ];
    });

    $batch = function (bool $reverse) use ($prayerA, $prayerB): array {
        $operations = [
            syncPrayerOperation(
                $reverse
                    ? '0198a600-0000-7000-8000-000000000003'
                    : '0198a600-0000-7000-8000-000000000001',
                'prayer_votes',
                'put',
                $reverse
                    ? '0198a600-0000-7000-8000-000000000004'
                    : '0198a600-0000-7000-8000-000000000002',
                ['prayer_id' => $prayerB],
            ),
            syncPrayerOperation(
                $reverse
                    ? '0198a600-0000-7000-8000-000000000007'
                    : '0198a600-0000-7000-8000-000000000005',
                'today_prayers',
                'put',
                $reverse
                    ? '0198a600-0000-7000-8000-000000000008'
                    : '0198a600-0000-7000-8000-000000000006',
                [
                    'local_date' => '2026-08-11',
                    'prayer_id' => $prayerA,
                    'include_action' => false,
                    'action_completed' => false,
                ],
            ),
        ];

        return ['operations' => $reverse ? array_reverse($operations) : $operations];
    };
    $lockedPrayerBindings = fn (array $captured): ?array => collect($captured)
        ->first(fn (array $query): bool => str_contains($query['sql'], 'from "library_prayers"')
            && str_contains($query['sql'], 'order by')
            && count($query['bindings']) === 2)['bindings'] ?? null;

    $this->actingAs($first)->postJson('/api/sync/mutations', $batch(false))
        ->assertOk()->assertJsonPath('accepted', 2);
    $firstOrder = $lockedPrayerBindings($queries);

    $queries = [];
    $this->actingAs($second)->postJson('/api/sync/mutations', $batch(true))
        ->assertOk()->assertJsonPath('accepted', 2);
    $secondOrder = $lockedPrayerBindings($queries);

    expect($firstOrder)->toBe([$prayerA, $prayerB])
        ->and($secondOrder)->toBe([$prayerA, $prayerB]);
});

it('creates user-scoped alias and prayer lookup indexes', function () {
    expect(Schema::hasTable('prayer_record_aliases'))->toBeTrue()
        ->and(Schema::hasIndex('prayer_votes', ['prayer_id']))->toBeTrue()
        ->and(Schema::hasIndex('today_prayers', ['prayer_id']))->toBeTrue()
        ->and(Schema::hasIndex(
            'prayer_record_aliases',
            ['user_id', 'record_type', 'alias_id'],
            'unique',
        ))->toBeTrue()
        ->and(Schema::hasIndex(
            'prayer_record_aliases',
            ['user_id', 'record_type', 'canonical_id'],
        ))->toBeTrue();
});

it('accepts offline installation ids while assigning ownership from authentication', function () {
    $user = User::factory()->create();
    $localOwnerId = 'pre-auth-installation-owner';
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

it('keeps first canonical rows addressable through second-installation aliases', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $canonicalVoteId = '0198a300-0000-7000-8000-000000000011';
    $canonicalTodayId = '0198a300-0000-7000-8000-000000000031';

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
        ->and(PrayerVote::first()->id)->toBe($canonicalVoteId)
        ->and(TodayPrayer::first()->id)->toBe($canonicalTodayId)
        ->and(TodayPrayer::first()->prayer_id)->toBe(seededPrayerId(2))
        ->and(TodayPrayer::first()->include_action)->toBeFalse();

    $secondVoteId = '0198a300-0000-7000-8000-000000000012';
    $secondTodayId = '0198a300-0000-7000-8000-000000000032';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a300-0000-7000-8000-000000000041',
            'today_prayers',
            'patch',
            $secondTodayId,
            ['action_completed' => true],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(TodayPrayer::first()->id)->toBe($canonicalTodayId)
        ->and(TodayPrayer::first()->action_completed)->toBeTrue();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            syncPrayerOperation(
                '0198a300-0000-7000-8000-000000000042',
                'prayer_votes',
                'delete',
                $secondVoteId,
            ),
            syncPrayerOperation(
                '0198a300-0000-7000-8000-000000000043',
                'today_prayers',
                'delete',
                $secondTodayId,
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(PrayerVote::count())->toBe(0)
        ->and(TodayPrayer::count())->toBe(0)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(0);
});

it('repairs a stale alias when a later semantic PUT finds a replacement canonical row', function () {
    $user = User::factory()->create();
    $date = '2026-08-11';
    $firstId = '0198a700-0000-7000-8000-000000000001';
    $aliasId = '0198a700-0000-7000-8000-000000000002';
    $replacementId = '0198a700-0000-7000-8000-000000000003';
    $put = fn (string $operationId, string $id): array => syncPrayerOperation(
        $operationId,
        'today_prayers',
        'put',
        $id,
        [
            'local_date' => $date,
            'prayer_id' => seededPrayerId(),
            'include_action' => true,
            'action_completed' => false,
        ],
    );

    foreach ([
        $put('0198a700-0000-7000-8000-000000000011', $firstId),
        $put('0198a700-0000-7000-8000-000000000012', $aliasId),
    ] as $operation) {
        $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
            ->assertOk()->assertJsonPath('accepted', 1);
    }

    DB::table('today_prayers')->where('id', $firstId)->delete();
    foreach ([
        $put('0198a700-0000-7000-8000-000000000013', $replacementId),
        $put('0198a700-0000-7000-8000-000000000014', $aliasId),
    ] as $operation) {
        $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
            ->assertOk()->assertJsonPath('accepted', 1);
    }

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a700-0000-7000-8000-000000000015',
            'today_prayers',
            'patch',
            $aliasId,
            ['action_completed' => true],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    expect(TodayPrayer::findOrFail($replacementId)->action_completed)->toBeTrue();
});

it('deletes votes idempotently without revealing another users row', function () {
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
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0);

    expect(PrayerVote::count())->toBe(2)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(2);

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

it('uses uniform semantics for foreign and missing private Today ids', function () {
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

    $foreignPatch = $this->actingAs($attacker)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000031',
            'today_prayers',
            'patch',
            $id,
            ['action_completed' => true],
        )],
    ]);
    $foreignPatch->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'inaccessible_record');

    $missingPatch = $this->actingAs($attacker)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a200-0000-7000-8000-000000000032',
            'today_prayers',
            'patch',
            todayId($attacker, '2026-08-12'),
            ['action_completed' => true],
        )],
    ]);
    $missingPatch->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'inaccessible_record');

    expect($foreignPatch->json())->toBe([
        'accepted' => 0,
        'rejected' => 1,
        'duplicates' => 0,
        'code' => 'inaccessible_record',
    ])->and($missingPatch->json())->toBe($foreignPatch->json());

    foreach ([$id, todayId($attacker, '2026-08-13')] as $index => $deleteId) {
        $this->actingAs($attacker)->postJson('/api/sync/mutations', [
            'operations' => [syncPrayerOperation(
                sprintf('0198a200-0000-7000-8000-%012d', 33 + $index),
                'today_prayers',
                'delete',
                $deleteId,
            )],
        ])->assertOk()
            ->assertJsonPath('accepted', 1)
            ->assertJsonPath('rejected', 0);
    }

    expect(TodayPrayer::findOrFail($id)->action_completed)->toBeFalse();
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

it('allows private rows to be deleted after their canonical prayer is archived', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $voteId = '0198a400-0000-7000-8000-000000000001';
    $todayId = '0198a400-0000-7000-8000-000000000002';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            syncPrayerOperation(
                '0198a400-0000-7000-8000-000000000003',
                'prayer_votes',
                'put',
                $voteId,
                ['prayer_id' => $prayerId],
            ),
            syncPrayerOperation(
                '0198a400-0000-7000-8000-000000000004',
                'today_prayers',
                'put',
                $todayId,
                [
                    'local_date' => '2026-08-11',
                    'prayer_id' => $prayerId,
                    'include_action' => true,
                    'action_completed' => false,
                ],
            ),
        ],
    ])->assertOk()->assertJsonPath('accepted', 2);

    LibraryPrayer::whereKey($prayerId)->update(['archived_at' => now()]);

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [
            syncPrayerOperation(
                '0198a400-0000-7000-8000-000000000005',
                'prayer_votes',
                'delete',
                $voteId,
            ),
            syncPrayerOperation(
                '0198a400-0000-7000-8000-000000000006',
                'today_prayers',
                'delete',
                $todayId,
            ),
        ],
    ])->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);

    expect(PrayerVote::count())->toBe(0)
        ->and(TodayPrayer::count())->toBe(0)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(0);
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

it('resolves a concurrent operation insert race through the HTTP handler', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $operation = syncPrayerOperation(
        '0198a200-0000-7000-8000-000000000080',
        'prayer_votes',
        'put',
        '0198a200-0000-7000-8000-000000000081',
        ['prayer_id' => $prayerId],
    );

    $service = new class extends ApplySyncMutation
    {
        public bool $resolverCalled = false;

        public bool $storeCalled = false;

        protected function storeSyncOperation(User $user, array $operation): void
        {
            $this->storeCalled = true;
            $exception = new PDOException('duplicate operation', 23000);

            throw new QueryException('sqlite', 'insert into sync_operations', [], $exception);
        }

        protected function concurrentReplayResult(
            User $user,
            Collection $pending,
            int $duplicates,
            int $total,
        ): ?array {
            $this->resolverCalled = true;

            return [
                'accepted' => $total,
                'rejected' => 0,
                'duplicates' => $duplicates + $pending->count(),
            ];
        }
    };
    $this->app->instance(ApplySyncMutation::class, $service);

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->assertOk()
        ->assertJsonPath('accepted', 1)
        ->assertJsonPath('rejected', 0)
        ->assertJsonPath('duplicates', 1);

    expect($service->storeCalled)->toBeTrue()
        ->and($service->resolverCalled)->toBeTrue()
        ->and(PrayerVote::count())->toBe(0)
        ->and(SyncOperation::count())->toBe(0);
});

it('repairs helpful counts when a user is deleted through a bulk query', function () {
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

    User::query()->whereKey($first->id)->delete();

    expect(User::whereKey($first->id)->exists())->toBeFalse()
        ->and(PrayerVote::count())->toBe(1)
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(1)
        ->and(PrayerVote::first()->user_id)->toBe($second->id);
});

it('repairs helpful counts when a vote is deleted directly', function () {
    $user = User::factory()->create();
    $prayerId = seededPrayerId();
    $voteId = '0198a500-0000-7000-8000-000000000001';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a500-0000-7000-8000-000000000002',
            'prayer_votes',
            'put',
            $voteId,
            ['prayer_id' => $prayerId],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    DB::table('prayer_votes')->where('id', $voteId)->delete();

    expect(PrayerVote::whereKey($voteId)->exists())->toBeFalse()
        ->and(LibraryPrayer::findOrFail($prayerId)->helpful_count)->toBe(0);
});

it('moves helpful counts when a vote prayer is updated directly', function () {
    $user = User::factory()->create();
    $firstPrayerId = seededPrayerId();
    $secondPrayerId = seededPrayerId(2);
    $voteId = '0198a500-0000-7000-8000-000000000003';

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [syncPrayerOperation(
            '0198a500-0000-7000-8000-000000000004',
            'prayer_votes',
            'put',
            $voteId,
            ['prayer_id' => $firstPrayerId],
        )],
    ])->assertOk()->assertJsonPath('accepted', 1);

    DB::table('prayer_votes')->where('id', $voteId)->update([
        'prayer_id' => $secondPrayerId,
    ]);

    expect(LibraryPrayer::findOrFail($firstPrayerId)->helpful_count)->toBe(0)
        ->and(LibraryPrayer::findOrFail($secondPrayerId)->helpful_count)->toBe(1);
});
