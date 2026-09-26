<?php

use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);
require_once __DIR__.'/../../Fixtures/commitment_batches.php';

it('projects only the authenticated public owner graph with the PowerSync fragment', function () {
    $first = User::factory()->create();
    $second = User::factory()->create();
    foreach ([$first, $second] as $user) {
        $batch = commitmentBatch();
        $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $batch])->assertJsonPath('rejected', 0);
        $session = commitmentOperation('commitment_meditation_sessions', ['commitment_id' => $batch[2]['id'], 'session_kind' => 'meditation', 'started_at' => '2026-09-24T08:00:00Z', 'ended_at' => '2026-09-24T08:05:00Z', 'local_date' => '2026-09-24', 'planned_duration_seconds' => 300, 'actual_duration_seconds' => 300, 'outcome' => 'completed', 'device_id' => 'device']);
        $this->postJson('/api/sync/mutations', ['operations' => [$session]])->assertJsonPath('rejected', 0);
    }
    $fragment = file_get_contents(base_path('../../infra/powersync/commitments.sync-rules.yaml'));
    preg_match_all('/^\s+- (SELECT .+)$/m', $fragment, $queries);
    expect($queries[1])->toHaveCount(6);
    foreach ($queries[1] as $query) {
        $rows = DB::select(str_replace('bucket.owner_id', '?', $query), [$first->public_id]);
        expect($rows)->toHaveCount(1);
        expect($rows[0]->owner_id)->toBe($first->public_id);
        expect(property_exists($rows[0], 'user_id'))->toBeFalse();
    }
    expect(fn () => DB::table('commitments')->where('user_id', $first->id)->update(['owner_id' => $second->public_id]))->toThrow(QueryException::class);
});
