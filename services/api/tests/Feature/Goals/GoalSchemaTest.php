<?php

use App\Models\Goal;
use App\Models\GoalAction;
use App\Models\GoalActionEvent;
use App\Models\GoalLink;
use App\Models\GoalRevision;
use App\Models\PersonalPrayer;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

it('creates the Goal persistence tables and lookup indexes', function () {
    expect(Schema::hasTable('goals'))->toBeTrue()
        ->and(Schema::hasTable('goal_revisions'))->toBeTrue()
        ->and(Schema::hasTable('goal_links'))->toBeTrue()
        ->and(Schema::hasTable('goal_actions'))->toBeTrue()
        ->and(Schema::hasTable('goal_action_events'))->toBeTrue()
        ->and(Schema::hasIndex('goals', ['user_id', 'status', 'position']))->toBeTrue()
        ->and(Schema::hasIndex('goal_revisions', ['goal_id', 'created_at']))->toBeTrue()
        ->and(Schema::hasIndex('goal_actions', ['user_id', 'enabled', 'schedule_type']))->toBeTrue();
});

it('enforces Goal ownership through the conventional policy', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $goal = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000001',
        'user_id' => $owner->id,
        'mode' => 'mixed',
        'status' => 'active',
        'position' => 0,
    ]);

    expect(Gate::forUser($owner)->allows('update', $goal))->toBeTrue()
        ->and(Gate::forUser($other)->allows('update', $goal))->toBeFalse();
});

it('rejects a current revision that belongs to another Goal', function () {
    $user = User::factory()->create();
    $first = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000010',
        'user_id' => $user->id,
        'mode' => 'mixed',
        'status' => 'active',
        'position' => 0,
    ]);
    $second = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000011',
        'user_id' => $user->id,
        'mode' => 'petition',
        'status' => 'active',
        'position' => 1,
    ]);
    $revision = GoalRevision::create([
        'id' => '0198b200-0000-7000-8000-000000000012',
        'goal_id' => $first->id,
        'user_id' => $user->id,
        'title' => 'First Goal',
        'device_id' => 'device-1',
        'created_at' => now(),
    ]);

    expect(fn () => $second->forceFill([
        'current_revision_id' => $revision->id,
    ])->save())->toThrow(QueryException::class);
});

it('rejects an action event whose Goal does not match its action', function () {
    $user = User::factory()->create();
    $first = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000020',
        'user_id' => $user->id,
        'mode' => 'actionable',
        'status' => 'active',
        'position' => 0,
    ]);
    $second = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000021',
        'user_id' => $user->id,
        'mode' => 'actionable',
        'status' => 'active',
        'position' => 1,
    ]);
    $action = GoalAction::create([
        'id' => '0198b200-0000-7000-8000-000000000022',
        'goal_id' => $first->id,
        'user_id' => $user->id,
        'body' => 'Take the next faithful step',
        'action_kind' => 'next_step',
        'schedule_type' => 'daily',
        'enabled' => true,
    ]);

    expect(fn () => GoalActionEvent::create([
        'id' => '0198b200-0000-7000-8000-000000000023',
        'goal_action_id' => $action->id,
        'goal_id' => $second->id,
        'user_id' => $user->id,
        'event_type' => 'completed',
        'occurrence_key' => $action->id.':2026-08-28',
        'occurred_at' => now(),
        'local_date' => '2026-08-28',
        'device_id' => 'device-1',
    ]))->toThrow(QueryException::class);
});

it('deletes structural Goal links cleanly when an account is deleted', function () {
    $user = User::factory()->create();
    $goal = Goal::create([
        'id' => '0198b200-0000-7000-8000-000000000030',
        'user_id' => $user->id,
        'mode' => 'mixed',
        'status' => 'active',
        'position' => 0,
    ]);
    $prayer = PersonalPrayer::create([
        'id' => '0198b200-0000-7000-8000-000000000031',
        'user_id' => $user->id,
        'title' => 'Private prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    $link = GoalLink::create([
        'id' => '0198b200-0000-7000-8000-000000000032',
        'goal_id' => $goal->id,
        'user_id' => $user->id,
        'link_type' => 'personal_prayer',
        'personal_prayer_id' => $prayer->id,
        'role' => 'primary_prayer',
        'created_at' => now(),
    ]);

    $user->delete();

    expect(Goal::find($goal->id))->toBeNull()
        ->and(PersonalPrayer::find($prayer->id))->toBeNull()
        ->and(GoalLink::find($link->id))->toBeNull();
});
