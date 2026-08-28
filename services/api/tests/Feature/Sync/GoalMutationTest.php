<?php

use App\Models\Encounter;
use App\Models\Goal;
use App\Models\GoalAction;
use App\Models\GoalActionEvent;
use App\Models\GoalLink;
use App\Models\GoalRevision;
use App\Models\PersonalPrayer;
use App\Models\SyncOperation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function goalMutationOperation(
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

function goalCreateBatch(string $goalId, string $revisionId, string $prefix = '0198b300'): array
{
    return [
        goalMutationOperation(
            $prefix.'-0000-7000-8000-000000000001',
            'goals',
            'put',
            $goalId,
            [
                'owner_id' => 'offline-installation-owner',
                'starter_key' => 'direction',
                'mode' => 'mixed',
                'status' => 'active',
                'current_revision_id' => $revisionId,
                'position' => 0,
                'created_at' => '2026-08-28T08:00:00.000Z',
                'updated_at' => '2026-08-28T08:00:00.000Z',
                'archived_at' => null,
            ],
        ),
        goalMutationOperation(
            $prefix.'-0000-7000-8000-000000000002',
            'goal_revisions',
            'put',
            $revisionId,
            [
                'owner_id' => 'offline-installation-owner',
                'goal_id' => $goalId,
                'title' => 'Find direction in my work',
                'current_situation' => 'I have two options to examine.',
                'why_it_matters' => 'I want to act faithfully.',
                'created_at' => '2026-08-28T08:00:00.000Z',
                'device_id' => 'device-1',
            ],
        ),
    ];
}

it('creates a Goal with an immutable revision and replays operation ids idempotently', function () {
    $user = User::factory()->create();
    $goalId = '0198b300-0000-7000-8000-000000000010';
    $revisionId = '0198b300-0000-7000-8000-000000000011';
    $operations = goalCreateBatch($goalId, $revisionId);

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('rejected', 0);
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 2)
        ->assertJsonPath('duplicates', 2);

    $goal = Goal::findOrFail($goalId);
    expect($goal->user_id)->toBe($user->id)
        ->and($goal->current_revision_id)->toBe($revisionId)
        ->and(GoalRevision::where('goal_id', $goalId)->count())->toBe(1)
        ->and(SyncOperation::whereIn('operation_id', collect($operations)->pluck('operation_id'))->count())->toBe(2);
});

it('preserves old Goal revisions when the current text changes', function () {
    $user = User::factory()->create();
    $goalId = '0198b300-0000-7000-8000-000000000020';
    $firstRevisionId = '0198b300-0000-7000-8000-000000000021';
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => goalCreateBatch($goalId, $firstRevisionId, '0198b301'),
    ])->assertOk()->assertJsonPath('accepted', 2);

    $secondRevisionId = '0198b300-0000-7000-8000-000000000022';
    $operations = [
        goalMutationOperation(
            '0198b302-0000-7000-8000-000000000001',
            'goal_revisions',
            'put',
            $secondRevisionId,
            [
                'owner_id' => 'installation-owner',
                'goal_id' => $goalId,
                'title' => 'Choose the next faithful work step',
                'current_situation' => 'One option is now clearly actionable.',
                'why_it_matters' => 'Delay is no longer useful.',
                'created_at' => '2026-08-28T08:05:00.000Z',
                'device_id' => 'device-1',
            ],
        ),
        goalMutationOperation(
            '0198b302-0000-7000-8000-000000000002',
            'goals',
            'patch',
            $goalId,
            [
                'current_revision_id' => $secondRevisionId,
                'updated_at' => '2026-08-28T08:05:00.000Z',
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 2);

    expect(Goal::findOrFail($goalId)->current_revision_id)->toBe($secondRevisionId)
        ->and(GoalRevision::where('goal_id', $goalId)->count())->toBe(2)
        ->and(GoalRevision::findOrFail($firstRevisionId)->title)->toBe('Find direction in my work');
});

it('rejects cross-owner Goal mutation and wrong-owner linked resources', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $goalId = '0198b300-0000-7000-8000-000000000030';
    $revisionId = '0198b300-0000-7000-8000-000000000031';
    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => goalCreateBatch($goalId, $revisionId, '0198b303'),
    ])->assertOk();

    $this->actingAs($attacker)->postJson('/api/sync/mutations', [
        'operations' => [goalMutationOperation(
            '0198b304-0000-7000-8000-000000000001',
            'goals',
            'patch',
            $goalId,
            ['status' => 'completed'],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 1)
        ->assertJsonPath('code', 'inaccessible_record');

    $foreignPrayer = PersonalPrayer::create([
        'id' => '0198b300-0000-7000-8000-000000000032',
        'user_id' => $attacker->id,
        'title' => 'Private prayer',
        'style' => 'daily',
        'reach' => 'personal',
        'grounding' => 'general_christian',
        'purpose' => 'daily',
        'current_revision_id' => null,
    ]);
    $linkId = '0198b300-0000-7000-8000-000000000033';
    $this->actingAs($owner)->postJson('/api/sync/mutations', [
        'operations' => [goalMutationOperation(
            '0198b304-0000-7000-8000-000000000002',
            'goal_links',
            'put',
            $linkId,
            [
                'owner_id' => 'offline-owner',
                'goal_id' => $goalId,
                'link_type' => 'personal_prayer',
                'personal_prayer_id' => $foreignPrayer->id,
                'library_prayer_id' => null,
                'encounter_id' => null,
                'voice_tablet_id' => null,
                'circle_id' => null,
                'translation' => null,
                'book' => null,
                'chapter' => null,
                'first_verse' => null,
                'last_verse' => null,
                'role' => 'primary_prayer',
                'created_at' => '2026-08-28T08:10:00.000Z',
                'archived_at' => null,
            ],
        )],
    ])->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'inaccessible_record');

    expect(GoalLink::find($linkId))->toBeNull();
});

