<?php

use Illuminate\Support\Str;

function commitmentOperation(string $table, array $data, ?string $id = null, string $type = 'put'): array
{
    return ['operation_id' => (string) Str::uuid(), 'table' => $table, 'type' => $type,
        'id' => $id ?? (string) Str::uuid(), 'data' => $data];
}

function commitmentBatch(int $count = 1): array
{
    $goal = (string) Str::uuid();
    $revision = (string) Str::uuid();
    $commitment = (string) Str::uuid();
    $stamp = ['created_at' => '2026-09-24T08:00:00Z', 'updated_at' => '2026-09-24T08:00:00Z'];
    $operations = [
        commitmentOperation('goals', ['owner_id' => 'forged', 'starter_key' => 'closer_to_god', 'mode' => 'actionable', 'status' => 'active', 'current_revision_id' => $revision, 'position' => 0, 'archived_at' => null], $goal),
        commitmentOperation('goal_revisions', ['goal_id' => $goal, 'title' => 'Private name', 'current_situation' => null, 'why_it_matters' => null, 'device_id' => 'device'], $revision),
        commitmentOperation('commitments', $stamp + ['owner_id' => 'forged', 'journey_slot' => 'primary', 'goal_id' => $goal, 'name' => 'Private name', 'key_need_one' => 'Private need', 'key_need_two' => 'Hope', 'key_need_three' => 'Peace', 'calling' => 'Private calling', 'guide_id' => 'surrender'], $commitment),
        commitmentOperation('commitment_declarations', $stamp + ['commitment_id' => $commitment, 'body' => 'Private declaration', 'reviewed_at' => '2026-09-24T08:00:00Z']),
        commitmentOperation('commitment_meditation_plans', $stamp + ['commitment_id' => $commitment, 'frequency' => 'daily', 'weekdays_mask' => null, 'local_time' => '08:00', 'timezone' => 'Africa/Lagos', 'duration_minutes' => 10, 'enabled' => true]),
        commitmentOperation('commitment_preparation_cycles', $stamp + ['commitment_id' => $commitment, 'started_at_utc' => '2026-09-24T08:00:00Z', 'started_local_date' => '2026-09-24', 'start_timezone' => 'Africa/Lagos', 'review_local_date' => '2026-10-03', 'state' => 'active']),
    ];
    for ($position = 0; $position < $count; $position++) {
        $action = (string) Str::uuid();
        $operations[] = commitmentOperation('goal_actions', ['goal_id' => $goal, 'body' => 'Private practice', 'action_kind' => 'commitment_practice', 'schedule_type' => 'daily', 'local_time' => null, 'timezone' => null, 'once_at' => null, 'weekdays_mask' => null, 'enabled' => true, 'archived_at' => null], $action);
        $operations[] = commitmentOperation('commitment_practices', $stamp + ['commitment_id' => $commitment, 'goal_action_id' => $action, 'category' => 'joy_pleasure', 'body' => 'Private practice', 'position' => $position, 'source' => 'user_authored', 'suggestion_id' => null]);
    }

    return $operations;
}
