<?php

namespace App\Domain\Sync;

use App\Models\Goal;
use App\Models\GoalGuardSelection;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Validator;

final class GoalGuardSelectionSyncMutation
{
    /**
     * @param Collection<int, array<string, mixed>> $allOperations
     * @param Collection<int, array<string, mixed>> $guardOperations
     */
    public function validate(User $user, Collection $allOperations, Collection $guardOperations): ?string
    {
        foreach ($guardOperations as $operation) {
            if (! in_array($operation['type'], ['put', 'patch', 'delete'], true)) {
                return 'unsupported_operation';
            }
            if ($operation['type'] === 'delete') {
                if ($operation['data'] !== []) {
                    return 'invalid_data';
                }
            } else {
                $rules = $operation['type'] === 'put'
                    ? $this->putRules()
                    : $this->patchRules();
                if ($operation['data'] === []
                    || array_diff(array_keys($operation['data']), array_keys($rules)) !== []
                    || Validator::make($operation['data'], $rules)->fails()) {
                    return 'invalid_data';
                }
            }

            $existing = GoalGuardSelection::query()->find($operation['id']);
            if ($existing !== null && $existing->user_id !== $user->id) {
                return 'inaccessible_record';
            }
            if ($operation['type'] !== 'put' && $existing === null) {
                return 'inaccessible_record';
            }
            if ($operation['type'] === 'put') {
                if (! $this->goalIsAvailable(
                    $user,
                    $allOperations,
                    $operation['data']['goal_id'],
                )) {
                    return 'inaccessible_record';
                }
                if ($existing !== null && ! $this->sameSelection($existing, $operation['data'])) {
                    return 'conflict';
                }
            }
        }

        return null;
    }

    /** @param Collection<int, array<string, mixed>> $guardOperations */
    public function apply(User $user, Collection $guardOperations): void
    {
        foreach ($guardOperations as $operation) {
            $selection = GoalGuardSelection::query()
                ->whereKey($operation['id'])
                ->where('user_id', $user->id)
                ->first();

            if ($operation['type'] === 'delete') {
                $selection?->forceFill(['archived_at' => now()])->save();

                continue;
            }
            if ($operation['type'] === 'patch') {
                $selection->forceFill(collect($operation['data'])->only([
                    'guard_content_version',
                    'private_note',
                    'configured_at',
                    'archived_at',
                ])->all())->save();

                continue;
            }
            if ($selection === null) {
                GoalGuardSelection::create([
                    'id' => $operation['id'],
                    'goal_id' => $operation['data']['goal_id'],
                    'user_id' => $user->id,
                    'guard_definition_id' => $operation['data']['guard_definition_id'],
                    'guard_content_version' => $operation['data']['guard_content_version'],
                    'private_note' => $operation['data']['private_note'],
                    'configured_at' => $operation['data']['configured_at'],
                    'archived_at' => $operation['data']['archived_at'],
                ]);
            }
        }
    }

    private function putRules(): array
    {
        return [
            'owner_id' => [],
            'goal_id' => ['required', 'uuid'],
            'guard_definition_id' => ['required', 'string', 'min:1', 'max:120', 'regex:/^[a-z0-9][a-z0-9-]*$/'],
            'guard_content_version' => ['required', 'integer', 'min:1'],
            'private_note' => ['present', 'nullable', 'string', 'max:1000'],
            'configured_at' => ['required', 'date'],
            'archived_at' => ['present', 'nullable', 'date'],
        ];
    }

    private function patchRules(): array
    {
        return [
            'guard_content_version' => ['sometimes', 'integer', 'min:1'],
            'private_note' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'configured_at' => ['sometimes', 'date'],
            'archived_at' => ['sometimes', 'nullable', 'date'],
        ];
    }

    private function goalIsAvailable(User $user, Collection $operations, string $goalId): bool
    {
        if ($operations->where('table', 'goals')->where('type', 'put')->contains('id', $goalId)) {
            return true;
        }

        return Goal::query()
            ->whereKey($goalId)
            ->where('user_id', $user->id)
            ->whereNull('archived_at')
            ->exists();
    }

    private function sameSelection(GoalGuardSelection $selection, array $data): bool
    {
        return $selection->goal_id === $data['goal_id']
            && $selection->guard_definition_id === $data['guard_definition_id']
            && $selection->guard_content_version === (int) $data['guard_content_version']
            && $selection->private_note === $data['private_note']
            && $this->sameDate($selection->configured_at, $data['configured_at'])
            && $this->sameDate($selection->archived_at, $data['archived_at']);
    }

    private function sameDate(mixed $stored, mixed $incoming): bool
    {
        if ($stored === null || $incoming === null) {
            return $stored === null && $incoming === null;
        }
        $storedTimestamp = $stored instanceof \DateTimeInterface
            ? $stored->getTimestamp()
            : strtotime((string) $stored);
        $incomingTimestamp = $incoming instanceof \DateTimeInterface
            ? $incoming->getTimestamp()
            : strtotime((string) $incoming);

        return $storedTimestamp !== false
            && $incomingTimestamp !== false
            && $storedTimestamp === $incomingTimestamp;
    }
}
