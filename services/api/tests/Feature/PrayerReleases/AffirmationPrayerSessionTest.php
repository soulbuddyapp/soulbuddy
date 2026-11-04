<?php

use App\Domain\PrayerReleases\PrayerReleasePublisher;
use App\Domain\PrayerReleases\ReleaseContent;
use App\Models\AffirmationPrayerSession;
use App\Models\PrayerRelease;
use App\Models\PrayerReleaseDownload;
use App\Models\PrayerReleaseItem;
use App\Models\User;
use Database\Seeders\PrayerReleaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function sessionRelease(): PrayerRelease
{
    config()->set('prayer_releases.published_at', '2026-10-05 07:00:00');
    app(PrayerReleasePublisher::class)->publish(
        ReleaseContent::fromJsonFile(resource_path('prayer-releases/'.PrayerReleaseSeeder::SLUG.'.json')),
        config('prayer_releases.published_at'),
    );

    return PrayerRelease::query()->where('slug', PrayerReleaseSeeder::SLUG)->firstOrFail();
}

function sessionUser(bool $addRelease = true): User
{
    $user = User::factory()->create();
    if ($addRelease) {
        $release = sessionRelease();
        PrayerReleaseDownload::query()->create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'release_id' => $release->id,
            'downloaded_at' => now(),
        ]);
    }

    return $user;
}

function attentionItem(): PrayerReleaseItem
{
    return sessionRelease()->items->firstWhere('practice_mode', 'affirmation_repetition');
}

/** @return array<string, mixed> */
function sessionOperation(array $overrides = []): array
{
    return array_replace([
        'operation_id' => (string) Str::uuid(),
        'table' => 'affirmation_prayer_sessions',
        'type' => 'put',
        'id' => (string) Str::uuid(),
        'data' => [
            'release_item_id' => attentionItem()->id,
            'local_date' => '2026-10-06',
            'started_at' => '2026-10-06 09:00:00',
            'ended_at' => '2026-10-06 09:12:00',
            'outcome' => 'ended_early',
            'step_one_count' => 12,
            'step_two_count' => 0,
            'sound_key' => 'oceanWaves',
            'narration_speed' => '0.85',
        ],
    ], $overrides);
}

function sendSession(User $user, array $operation): array
{
    return test()->actingAs($user, 'sanctum')
        ->postJson('/api/sync/mutations', ['operations' => [$operation]])
        ->json();
}

it('accepts a terminal early exit that records the actual counts', function () {
    $user = sessionUser();
    $operation = sessionOperation();

    $result = sendSession($user, $operation);

    expect($result['accepted'])->toBe(1)
        ->and($result['rejected'])->toBe(0)
        ->and(AffirmationPrayerSession::query()->count())->toBe(1);

    $stored = AffirmationPrayerSession::query()->firstOrFail();
    expect($stored->user_id)->toBe($user->id)
        ->and($stored->release_item_id)->toBe(attentionItem()->id)
        ->and($stored->outcome)->toBe('ended_early')
        ->and($stored->step_one_count)->toBe(12)
        ->and($stored->step_two_count)->toBe(0)
        ->and($stored->sound_key)->toBe('oceanWaves')
        ->and($stored->narration_speed)->toBe('0.85')
        ->and($stored->local_date->format('Y-m-d'))->toBe('2026-10-06');
});

it('accepts a completed session only at fifty and ten', function () {
    $user = sessionUser();
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], [
            'outcome' => 'completed',
            'step_one_count' => 50,
            'step_two_count' => 10,
        ]),
    ]);

    expect(sendSession($user, $operation)['accepted'])->toBe(1);
    expect(AffirmationPrayerSession::query()->firstOrFail()->outcome)->toBe('completed');
});

