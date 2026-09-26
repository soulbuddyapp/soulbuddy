<?php

namespace App\Domain\Sync;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

final class CommitmentSyncMutationValidator
{
    public const TABLES = ['commitments', 'commitment_practices', 'commitment_declarations', 'commitment_meditation_plans', 'commitment_preparation_cycles', 'commitment_meditation_sessions'];

    public static function supports(string $table): bool
    {
        return in_array($table, self::TABLES, true);
    }

    public function validate(User $user, Collection $all, Collection $operations): ?string
    {
        $state = [];
        foreach (array_merge(self::TABLES, ['goals', 'goal_actions', 'goal_revisions']) as $table) {
            $state[$table] = DB::table($table)->where('user_id', $user->id)->get()->mapWithKeys(fn ($row) => [$row->id => (array) $row])->all();
        }
        $seen = [];
        foreach ($operations as $operation) {
            $table = $operation['table'];
            $id = $operation['id'];
            $type = $operation['type'];
            if (isset($seen[$table][$id])) {
                return 'invalid_data';
            }
            $seen[$table][$id] = true;
            $existing = DB::table($table)->where('id', $id)->first();
            if ($existing !== null && $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }
            if ($table === 'commitment_meditation_sessions' && ($type !== 'put' || $existing !== null)) {
                return 'immutable_session';
            }
            if (! in_array($type, ['put', 'patch'], true)) {
                return 'unsupported_operation';
            }
            if ($type === 'patch' && $existing === null) {
                return 'inaccessible_record';
            }
            $rules = $this->rules($table);
            $allowed = $type === 'patch' ? $this->patchFields($table) : array_keys($rules);
            if ($operation['data'] === [] || array_diff(array_keys($operation['data']), $allowed) !== []) {
                return 'invalid_data';
            }
            if ($type === 'put' && Validator::make($operation['data'], $rules)->fails()) {
                return 'invalid_data';
            }
            if ($type === 'patch' && $table === 'commitment_declarations' && array_key_exists('body', $operation['data']) && ! isset($operation['data']['reviewed_at'])) {
                return 'invalid_data';
            }
            $merged = array_replace($state[$table][$id] ?? [], $operation['data']);
            if (Validator::make($merged, $rules)->fails() || ! $this->validShape($table, $merged)) {
                return 'invalid_data';
            }
            if ($existing !== null && $type === 'put') {
                foreach (array_diff(array_keys($rules), ['owner_id', 'created_at', 'updated_at']) as $field) {
                    if (($merged[$field] ?? null) != ($existing->$field ?? null)) {
                        return 'invalid_data';
                    }
                }
            }
            $state[$table][$id] = $merged + ['id' => $id, 'user_id' => $user->id];
        }
        foreach ($all->whereIn('table', ['goals', 'goal_actions', 'goal_revisions']) as $operation) {
            $table = $operation['table'];
            if ($operation['type'] !== 'delete') {
                $state[$table][$operation['id']] = array_replace($state[$table][$operation['id']] ?? [], $operation['data']);
                if ($table === 'goal_revisions') {
                    // Match the existing Goal writer's title normalization.
                    $state[$table][$operation['id']]['title'] = trim($operation['data']['title']);
                }
            }
        }
        if (count($state['commitments']) > 1) {
            return 'primary_commitment_exists';
        }
        foreach ($state['commitments'] as $id => $commitment) {
            $goal = $state['goals'][$commitment['goal_id']] ?? null;
            if ($goal === null || $goal['mode'] !== 'actionable') {
                return 'invalid_commitment_goal';
            }
            $revision = $state['goal_revisions'][$goal['current_revision_id'] ?? ''] ?? null;
            if ($revision === null || $revision['goal_id'] !== $commitment['goal_id'] || $revision['title'] !== $commitment['name']) {
                return 'invalid_commitment_goal';
            }
            $practices = array_filter($state['commitment_practices'], fn ($row) => $row['commitment_id'] === $id);
            if (count($practices) < 1 || count($practices) > 12) {
                return 'invalid_data';
            }
            if (count(array_unique(array_column($practices, 'position'))) !== count($practices)) {
                return 'invalid_data';
            }
            foreach (['commitment_declarations', 'commitment_meditation_plans', 'commitment_preparation_cycles'] as $table) {
                if (count(array_filter($state[$table], fn ($row) => $row['commitment_id'] === $id)) !== 1) {
                    return 'invalid_data';
                }
            }
        }
        $linkedActions = [];
        foreach (array_diff(self::TABLES, ['commitments']) as $table) {
            foreach ($state[$table] as $row) {
                $commitment = $state['commitments'][$row['commitment_id']] ?? null;
                if ($commitment === null) {
                    return 'inaccessible_record';
                }
                if ($table !== 'commitment_practices') {
                    continue;
                }
                $action = $state['goal_actions'][$row['goal_action_id']] ?? null;
                if ($action === null || $action['goal_id'] !== $commitment['goal_id'] || $action['action_kind'] !== 'commitment_practice') {
                    return 'invalid_commitment_goal';
                }
                if (isset($linkedActions[$row['goal_action_id']])) {
                    return 'invalid_data';
                }
                $linkedActions[$row['goal_action_id']] = true;
                if ($row['body'] !== $action['body']) {
                    return 'invalid_data';
                }
            }
        }
        foreach ($all->where('table', 'goal_actions')->where('type', 'put') as $operation) {
            if (($operation['data']['action_kind'] ?? null) === 'commitment_practice' && ! isset($linkedActions[$operation['id']])) {
                return 'invalid_commitment_goal';
            }
        }

        return null;
    }

