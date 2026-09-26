<?php

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

require_once __DIR__.'/../../Fixtures/commitment_batches.php';

it('accepts the exported Flutter finalizer transaction and replays it unchanged', function () {
    // Captured from the real PowerSync CRUD queue using test-owned content.
    $batch = json_decode(file_get_contents(__DIR__.'/../../Fixtures/commitment_actual_wire.json'), true, flags: JSON_THROW_ON_ERROR);
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $batch])->assertOk()->assertJsonPath('accepted', count($batch))->assertJsonPath('rejected', 0);
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('duplicates', count($batch));
    expect(DB::table('commitment_practices')->count())->toBe(5);
    expect(DB::table('commitments')->value('owner_id'))->toBe($user->public_id);

    $batch[0]['data']['archived_at'] = null;
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('code', 'operation_conflict');
});

it('accepts actual PowerSync put shapes that omit null fields and replays their original identity', function () {
    $batch = array_map(function (array $operation): array {
        $operation['data'] = array_filter($operation['data'], fn ($value) => $value !== null);

        return $operation;
    }, commitmentBatch());
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('accepted', 8)->assertJsonPath('rejected', 0);
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('duplicates', 8);
    expect(DB::table('commitment_practices')->value('suggestion_id'))->toBeNull();
    expect(DB::table('commitment_meditation_plans')->value('weekdays_mask'))->toBeNull();
});

it('preserves reviewed private text exactly and supports Unicode code point limits', function () {
    $batch = commitmentBatch();
    $batch[2]['data']['name'] = str_repeat('🙂', 120);
    $batch[1]['data']['title'] = $batch[2]['data']['name'];
    $batch[3]['data']['body'] = "  A reviewed declaration.\n  ";
    $batch[6]['data']['body'] = $batch[7]['data']['body'] = "  A reviewed practice.\n  ";
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
    expect(DB::table('commitment_declarations')->value('body'))->toBe($batch[3]['data']['body']);
    expect(DB::table('goal_actions')->value('body'))->toBe($batch[7]['data']['body']);
});

it('rejects a mismatched linked Goal title in a new mixed batch', function () {
    $batch = commitmentBatch();
    $batch[1]['data']['title'] = 'A different private title';
    $response = $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => array_reverse($batch)]);
    $response->assertJsonPath('accepted', 0)->assertJsonPath('code', 'invalid_commitment_goal');
    expect($response->getContent())->not->toContain('private title');
    expect(DB::table('goals')->count())->toBe(0);
    expect(DB::table('goal_revisions')->count())->toBe(0);
});

it('validates the effective linked Goal revision before accepting revision mutations', function () {
    $batch = commitmentBatch();
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
    $revision = commitmentOperation('goal_revisions', ['goal_id' => $batch[0]['id'], 'title' => 'Another title', 'current_situation' => 'Updated situation', 'why_it_matters' => null, 'device_id' => 'device']);
    $goalPatch = commitmentOperation('goals', ['current_revision_id' => $revision['id']], $batch[0]['id'], 'patch');
    $this->postJson('/api/sync/mutations', ['operations' => [$goalPatch, $revision]])->assertJsonPath('code', 'invalid_commitment_goal')->assertJsonPath('accepted', 0);
    expect(DB::table('goals')->value('current_revision_id'))->toBe($batch[1]['id']);
    expect(DB::table('goal_revisions')->count())->toBe(1);

    $revision['data']['title'] = $batch[2]['data']['name'];
    $this->postJson('/api/sync/mutations', ['operations' => [$goalPatch, $revision]])->assertJsonPath('rejected', 0)->assertJsonPath('accepted', 2);
    expect(DB::table('goals')->value('current_revision_id'))->toBe($revision['id']);
    expect(DB::table('goal_revisions')->count())->toBe(2);
});

it('preserves operation identity and rejects wrong goal references atomically', function () {
    $this->actingAs(User::factory()->create());
    $batch = commitmentBatch();
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
    $batch[2]['data']['name'] = 'Changed';
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('code', 'operation_conflict');
    $patch = commitmentOperation('commitment_practices', ['body' => 'Changed'], end($batch)['id'], 'patch');
    $this->postJson('/api/sync/mutations', ['operations' => [$patch]])->assertJsonPath('code', 'invalid_data');
    $actionPatch = commitmentOperation('goal_actions', ['body' => 'Changed'], $batch[6]['id'], 'patch');
    $this->postJson('/api/sync/mutations', ['operations' => [$patch, $actionPatch]])->assertJsonPath('rejected', 0);
});