it('refuses a forged completed record with incomplete counts', function () {
    $user = sessionUser();
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], [
            'outcome' => 'completed',
            'step_one_count' => 49,
            'step_two_count' => 10,
        ]),
    ]);

    $result = sendSession($user, $operation);

    expect($result['rejected'])->toBe(1)
        ->and($result['code'])->toBe('invalid_data')
        ->and(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('refuses counts beyond either target', function () {
    $user = sessionUser();
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], ['step_one_count' => 51]),
    ]);

    expect(sendSession($user, $operation)['code'])->toBe('invalid_data')
        ->and(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('refuses a session for an item that carries no counted practice', function () {
    $user = sessionUser();
    $plain = sessionRelease()->items->firstWhere('practice_mode', null);
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], [
            'release_item_id' => $plain->id,
        ]),
    ]);

    expect(sendSession($user, $operation)['code'])->toBe('inaccessible_record')
        ->and(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('refuses a session for a collection the person never added', function () {
    $user = sessionUser(addRelease: false);
    $operation = sessionOperation();

    expect(sendSession($user, $operation)['code'])->toBe('inaccessible_record')
        ->and(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('refuses a session that belongs to another account', function () {
    $owner = sessionUser();
    $other = sessionUser();
    $operation = sessionOperation();

    sendSession($owner, $operation);

    // The same operation replayed by another account is refused, not adopted.
    $result = sendSession($other, $operation);
    expect($result['rejected'])->toBe(1)
        ->and($result['code'])->toBe('operation_conflict')
        ->and(AffirmationPrayerSession::query()->firstOrFail()->user_id)->toBe($owner->id);
});

it('never rewrites a stored terminal record', function () {
    $user = sessionUser();
    $operation = sessionOperation();
    sendSession($user, $operation);

    $rewritten = sessionOperation([
        'id' => $operation['id'],
        'data' => array_replace($operation['data'], ['step_one_count' => 30]),
    ]);

    expect(sendSession($user, $rewritten)['code'])->toBe('immutable_session')
        ->and(AffirmationPrayerSession::query()->firstOrFail()->step_one_count)->toBe(12);
});

it('accepts the same terminal record replayed by its owner', function () {
    $user = sessionUser();
    $operation = sessionOperation();
    sendSession($user, $operation);

    // The operation id is already stored, so the batch is a duplicate.
    $replay = $operation;
    $result = sendSession($user, $replay);

    expect($result['duplicates'] ?? 0)->toBe(1)
        ->and(AffirmationPrayerSession::query()->count())->toBe(1);
});

it('refuses a session that ends before it starts', function () {
    $user = sessionUser();
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], [
            'started_at' => '2026-10-06 09:12:00',
            'ended_at' => '2026-10-06 09:00:00',
        ]),
    ]);

    expect(sendSession($user, $operation)['code'])->toBe('invalid_data');
});

it('refuses an unknown spoken pace', function () {
    $user = sessionUser();
    $operation = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], ['narration_speed' => '1.4']),
    ]);

    expect(sendSession($user, $operation)['code'])->toBe('invalid_data');
});

it('accepts each of the four approved paces', function () {
    $user = sessionUser();

    foreach (['0.7', '0.85', '1', '1.15'] as $index => $speed) {
        $operation = sessionOperation([
            'data' => array_replace(sessionOperation()['data'], ['narration_speed' => $speed]),
        ]);
        expect(sendSession($user, $operation)['accepted'])->toBe(1);
    }

    expect(AffirmationPrayerSession::query()->count())->toBe(4);
});

it('refuses unknown fields and non-put operations', function () {
    $user = sessionUser();

    $withExtra = sessionOperation([
        'data' => array_replace(sessionOperation()['data'], ['score' => 3]),
    ]);
    expect(sendSession($user, $withExtra)['code'])->toBe('invalid_data');

    $delete = sessionOperation(['type' => 'delete', 'data' => []]);
    expect(sendSession($user, $delete)['code'])->toBe('unsupported_operation');
});

it('refuses a session when the stored practice profile no longer rebuilds', function () {
    $user = sessionUser();
    $operation = sessionOperation();

    // The profile is altered after the collection was added, so it no longer
    // rebuilds its own source lines.
    $item = sessionRelease()->items->findOrFail($operation['data']['release_item_id']);
    $item->forceFill([
        'practice_steps' => [
            ['phrase' => 'A planted phrase', 'target_count' => 50, 'source_line' => 'Dear Lord (x50)'],
            ['phrase' => 'Another', 'target_count' => 10, 'source_line' => 'Another (x10)'],
        ],
    ])->save();

    expect(sendSession($user, $operation)['code'])->toBe('invalid_data')
        ->and(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('removes sessions when the account is deleted', function () {
    $user = sessionUser();
    sendSession($user, sessionOperation());

    $user->delete();

    expect(AffirmationPrayerSession::query()->count())->toBe(0);
});

it('keeps sessions when the release is archived', function () {
    $user = sessionUser();
    sendSession($user, sessionOperation());

    sessionRelease()->forceFill(['archived_at' => now()])->save();

    expect(AffirmationPrayerSession::query()->count())->toBe(1);
});