    private function patchFields(string $table): array
    {
        return array_merge(['owner_id', 'updated_at'], match ($table) {
            'commitments' => ['guide_id'],
            'commitment_practices' => ['body', 'category', 'position', 'source', 'suggestion_id'],
            'commitment_declarations' => ['body', 'reviewed_at'],
            'commitment_meditation_plans' => ['frequency', 'weekdays_mask', 'local_time', 'timezone', 'duration_minutes', 'enabled'],
            'commitment_preparation_cycles' => ['state'],
            default => [],
        });
    }

    private function rules(string $table): array
    {
        $text = fn (int $max) => ['required', 'string', 'min:1', "max:$max", 'regex:/\\S/u'];
        $rules = match ($table) {
            'commitments' => [
                'journey_slot' => ['required', 'in:primary'], 'goal_id' => ['required', 'uuid'],
                'name' => $text(120), 'key_need_one' => $text(500), 'key_need_two' => $text(500), 'key_need_three' => $text(500), 'calling' => $text(1500), 'guide_id' => ['required', 'in:surrender,direction,peace'],
            ],
            'commitment_practices' => [
                'goal_action_id' => ['required', 'uuid'], 'category' => ['required', 'in:joy_pleasure,exploration_adventure,attention_self_esteem'], 'body' => $text(1000), 'position' => ['required', 'integer', 'between:0,11'], 'source' => ['required', 'in:reviewed_suggestion,user_authored'], 'suggestion_id' => ['present', 'nullable', 'string', 'max:120'],
            ],
            'commitment_declarations' => ['body' => $text(4000), 'reviewed_at' => ['required', 'date']],
            'commitment_meditation_plans' => [
                'frequency' => ['required', 'in:daily,selected_days'], 'weekdays_mask' => ['present', 'nullable', 'integer', 'between:1,127'], 'local_time' => ['required', 'date_format:H:i'], 'timezone' => ['required', 'timezone:all', 'max:100'], 'duration_minutes' => ['required', 'integer', 'in:5,10,15,20,30'], 'enabled' => ['required', 'boolean'],
            ],
            'commitment_preparation_cycles' => [
                'started_at_utc' => ['required', 'date'], 'started_local_date' => ['required', 'date_format:Y-m-d'], 'start_timezone' => ['required', 'timezone:all', 'max:100'], 'review_local_date' => ['required', 'date_format:Y-m-d'], 'state' => ['required', 'in:active,review_available,listening_opened,deferred'],
            ],
            'commitment_meditation_sessions' => [
                'session_kind' => ['required', 'in:meditation,listening'], 'started_at' => ['required', 'date'], 'ended_at' => ['required', 'date', 'after_or_equal:started_at'], 'local_date' => ['required', 'date_format:Y-m-d'], 'planned_duration_seconds' => ['required', 'integer', 'in:300,600,900,1200,1800'], 'actual_duration_seconds' => ['required', 'integer', 'min:0', 'lte:planned_duration_seconds'], 'outcome' => ['required', 'in:completed,ended_early'], 'device_id' => $text(120),
            ],
        };
        $rules['owner_id'] = [];
        if ($table !== 'commitments') {
            $rules['commitment_id'] = ['required', 'uuid'];
        }
        if ($table !== 'commitment_meditation_sessions') {
            $rules['created_at'] = ['sometimes', 'date'];
            $rules['updated_at'] = ['sometimes', 'date'];
        }

        return $rules;
    }

    private function validShape(string $table, array $data): bool
    {
        return match ($table) {
            'commitment_practices' => $data['source'] === 'user_authored' ? $data['suggestion_id'] === null : is_string($data['suggestion_id']) && trim($data['suggestion_id']) !== '',
            'commitment_meditation_plans' => $data['frequency'] === 'daily' ? $data['weekdays_mask'] === null : $data['weekdays_mask'] !== null,
            'commitment_preparation_cycles' => CarbonImmutable::parse($data['started_local_date'])->addDays(9)->toDateString() === $data['review_local_date'] && CarbonImmutable::parse($data['started_at_utc'])->setTimezone($data['start_timezone'])->toDateString() === $data['started_local_date'],
            'commitment_meditation_sessions' => ($data['outcome'] === 'completed' ? (int) $data['actual_duration_seconds'] === (int) $data['planned_duration_seconds'] : $data['actual_duration_seconds'] < $data['planned_duration_seconds']) && CarbonImmutable::parse($data['started_at'])->diffInSeconds(CarbonImmutable::parse($data['ended_at'])) >= $data['actual_duration_seconds'],
            default => true,
        };
    }
}
