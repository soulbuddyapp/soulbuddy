<?php

namespace App\Domain\Encounters;

use App\Models\Encounter;
use App\Models\EncounterRevision;
use App\Models\SyncOperation;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;

class ApplyEncounterMutation
{
    public function apply(User $user, array $operations): array
    {
        $duplicates = collect($operations)->filter(
            fn (array $operation) => SyncOperation::whereKey($operation['operation_id'])->exists()
        )->count();
        $pending = collect($operations)->reject(
            fn (array $operation) => SyncOperation::whereKey($operation['operation_id'])->exists()
        )->values();

        if ($pending->isEmpty()) {
            return $this->result(count($operations), 0, $duplicates);
        }

        if ($pending->contains(fn (array $operation) => ! in_array(
            $operation['table'],
            ['encounters', 'encounter_revisions'],
            true,
        ))) {
            return $this->result($duplicates, $pending->count(), $duplicates, 'unsupported_table');
        }

        $pairError = $this->validatePairs($pending->all());
        if ($pairError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $pairError);
        }

        $validationError = $this->validateData($pending->all());
        if ($validationError !== null) {
            return $this->result($duplicates, $pending->count(), $duplicates, $validationError);
        }

        try {
            DB::transaction(function () use ($user, $pending) {
                foreach ($pending->sortBy(fn (array $operation) => $operation['table'] === 'encounters' ? 0 : 1) as $operation) {
                    $operation['table'] === 'encounters'
                        ? $this->applyEncounter($user, $operation)
                        : $this->applyRevision($user, $operation);

                    SyncOperation::create([
                        'operation_id' => $operation['operation_id'],
                        'user_id' => $user->id,
                        'table_name' => $operation['table'],
                        'record_id' => $operation['id'],
                        'created_at' => now(),
                    ]);
                }
            });
        } catch (AuthorizationException) {
            return $this->result($duplicates, $pending->count(), $duplicates, 'forbidden');
        }

        return $this->result(count($operations), 0, $duplicates);
    }

    private function validatePairs(array $operations): ?string
    {
        $encounters = collect($operations)->where('table', 'encounters');
        $revisions = collect($operations)->where('table', 'encounter_revisions');

        foreach ($encounters as $encounter) {
            if ($encounter['type'] === 'delete') {
                continue;
            }
            $revisionId = $encounter['data']['current_revision_id'] ?? null;
            $paired = $revisions->contains(
                fn (array $revision) => $revision['id'] === $revisionId
                    && ($revision['data']['encounter_id'] ?? null) === $encounter['id']
            );
            if (! $paired && ! EncounterRevision::whereKey($revisionId)->exists()) {
                return 'incomplete_revision_pair';
            }
        }

        foreach ($revisions as $revision) {
            $encounterId = $revision['data']['encounter_id'] ?? null;
            if (! $encounters->contains('id', $encounterId) && ! Encounter::whereKey($encounterId)->exists()) {
                return 'incomplete_revision_pair';
            }
        }

        return null;
    }

    private function validateData(array $operations): ?string
    {
        foreach ($operations as $operation) {
            if ($operation['type'] === 'delete') {
                continue;
            }
            $rules = $operation['table'] === 'encounters'
                ? ['title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'occurred_on' => ['required', 'date_format:Y-m-d'], 'is_altar' => ['required', 'boolean'], 'current_revision_id' => ['required', 'uuid']]
                : ['encounter_id' => ['required', 'uuid'], 'title' => ['required', 'string', 'max:120'], 'body' => ['nullable', 'string', 'max:4000'], 'device_id' => ['required', 'string', 'max:120']];
            if (Validator::make($operation['data'], $rules)->fails()) {
                return 'invalid_data';
            }
        }

        return null;
    }

    private function applyEncounter(User $user, array $operation): void
    {
        $encounter = Encounter::find($operation['id']);
        if ($encounter !== null) {
            Gate::forUser($user)->authorize('update', $encounter);
        } else {
            $encounter = new Encounter(['id' => $operation['id'], 'user_id' => $user->id]);
        }

        if ($operation['type'] === 'delete') {
            $encounter->forceFill(['archived_at' => now()])->save();

            return;
        }

        $encounter->forceFill([
            'user_id' => $user->id,
            'title' => $operation['data']['title'],
            'body' => $operation['data']['body'] ?? null,
            'occurred_on' => $operation['data']['occurred_on'],
            'is_altar' => $operation['data']['is_altar'],
            'current_revision_id' => $operation['data']['current_revision_id'],
            'archived_at' => $operation['data']['archived_at'] ?? null,
        ])->save();
    }

    private function applyRevision(User $user, array $operation): void
    {
        $encounter = Encounter::findOrFail($operation['data']['encounter_id']);
        Gate::forUser($user)->authorize('update', $encounter);
        EncounterRevision::updateOrCreate(
            ['id' => $operation['id']],
            [
                'encounter_id' => $encounter->id,
                'user_id' => $user->id,
                'title' => $operation['data']['title'],
                'body' => $operation['data']['body'] ?? null,
                'device_id' => $operation['data']['device_id'],
                'created_at' => now(),
            ],
        );
    }

    private function result(int $accepted, int $rejected, int $duplicates, ?string $code = null): array
    {
        return array_filter([
            'accepted' => $accepted,
            'rejected' => $rejected,
            'duplicates' => $duplicates,
            'code' => $code,
        ], fn ($value) => $value !== null);
    }
}