it('accepts action occurrences while binding every event to its action and Goal', function () {
    $user = User::factory()->create();
    $goalId = '0198b300-0000-7000-8000-000000000040';
    $revisionId = '0198b300-0000-7000-8000-000000000041';
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => goalCreateBatch($goalId, $revisionId, '0198b305'),
    ])->assertOk();

    $actionId = '0198b300-0000-7000-8000-000000000042';
    $eventId = '0198b300-0000-7000-8000-000000000043';
    $operations = [
        goalMutationOperation(
            '0198b306-0000-7000-8000-000000000001',
            'goal_actions',
            'put',
            $actionId,
            [
                'owner_id' => 'offline-owner',
                'goal_id' => $goalId,
                'body' => 'Phone outside bedroom by 10 PM',
                'action_kind' => 'guard',
                'schedule_type' => 'daily',
                'local_time' => '22:00',
                'timezone' => 'Africa/Lagos',
                'once_at' => null,
                'weekdays_mask' => null,
                'enabled' => true,
                'created_at' => '2026-08-28T08:00:00.000Z',
                'updated_at' => '2026-08-28T08:00:00.000Z',
                'archived_at' => null,
            ],
        ),
        goalMutationOperation(
            '0198b306-0000-7000-8000-000000000002',
            'goal_action_events',
            'put',
            $eventId,
            [
                'owner_id' => 'offline-owner',
                'goal_action_id' => $actionId,
                'goal_id' => $goalId,
                'event_type' => 'completed',
                'occurrence_key' => $actionId.':2026-08-28',
                'occurred_at' => '2026-08-28T21:00:00.000Z',
                'local_date' => '2026-08-28',
                'device_id' => 'device-1',
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()->assertJsonPath('accepted', 2);
    expect(GoalAction::find($actionId))->not->toBeNull()
        ->and(GoalActionEvent::find($eventId)?->goal_id)->toBe($goalId);

    $tampered = $operations[1];
    $tampered['operation_id'] = '0198b306-0000-7000-8000-000000000003';
    $tampered['id'] = '0198b300-0000-7000-8000-000000000044';
    $tampered['data']['occurrence_key'] = $actionId.':2026-08-29';
    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => [$tampered]])
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('code', 'invalid_occurrence');
});

it('rolls back legacy writes when a mixed Goal batch is rejected', function () {
    $user = User::factory()->create();
    $encounterId = '0198b300-0000-7000-8000-000000000050';
    $revisionId = '0198b300-0000-7000-8000-000000000051';
    $operations = [
        goalMutationOperation(
            '0198b307-0000-7000-8000-000000000001',
            'encounters',
            'put',
            $encounterId,
            [
                'title' => 'A remembered event',
                'body' => 'Something worth preserving.',
                'occurred_on' => '2026-08-28',
                'is_altar' => false,
                'current_revision_id' => $revisionId,
                'archived_at' => null,
            ],
        ),
        goalMutationOperation(
            '0198b307-0000-7000-8000-000000000002',
            'encounter_revisions',
            'put',
            $revisionId,
            [
                'encounter_id' => $encounterId,
                'title' => 'A remembered event',
                'body' => 'Something worth preserving.',
                'device_id' => 'device-1',
            ],
        ),
        goalMutationOperation(
            '0198b307-0000-7000-8000-000000000003',
            'goal_actions',
            'put',
            '0198b300-0000-7000-8000-000000000052',
            [
                'owner_id' => 'offline-owner',
                'goal_id' => '0198b300-0000-7000-8000-000000000099',
                'body' => 'This has no Goal',
                'action_kind' => 'next_step',
                'schedule_type' => 'daily',
                'local_time' => null,
                'timezone' => null,
                'once_at' => null,
                'weekdays_mask' => null,
                'enabled' => true,
                'archived_at' => null,
            ],
        ),
    ];

    $this->actingAs($user)->postJson('/api/sync/mutations', ['operations' => $operations])
        ->assertOk()
        ->assertJsonPath('accepted', 0)
        ->assertJsonPath('rejected', 3)
        ->assertJsonPath('code', 'inaccessible_record');

    expect(Encounter::find($encounterId))->toBeNull()
        ->and(SyncOperation::whereIn(
            'operation_id',
            collect($operations)->pluck('operation_id'),
        )->count())->toBe(0);
});
