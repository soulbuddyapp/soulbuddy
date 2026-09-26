<?php

use App\Models\Goal;
use App\Models\GoalAction;
use App\Models\GoalActionEvent;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

require_once __DIR__.'/../../Fixtures/commitment_batches.php';

it('preserves populated Goal actions and events through the action kind migration', function () {
    $user = User::factory()->create();
    $goal = Goal::create(['user_id' => $user->id, 'mode' => 'actionable', 'status' => 'active', 'position' => 0]);
    $action = GoalAction::create(['user_id' => $user->id, 'goal_id' => $goal->id, 'body' => 'Existing practice', 'action_kind' => 'care', 'schedule_type' => 'daily', 'enabled' => true]);
    $event = GoalActionEvent::create(['user_id' => $user->id, 'goal_id' => $goal->id, 'goal_action_id' => $action->id, 'event_type' => 'completed', 'occurrence_key' => '2026-09-24', 'occurred_at' => now(), 'local_date' => '2026-09-24', 'device_id' => 'device']);
    $migration = require database_path('migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php');
    $migration->down();
    $migration->up();
    expect($action->fresh()->body)->toBe('Existing practice');
    expect($event->fresh())->not->toBeNull();
});

it('refuses an action kind rollback while commitment practices exist', function () {
    $this->actingAs(User::factory()->create())->postJson('/api/sync/mutations', ['operations' => commitmentBatch()])->assertJsonPath('rejected', 0);
    $migration = require database_path('migrations/2026_09_24_000001_add_commitment_practice_to_goal_action_kind.php');
    expect(fn () => $migration->down())->toThrow(LogicException::class);
});

it('has six owner scoped commitment tables and indexes', function () {
    foreach (['commitments', 'commitment_practices', 'commitment_declarations', 'commitment_meditation_plans', 'commitment_preparation_cycles', 'commitment_meditation_sessions'] as $table) {
        expect(Schema::hasColumns($table, ['id', 'user_id', 'owner_id']))->toBeTrue();
    }
    expect(Schema::hasIndex('commitments', ['user_id', 'journey_slot']))->toBeTrue();
    expect(Schema::hasIndex('commitment_practices', ['commitment_id', 'position']))->toBeTrue();
});

it('enforces database shapes independently of upload validation', function (string $table, array $changes) {
    $this->actingAs(User::factory()->create());
    $this->postJson('/api/sync/mutations', ['operations' => commitmentBatch()])->assertJsonPath('rejected', 0);
    expect(fn () => DB::table($table)->update($changes))->toThrow(QueryException::class);
})->with([
    ['commitments', ['journey_slot' => 'second']],
    ['commitment_practices', ['position' => 12]],
    ['commitment_practices', ['category' => 'invalid']],
    ['commitment_practices', ['suggestion_id' => 'invalid']],
    ['commitment_declarations', ['body' => '']],
    ['commitment_declarations', ['body' => str_repeat('x', 4001)]],
    ['commitment_meditation_plans', ['duration_minutes' => 11]],
    ['commitment_meditation_plans', ['local_time' => '08:99']],
    ['commitment_meditation_plans', ['frequency' => 'selected_days', 'weekdays_mask' => null]],
    ['commitment_preparation_cycles', ['review_local_date' => '2026-09-01']],
]);