it('atomically saves all commitment records with authenticated ownership and exact replay', function () {
    $user = User::factory()->create();
    $batch = commitmentBatch(12);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => array_reverse($batch)])->assertOk()->assertJsonPath('accepted', 30)->assertJsonPath('rejected', 0);
    $this->postJson('/api/sync/mutations', ['operations' => array_reverse($batch)])->assertJsonPath('duplicates', 30);
    expect(DB::table('commitments')->value('user_id'))->toBe($user->id);
    expect(DB::table('commitments')->value('owner_id'))->toBe($user->public_id);
    $user->delete();
    foreach (['commitments', 'commitment_practices', 'commitment_declarations', 'commitment_meditation_plans', 'commitment_preparation_cycles'] as $table) {
        expect(DB::table($table)->count())->toBe(0);
    }
});

it('rejects second primary atomically without leaking private text', function () {
    $this->actingAs(User::factory()->create());
    $this->postJson('/api/sync/mutations', ['operations' => commitmentBatch()])->assertJsonPath('rejected', 0);
    $response = $this->postJson('/api/sync/mutations', ['operations' => commitmentBatch()]);
    $response->assertJsonPath('code', 'primary_commitment_exists')->assertJsonPath('accepted', 0);
    expect($response->getContent())->not->toContain('Private');
    expect(DB::table('goals')->count())->toBe(1);
});

it('rejects invalid commitment data before writing any records', function (string $table, string $field, mixed $value) {
    $batch = commitmentBatch();
    foreach ($batch as &$operation) {
        if ($operation['table'] === $table) {
            $operation['data'][$field] = $value;
        }
    }
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('code', 'invalid_data')->assertJsonPath('accepted', 0);
    expect(DB::table('goals')->count())->toBe(0);
})->with([
    ['commitments', 'name', str_repeat('🙂', 121)],
    ['commitments', 'calling', '   '],
    ['commitments', 'private_notes', 'Private secret'],
    ['commitment_practices', 'category', 'invalid'],
    ['commitment_practices', 'source', 'invalid'],
    ['commitment_practices', 'suggestion_id', 'not-user-authored'],
    ['commitment_declarations', 'body', str_repeat('x', 4001)],
    ['commitment_meditation_plans', 'duration_minutes', 7],
    ['commitment_meditation_plans', 'frequency', 'weekly'],
    ['commitment_meditation_plans', 'timezone', 'invented/timezone'],
    ['commitment_meditation_plans', 'weekdays_mask', 1],
    ['commitment_preparation_cycles', 'review_local_date', '2026-10-04'],
    ['commitment_preparation_cycles', 'state', 'ready'],
]);

it('rejects zero practices and cross owner changes', function () {
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => commitmentBatch(0)])->assertJsonPath('code', 'invalid_data');
    $batch = commitmentBatch();
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => [commitmentOperation('commitments', ['guide_id' => 'peace'], $batch[2]['id'], 'patch')]])->assertJsonPath('code', 'inaccessible_record');
});

it('records append only sessions and permits reviewed declaration edits', function () {
    $this->actingAs(User::factory()->create());
    $batch = commitmentBatch();
    $this->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
    $session = commitmentOperation('commitment_meditation_sessions', ['commitment_id' => $batch[2]['id'], 'session_kind' => 'listening', 'started_at' => '2026-09-24T09:00:00Z', 'ended_at' => '2026-09-24T09:05:00Z', 'local_date' => '2026-09-24', 'planned_duration_seconds' => 600, 'actual_duration_seconds' => 300, 'outcome' => 'ended_early', 'device_id' => 'device']);
    $this->postJson('/api/sync/mutations', ['operations' => [$session]])->assertJsonPath('rejected', 0);
    $this->postJson('/api/sync/mutations', ['operations' => [commitmentOperation($session['table'], ['outcome' => 'completed'], $session['id'], 'patch')]])->assertJsonPath('code', 'immutable_session');
    $this->postJson('/api/sync/mutations', ['operations' => [commitmentOperation('commitment_declarations', ['body' => 'Revised declaration', 'reviewed_at' => '2026-09-24T09:10:00Z'], $batch[3]['id'], 'patch')]])->assertJsonPath('rejected', 0);
});
